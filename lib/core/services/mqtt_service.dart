import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/node_model.dart';

class MqttService extends ChangeNotifier {
  static String defaultBrokerUrl = 'wss://mqtt.duynguyen.io.vn';
  
  MqttServerClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  List<NodeModel> _currentNodes = [];

  // Stream truyền dữ liệu sang DeviceProvider
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  MqttService();

  Future<void> saveBrokerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_mqtt_url', url);
  }

  Future<String> getSavedBrokerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_mqtt_url') ?? defaultBrokerUrl;
  }

  // ═══════════════════════════════════════════════════════════
  //  KẾT NỐI
  // ═══════════════════════════════════════════════════════════
  Future<bool> connect({String? customUrl}) async {
    if (_isConnected && _client != null) {
      return true;
    }

    final targetUrlStr = customUrl ?? await getSavedBrokerUrl();
    if (customUrl != null) {
      await saveBrokerUrl(customUrl);
    }

    final Uri uri = Uri.parse(targetUrlStr);
    final String scheme = uri.scheme.isNotEmpty ? uri.scheme : 'ws';
    final bool isSecure = scheme == 'wss' || scheme == 'https';
    final String host = uri.host.isNotEmpty ? uri.host : '10.0.2.2';
    final int port = uri.port != 0 ? uri.port : (isSecure ? 443 : 8083);
    final String path = uri.path.isNotEmpty ? uri.path : '/mqtt';

    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      print('MQTT: Đang kết nối tới $scheme://$host:$port$path ...');
    }

    // Server client với URI WebSocket
    _client = MqttServerClient.withPort('$scheme://$host$path', clientId, port);
    _client!.useWebSocket = true;
    _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    
    _client!.logging(on: false); 
    _client!.keepAlivePeriod = 60;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;
    _client!.onSubscribed = _onSubscribed;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('tele/flutter_app/status')
        .withWillMessage('offline')
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect().timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print('MQTT: Lỗi kết nối - $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected = true;
      _listenMessages();
      notifyListeners();
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════
  //  SUBSCRIBE TỰ ĐỘNG THEO DANH SÁCH NODE
  // ═══════════════════════════════════════════════════════════
  void subscribeNodes(List<NodeModel> nodes) {
    _currentNodes = nodes;
    if (_client == null || !_isConnected) return;
    
    final topics = <String>{
      'tele/+/status', // Wildcard toàn bộ thiết bị
      'tele/123/status',
      'tele/123_temp_livingroom/status',
      'tele/123_humi_living_room/status',
      'tele/123_led1/status',
      'tele/123_fan_livingroom/status',
      'tele/123_door_livingroom1/status',
      'tele/123_gas_livingroom/status',
      'tele/123_fire_livingroom/status',
    };
    
    for (var node in nodes) {
      if (node.chipId.isEmpty) continue;
      final cId = node.chipId;
      
      topics.add('tele/$cId/status');

      if (node.templateType == 'kitchen_living') {
        topics.addAll([
          'tele/${cId}_temp_livingroom/status',
          'tele/${cId}_humi_living_room/status',
          'tele/${cId}_led1/status',
          'tele/${cId}_fan_livingroom/status',
          'tele/${cId}_door_livingroom1/status',
          'tele/${cId}_gas_livingroom/status',
          'tele/${cId}_fire_livingroom/status',
        ]);
      } else if (node.templateType == 'bedroom') {
        topics.addAll([
          'tele/${cId}_led_bedroom/status',
          'tele/${cId}_fan_bedroom/status',
          'tele/${cId}_curtain/status',
        ]);
      }
    }

    for (final t in topics) {
      try {
        _client!.subscribe(t, MqttQos.atLeastOnce);
        if (kDebugMode) print('MQTT: Đã subscribe -> $t');
      } catch (e) {
        if (kDebugMode) print('MQTT Subscribe Error on $t: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  LẮNG NGHE MESSAGE
  // ═══════════════════════════════════════════════════════════
  void _listenMessages() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;

      final recMsg = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
          recMsg.payload.message);
      final topic = c[0].topic;

      dynamic value;
      try {
        final json = jsonDecode(payload);
        value = json['value'];
      } catch (_) {
        value = payload.trim();
      }

      _messageController.add({
        'topic': topic,
        'value': value,
        'raw': payload,
      });
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  PUBLISH LỆNH
  // ═══════════════════════════════════════════════════════════
  void publish(String topic, String message) {
    if (!_isConnected || _client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (kDebugMode) print('MQTT TX: [$topic] → $message');

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishCommand(String chipId, String deviceSuffix, String command) {
    publish('cmnd/${chipId}_$deviceSuffix/POWER', command);
  }

  // ═══════════════════════════════════════════════════════════
  //  CALLBACKS
  // ═══════════════════════════════════════════════════════════
  void _onConnected() {
    if (kDebugMode) print('MQTT: ✅ Đã kết nối thành công');
    _isConnected = true;
    subscribeNodes(_currentNodes);
    notifyListeners();
  }

  void _onDisconnected() {
    if (kDebugMode) print('MQTT: ⚠️ Đã ngắt kết nối');
    _isConnected = false;
    notifyListeners();
  }

  void _onAutoReconnect() {
    if (kDebugMode) print('MQTT: 🔄 Đang kết nối lại...');
  }

  void _onAutoReconnected() {
    if (kDebugMode) print('MQTT: ✅ Đã kết nối lại thành công');
    _isConnected = true;
    subscribeNodes(_currentNodes);
    notifyListeners();
  }

  void _onSubscribed(String topic) {}

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _currentNodes.clear();
    notifyListeners();
  }
}
