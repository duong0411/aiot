/*
 * ╔══════════════════════════════════════════════════════════════╗
 * ║         SMARTHOME ESP32 — ĐIỀU KHIỂN & CẢNH BÁO THÔNG MINH  ║
 * ╠══════════════════════════════════════════════════════════════╣
 * ║  ✅ WiFiManager Web Portal cấu hình AP tĩnh 192.168.4.1       ║
 * ║  ✅ Quét & tự động lưu 5 mạng WiFi vào EEPROM Flash          ║
 * ║  ✅ Double Reset Detector (Nhấn Reset 2 lần để xóa WiFi)    ║
 * ║  ✅ Quản lý Cảm biến (Gas D34, Lửa D19, DHT11 D27)            ║
 * ║  ✅ Điều khiển Relay Đèn (D25), Relay Quạt (D26), Còi (D14)  ║
 * ║  ✅ Điều khiển Duy nhất 1 Servo Cửa (D13: 0° - 90°)          ║
 * ╚══════════════════════════════════════════════════════════════╝
 * 
 * ⚠️ THƯ VIỆN CẦN CÓ TRÊN ARDUINO IDE:
 * 1. WebSockets by Markus Sattler
 * 2. MQTTPubSubClient by Hideaki Tai
 * 3. DHT sensor library by Adafruit
 * 4. ArduinoJson by Benoit Blanchon
 * (Servo được tích hợp sẵn qua bộ tạo xung LEDC của ESP32, KHÔNG BẮT BUỘC cài thêm thư viện ngoài!)
 */

#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <WebSocketsClient.h>
#include <MQTTPubSubClient.h>
#include "DHT.h"
#include <ArduinoJson.h>

// ─────────────────────────────────────────────────────────────
//  TÍCH HỢP ĐIỀU KHIỂN SERVO TRÊN ESP32
//  (Tự động hỗ trợ cả Core ESP32 v2.x và v3.x mà không sợ lỗi thư viện)
// ─────────────────────────────────────────────────────────────
#if __has_include(<ESP32Servo.h>)
  #include <ESP32Servo.h>
#else
  class Servo {
  private:
    int _pin = -1;
    int _channel = 0;
  public:
    void attach(int pin, int channel = 0) {
      _pin = pin;
      _channel = channel;
      #if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
        ledcAttach(_pin, 50, 16);
      #else
        ledcSetup(_channel, 50, 16);
        ledcAttachPin(_pin, _channel);
      #endif
    }
    void write(int angle) {
      if (_pin < 0) return;
      angle = constrain(angle, 0, 180);
      // Tần số 50Hz (chu kỳ 20ms). 16-bit: 0.5ms = 1638, 2.5ms = 8192
      uint32_t duty = (uint32_t)(1638 + ((float)angle / 180.0f) * (8192 - 1638));
      #if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
        ledcWrite(_pin, duty);
      #else
        ledcWrite(_channel, duty);
      #endif
    }
  };
#endif

// ─────────────────────────────────────────────────────────────
//  SƠ ĐỒ CHÂN (PINOUT ESP32 CHÍNH XÁC THEO YÊU CẦU)
// ─────────────────────────────────────────────────────────────
#define PIN_GAS       34  // D34 (GPIO34) - Cảm biến Khí Gas MQ2 (ADC1)
#define PIN_FAN       26  // D26 (GPIO26) - Relay Quạt
#define PIN_LED       25  // D25 (GPIO25) - Relay Đèn
#define PIN_FIRE      19  // D19 (GPIO19) - Cảm biến Lửa (Flame)
#define PIN_DHT       27  // D27 (GPIO27) - Cảm biến DHT11 (Nhiệt độ & Độ ẩm)
#define PIN_DOOR      13  // D13 (GPIO13) - Động cơ Servo (Cửa duy nhất)
#define PIN_BUZZER    14  // D14 (GPIO14) - Còi báo động

