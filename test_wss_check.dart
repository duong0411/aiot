import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main() async {
  print('--- Testing Cloudflare Tunnel WSS: wss://mqtt.duynguyen.io.vn/mqtt ---');
  final client = MqttServerClient('wss://mqtt.duynguyen.io.vn/mqtt', 'dart_test_client');
  client.port = 443;
  client.useWebSocket = true;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  client.logging(on: true);

  try {
    print('Connecting to wss://mqtt.duynguyen.io.vn/mqtt:443 ...');
    final status = await client.connect().timeout(const Duration(seconds: 10));
    print('RESULT: ${status?.state}');
  } catch (e) {
    print('CONNECT ERROR: $e');
  }
  exit(0);
}