#define DHTTYPE       DHT11
#define RELAY_ON      HIGH
#define RELAY_OFF     LOW
#define GAS_THRESHOLD 700 // Ngưỡng cảnh báo Gas chính xác (0 - 1023, không khí sạch ~150-350, phát hiện gas/khói > 700)

// ─────────────────────────────────────────────────────────────
//  PORTAL CẤU HÌNH WIFI TĨNH
// ─────────────────────────────────────────────────────────────
#define AP_SSID       "SmartHome"
#define AP_PASSWORD   ""
IPAddress apIP(192, 168, 4, 1);
const byte DNS_PORT = 53;

// ─────────────────────────────────────────────────────────────
//  THÔNG SỐ KẾT NỐI MQTT (CLOUDFLARE TUNNEL WSS)
// ─────────────────────────────────────────────────────────────
#define MQTT_HOST     "mqtt.duynguyen.io.vn"
#define MQTT_PORT     443
#define MQTT_PATH     "/mqtt"
#define CHIP_ID       "123"

#define DEV_TEMP      "123_temp_livingroom"
#define DEV_HUMI      "123_humi_living_room"
#define DEV_LED       "123_led1"
#define DEV_FAN       "123_fan_livingroom"
#define DEV_DOOR      "123_door_livingroom1"
#define DEV_GAS       "123_gas_livingroom"
#define DEV_FIRE      "123_fire_livingroom"

// ─────────────────────────────────────────────────────────────
//  MULTI-WIFI (LƯU VÀO FLASH EEPROM)
// ─────────────────────────────────────────────────────────────
#define EEPROM_SIZE   512
#define MAX_WIFI      5

struct WifiEntry {
  char ssid[32];
  char pass[32];
};
WifiEntry wifiList[MAX_WIFI];
int wifiCount = 0;

// ─────────────────────────────────────────────────────────────
//  CHU KỲ THỰC HIỆN TÁC VỤ (INTERVALS)
// ─────────────────────────────────────────────────────────────
#define TELEMETRY_MS   5000
#define SENSOR_FAST_MS 500
#define HEARTBEAT_MS  30000
#define RECONNECT_MS  10000

// ─────────────────────────────────────────────────────────────
//  KHỞI TẠO ĐỐI TƯỢNG
// ─────────────────────────────────────────────────────────────
DHT dht(PIN_DHT, DHTTYPE);
Servo servoDoor;
WebServer webServer(80);
DNSServer dnsServer;
WebSocketsClient wsClient;
MQTTPubSubClient mqttClient;

// ─────────────────────────────────────────────────────────────
//  BIẾN TRẠNG THÁI HỆ THỐNG
// ─────────────────────────────────────────────────────────────
bool portalActive = false;
int doorAngle = 0;
String ledState = "OFF";
String fanState = "OFF";

bool isGasAlert = false;
bool isFireAlert = false;

unsigned long lastTelemetry = 0;
unsigned long lastFastRead = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastReconnect = 0;
unsigned long lastMqttRetry = 0;
bool wssReady = false;
bool mqttLoggedOk = false;

// ─────────────────────────────────────────────────────────────
//  HÀM HỖ TRỢ TRẠNG THÁI
// ─────────────────────────────────────────────────────────────
String relayRead(uint8_t pin) {
  return (digitalRead(pin) == RELAY_ON) ? "ON" : "OFF";
}

void adjustDoorAngle(int angle) {
  doorAngle = constrain(angle, 0, 90);
  servoDoor.write(doorAngle);
}

// ─────────────────────────────────────────────────────────────
//  QUẢN LÝ LƯU TRỮ DANH SÁCH MẠNG WIFI (EEPROM FLASH)
// ─────────────────────────────────────────────────────────────
void saveWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(0, wifiCount);
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.put(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.commit();
  EEPROM.end();
}

void loadWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(0, wifiCount);
  if (wifiCount < 0 || wifiCount > MAX_WIFI) wifiCount = 0;
  
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.get(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.end();
}

void addOrUpdateWifi(String ssid, String pass) {
  for (int i = 0; i < wifiCount; i++) {
    if (String(wifiList[i].ssid) == ssid) {
      pass.toCharArray(wifiList[i].pass, 32);
      saveWifiList();
      return;
    }
  }
  if (wifiCount >= MAX_WIFI) {
    for (int i = 0; i < MAX_WIFI - 1; i++) wifiList[i] = wifiList[i+1];
    wifiCount = MAX_WIFI - 1;
  }
  ssid.toCharArray(wifiList[wifiCount].ssid, 32);
  pass.toCharArray(wifiList[wifiCount].pass, 32);
  wifiCount++;
  saveWifiList();
}

bool connectBestWifi() {
  Serial.println("\n🔍 Quét danh sách mạng WiFi đã lưu...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);

  if (wifiCount == 0) {
    Serial.println("❌ Chưa có mạng WiFi nào được lưu trong bộ nhớ!");
    return false;
  }

  int n = WiFi.scanNetworks();
  int bestIdx = -1;
  int bestRSSI = -999;

  if (n > 0) {
    for (int i = 0; i < n; i++) {
      String scannedSSID = WiFi.SSID(i);
      int rssi = WiFi.RSSI(i);
      for (int w = 0; w < wifiCount; w++) {
        if (String(wifiList[w].ssid) == scannedSSID && rssi > bestRSSI) {
          bestRSSI = rssi;
          bestIdx = w;
        }
      }
    }
    WiFi.scanDelete();
  }

  if (bestIdx < 0) {
    Serial.println("⚠️ Không thấy qua quét sóng, thử mạng đã lưu gần nhất...");
    bestIdx = wifiCount - 1;
  } else {
    Serial.printf("📶 Tìm thấy mạng tốt nhất: %s (%ddBm)\n", wifiList[bestIdx].ssid, bestRSSI);
  }

  Serial.printf("🚀 Đang kết nối tới: %s\n", wifiList[bestIdx].ssid);
  WiFi.begin(wifiList[bestIdx].ssid, wifiList[bestIdx].pass);
  
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi OK! IP Của mạch: " + WiFi.localIP().toString());
    return true;
  } else {
    Serial.println("\n❌ Kết nối WiFi thất bại!");
    return false;
  }
}

// ─────────────────────────────────────────────────────────────
//  MQTT GỬI & NHẬN LỆNH ĐIỀU KHIỂN
// ─────────────────────────────────────────────────────────────
void mqttPub(const char* device, const String& payload) {
  if (!mqttClient.isConnected()) return;
  String topic = "tele/" + String(device) + "/status";
  mqttClient.publish(topic, payload, false, 0);
}

void pubOnline()     { mqttPub(CHIP_ID, "online"); }
void pubTemp(float t){ mqttPub(DEV_TEMP, "{\"value\":" + String(t,1) + "}"); }
void pubHumi(float h){ mqttPub(DEV_HUMI, "{\"value\":" + String(h,1) + "}"); }
void pubLed()   { ledState = relayRead(PIN_LED); mqttPub(DEV_LED, "{\"value\":\""+ledState+"\"}"); }
void pubFan()   { fanState = relayRead(PIN_FAN); mqttPub(DEV_FAN, "{\"value\":\""+fanState+"\"}"); }
void pubDoor()  { mqttPub(DEV_DOOR, "{\"value\":" + String(doorAngle) + "}"); }
void pubGas()   { mqttPub(DEV_GAS, isGasAlert ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}"); }
void pubFire()  { mqttPub(DEV_FIRE, isFireAlert ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}"); }

void mqttCallback(const String& topicStr, const String& payload, const size_t size) {
  String topic = topicStr;
  String cmd = payload;
  cmd.trim();

  Serial.printf("📩 Nhận lệnh [%s]: %s\n", topic.c_str(), cmd.c_str());

  if (topic.indexOf(DEV_LED) >= 0) {
    digitalWrite(PIN_LED, (cmd == "ON") ? RELAY_ON : RELAY_OFF);
    pubLed();
  }
  else if (topic.indexOf(DEV_FAN) >= 0) {
    digitalWrite(PIN_FAN, (cmd == "ON") ? RELAY_ON : RELAY_OFF);
    pubFan();
  }
  else if (topic.indexOf(DEV_DOOR) >= 0) {
    int a = (cmd == "ON") ? 90 : (cmd == "OFF" ? 0 : cmd.toInt());
    adjustDoorAngle(a);
    pubDoor();
  }
}

void reconnectMQTT() {
  if (mqttClient.isConnected()) return;

  // Bắt buộc WebSocket kết nối thành công trước khi kết nối MQTT
  if (!wsClient.isConnected()) {
    Serial.println("⏳ [MQTT] Chờ WebSocket SSL sẵn sàng...");
    Serial.printf("   host=%s port=%d path=%s wifi=%s\n",
                  MQTT_HOST, MQTT_PORT, MQTT_PATH,
                  (WiFi.status() == WL_CONNECTED) ? "OK" : "FAIL");
    return;
  }
  wssReady = true;

  uint32_t chipId = (uint32_t)ESP.getEfuseMac();
  String clientId = "ESP32-" + String(chipId, HEX);
  String lwtTopic = "tele/" + String(CHIP_ID) + "/status";

  Serial.printf("📡 [MQTT] CONNECT clientId=%s ...\n", clientId.c_str());
  mqttClient.setWill(lwtTopic, "offline", true, 1);

  if (mqttClient.connect(clientId, "", "")) {
    mqttLoggedOk = true;
    Serial.println("✅ [MQTT] CONNECTED!");
    Serial.println("   → publish tele/" + String(CHIP_ID) + "/status = online");
    pubOnline(); wsClient.loop(); delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_LED) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = ""; for(unsigned int i=0; i<size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_LED) + "/POWER", cmd, size);
    });
    wsClient.loop(); delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_FAN) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = ""; for(unsigned int i=0; i<size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_FAN) + "/POWER", cmd, size);
    });
    wsClient.loop(); delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_DOOR) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = ""; for(unsigned int i=0; i<size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_DOOR) + "/POWER", cmd, size);
    });
    wsClient.loop(); delay(50);

    Serial.println("📥 [MQTT] Subscribed: LED/FAN/DOOR");
    pubLed(); wsClient.loop(); delay(50);
    pubFan(); wsClient.loop(); delay(50);
    pubDoor(); wsClient.loop();
  } else {
    mqttLoggedOk = false;
    Serial.println("❌ [MQTT] CONNECT FAIL (WSS OK nhưng broker từ chối / timeout CONNACK)");
  }
}

// ─────────────────────────────────────────────────────────────
//  GIAO DIỆN WEB PORTAL CẤU HÌNH WIFI TĨNH
// ─────────────────────────────────────────────────────────────
const char PORTAL_HTML[] PROGMEM = R"rawhtml(
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartHome Setup</title>
<style>body{font-family:sans-serif;background:#0a0e1a;color:#e2e8f0;display:flex;justify-content:center;padding:20px}
.c{max-width:400px;width:100%;} input{width:100%;padding:10px;margin-bottom:10px;border-radius:5px;border:none} button{padding:10px;width:100%;background:#0ea5e9;color:#fff;border:none;border-radius:5px;cursor:pointer;font-weight:bold}
#st{margin-top:15px;text-align:center;font-weight:bold;padding:10px;border-radius:5px;display:none;}</style>
</head><body><div class="c"><h2>⚙️ SmartHome WiFi</h2>
<button onclick="scan()" style="margin-bottom:10px;background:#6366f1;">🔍 Quét mạng xung quanh</button><div id="w" style="margin-bottom:10px;line-height:1.8;cursor:pointer;"></div>
<input id="s" placeholder="Tên WiFi"><input type="password" id="p" placeholder="Mật khẩu">
<button onclick="conn()">🚀 Kết nối</button><div id="st"></div></div>
<script>
function scan() {
  document.getElementById('w').innerHTML = 'Đang quét...';
  fetch('/scan')
    .then(r => r.json())
    .then(l => {
      document.getElementById('w').innerHTML = l.map(n => 
        `<div style="padding:5px; background:#1e293b; margin-top:5px; border-radius:5px;" onclick="document.getElementById('s').value='${n.ssid}'">📶 ${n.ssid} (${n.rssi}dBm)</div>`
      ).join('');
    })
    .catch(e => {
      document.getElementById('w').innerHTML = '❌ Lỗi quét mạng';
    });
}
function conn() {
  const s = document.getElementById('s').value;
  const p = document.getElementById('p').value;
  if (!s) { alert("Vui lòng nhập tên WiFi!"); return; }
  
  const st = document.getElementById('st');
  st.style.display = 'block';
  st.innerHTML = '⏳ Đang kết nối thử... Vui lòng đợi đến 15s!';
  st.style.background = '#334155';
  st.style.color = '#fff';
  
  fetch('/connect', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'ssid=' + encodeURIComponent(s) + '&pass=' + encodeURIComponent(p)
  })
  .then(r => r.json())
  .then(d => {
    if (d.ok) {
      st.style.background = '#22c55e';
      st.innerHTML = '✅ KẾT NỐI THÀNH CÔNG!<br>Mạch đang tự khởi động lại...';
      alert("Kết nối WiFi thành công! Mạch đang khởi động lại.");
    } else {
      st.style.background = '#ef4444';
      st.innerHTML = '❌ LỖI: ' + (d.message || 'Kết nối thất bại');
    }
  })
  .catch(e => {
    st.style.background = '#ef4444';
    st.innerHTML = '❌ LỖI MẠNG!<br>Vui lòng thử lại...';
  });
}
</script></body></html>
)rawhtml";

void handleNotFound() {
  webServer.sendHeader("Location", "http://192.168.4.1/", true);
  webServer.send(302, "text/plain", "");
}

void handleRoot() { webServer.send_P(200, "text/html", PORTAL_HTML); }

void handleScan() {
  int n = WiFi.scanNetworks();
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i) json += ",";
    json += "{\"ssid\":\""+WiFi.SSID(i)+"\",\"rssi\":"+String(WiFi.RSSI(i))+"}";
  }
  json += "]"; WiFi.scanDelete(); webServer.send(200, "application/json", json);
}

void handleConnect() {
  String ssid = webServer.arg("ssid"); 
  String pass = webServer.arg("pass");
  if (ssid.length() > 0) {
    Serial.printf("Thử kết nối đến WiFi: %s\n", ssid.c_str());
    WiFi.begin(ssid.c_str(), pass.c_str());
    for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
      delay(500);
    }
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("Kết nối WiFi thử nghiệm thành công!");
      addOrUpdateWifi(ssid, pass);
      webServer.send(200, "application/json", "{\"ok\":true}");
      delay(1000); 
      ESP.restart();
    } else {
      Serial.println("Kết nối WiFi thử nghiệm thất bại!");
      WiFi.disconnect();
      webServer.send(200, "application/json", "{\"ok\":false, \"message\":\"Sai mật khẩu hoặc WiFi quá yếu.\"}");
    }
  } else {
    webServer.send(200, "application/json", "{\"ok\":false, \"message\":\"Chưa nhập tên WiFi!\"}");
  }
}

void startPortal() {
  portalActive = true;
  Serial.println("\n🌐 Khởi tạo WiFi Access Point...");
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  dnsServer.start(DNS_PORT, "*", apIP);
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/scan", HTTP_GET, handleScan);
  webServer.on("/connect", HTTP_POST, handleConnect);
  webServer.onNotFound(handleNotFound);
  webServer.begin();
  Serial.println("✅ Portal đã sẵn sàng!");
  Serial.println("👉 Vui lòng kết nối điện thoại vào WiFi: SmartHome");
  Serial.println("👉 Sau đó truy cập trang: http://192.168.4.1");
}

// ─────────────────────────────────────────────────────────────
//  DOUBLE RESET DETECTOR (SỬ DỤNG BỘ NHỚ RTC CỦA ESP32)
// ─────────────────────────────────────────────────────────────
#define DOUBLE_RESET_MAGIC 0x12345678
RTC_DATA_ATTR uint32_t rtcMagic = 0;
bool isDoubleReset = false;

void checkDoubleReset() {
  if (rtcMagic == DOUBLE_RESET_MAGIC) {
    isDoubleReset = true;
    Serial.println("\n⚠️ DOUBLE RESET DETECTED! Xóa toàn bộ cấu hình WiFi...");
    rtcMagic = 0;
    wifiCount = 0;
    saveWifiList();
    Serial.println("✅ Đã xóa WiFi. Khởi động chế độ cài đặt mạng (Portal)...");
  } else {
    isDoubleReset = false;
    rtcMagic = DOUBLE_RESET_MAGIC;
  }
}

void clearDoubleResetFlag() {
  if (rtcMagic == DOUBLE_RESET_MAGIC) {
    rtcMagic = 0;
  }
}

// ─────────────────────────────────────────────────────────────
//  SETUP
// ─────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n╔════════════════════════════════════╗");
  Serial.println("║  🚀 SmartHome ESP32 Khởi động    ║");
  Serial.println("╚════════════════════════════════════╝");

  // Cấu hình Relay & Còi
  pinMode(PIN_LED, OUTPUT); digitalWrite(PIN_LED, RELAY_OFF);
  pinMode(PIN_FAN, OUTPUT); digitalWrite(PIN_FAN, RELAY_OFF);
  pinMode(PIN_BUZZER, OUTPUT); digitalWrite(PIN_BUZZER, LOW);
  
  // Cấu hình Cảm biến Digital
  pinMode(PIN_FIRE, INPUT_PULLUP);
  
  // ESP32 ADC: Cấu hình độ phân giải 10-bit (0 - 1023) để khớp ngưỡng GAS 500 như ESP8266
  analogReadResolution(10);

  dht.begin();
  
  // Khởi tạo Duy nhất 1 Servo Cửa (D13: 0 - 90 độ)
  servoDoor.attach(PIN_DOOR, 0);
  servoDoor.write(0);

  // Cấu hình WebSocket SSL Port 443
  Serial.printf("🌐 [WSS] beginSSL %s:%d%s\n", MQTT_HOST, MQTT_PORT, MQTT_PATH);
  wsClient.beginSSL(MQTT_HOST, MQTT_PORT, MQTT_PATH);
  wsClient.setExtraHeaders("Sec-WebSocket-Protocol: mqtt");
  wsClient.setReconnectInterval(5000);

  // Lắng nghe chi tiết sự kiện WebSocket để Debug trên Serial Monitor
  wsClient.onEvent([](WStype_t type, uint8_t * payload, size_t length) {
    switch (type) {
      case WStype_DISCONNECTED:
        wssReady = false;
        mqttLoggedOk = false;
        Serial.println("🔴 [WSS] DISCONNECTED");
        break;
      case WStype_CONNECTED:
        wssReady = true;
        Serial.printf("🟢 [WSS] CONNECTED → %s\n", payload ? (const char*)payload : MQTT_HOST);
        // Thử MQTT ngay khi WSS vừa lên
        lastMqttRetry = 0;
        break;
      case WStype_ERROR:
        wssReady = false;
        Serial.println("❌ [WSS] ERROR (SSL handshake / upgrade thất bại)");
        break;
      default:
        break;
    }
  });

  mqttClient.begin(wsClient);
  mqttClient.setTimeout(8000);

  loadWifiList();
  checkDoubleReset();

  if (isDoubleReset) {
    startPortal();
  } else {
    if (!(wifiCount > 0 && connectBestWifi())) {
      startPortal();
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  LOOP
// ─────────────────────────────────────────────────────────────
int wifiRetries = 0;

void loop() {
  // Xóa cờ Double Reset nếu mạch đã chạy ổn định quá 3 giây
  if (millis() > 3000 && rtcMagic == DOUBLE_RESET_MAGIC) {
    clearDoubleResetFlag();
  }

  if (portalActive) {
    dnsServer.processNextRequest();
    webServer.handleClient();
    return;
  }

  unsigned long now = millis();

  // Kiểm tra & Tự động kết nối lại WiFi nếu mất kết nối
  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnect >= RECONNECT_MS) {
      lastReconnect = now;
      if (connectBestWifi()) {
        wifiRetries = 0;
      } else {
        wifiRetries++;
        if (wifiRetries >= 3) {
          Serial.println("⚠️ Không thể kết nối lại mạng! Chuyển sang chế độ Portal cấu hình...");
          startPortal();
          wifiRetries = 0;
        }
      }
    }
    return;
  } else {
    wifiRetries = 0;
  }

  wsClient.loop();
  mqttClient.update();

  // Debug trạng thái định kỳ + reconnect MQTT (timer riêng, không dùng chung WiFi)
  if (!mqttClient.isConnected()) {
    if (now - lastMqttRetry >= 5000) {
      lastMqttRetry = now;
      if (wsClient.isConnected()) wssReady = true;
      Serial.printf("🔎 [DEBUG] wifi=%d wsConnected=%d mqtt=%d\n",
                    WiFi.status() == WL_CONNECTED,
                    wsClient.isConnected(),
                    mqttClient.isConnected());
      reconnectMQTT();
    }
  } else if (!mqttLoggedOk) {
    mqttLoggedOk = true;
    Serial.println("✅ [MQTT] đang giữ kết nối ổn định");
  }

  // Đọc nhanh cảm biến khẩn cấp (Gas, Lửa, Mưa) mỗi 500ms
  if (now - lastFastRead >= SENSOR_FAST_MS) {
    lastFastRead = now;

    // Đọc Gas MQ2 (0 - 1023) - Lấy trung bình 8 mẫu chống nhiễu xung ADC
    long gasSum = 0;
    for (int i = 0; i < 8; i++) {
      gasSum += analogRead(PIN_GAS);
      delay(1);
    }
    int gasVal = gasSum / 8;
    bool currentGasAlert = (gasVal > GAS_THRESHOLD);
    if (currentGasAlert != isGasAlert) {
      isGasAlert = currentGasAlert;
      Serial.printf("🚨 Cảnh báo Gas: %s (Giá trị ADC: %d / Ngưỡng: %d)\n", 
                    isGasAlert ? "BẬT" : "TẮT", gasVal, GAS_THRESHOLD);
      pubGas();
    }

    // Đọc cảm biến Lửa (Chân D19: LOW là phát hiện lửa)
    bool currentFireAlert = (digitalRead(PIN_FIRE) == LOW);
    if (currentFireAlert != isFireAlert) {
      isFireAlert = currentFireAlert;
      pubFire();
    }

    // Bật còi báo động ngay khi có Khí Gas HOẶC Lửa
    if (isGasAlert || isFireAlert) {
      digitalWrite(PIN_BUZZER, HIGH);
    } else {
      digitalWrite(PIN_BUZZER, LOW);
    }
  }

  // Gửi gói Heartbeat mỗi 30s
  if (now - lastHeartbeat >= HEARTBEAT_MS) {
    lastHeartbeat = now;
    pubOnline();
  }

  // Gửi Telemetry Nhiệt độ & Độ ẩm mỗi 5s
  if (now - lastTelemetry >= TELEMETRY_MS) {
    lastTelemetry = now;
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(t) && !isnan(h)) {
      Serial.printf("🌡️ Nhiệt độ: %.1f°C | 💧 Độ ẩm: %.1f%%\n", t, h);
      pubTemp(t); 
      pubHumi(h);
    } else {
      Serial.println("⚠️ Lỗi: Không đọc được cảm biến DHT!");
    }
  }
}
