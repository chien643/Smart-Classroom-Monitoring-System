#include <Keypad.h>
#include "DHT.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include <Wire.h>
#include <BH1750.h>

// ================= WIFI =================
#define WIFI_SSID "Loan"
#define WIFI_PASS "1122/23/6"

// ================= FIREBASE =================
#define API_KEY           "AIzaSyCSJlrLC7YqvQDrcXOEFbW6Ax00NU9qtNk"
#define DATABASE_URL      "https://doan2-75243-default-rtdb.firebaseio.com/"
#define USER_EMAIL        "chienpro643@gmail.com"
#define USER_PASSWORD     "jayanhoo2004"

FirebaseData fbdo;
FirebaseData fbStream;
FirebaseAuth auth;
FirebaseConfig config;

// ================= MQTT =================
const char* mqtt_server = "192.168.2.36";
const int   mqtt_port   = 1883;
const char* mqtt_user   = "chienhn1604";
const char* mqtt_pass   = "jayanhoo2004";

WiFiClient espClient;
PubSubClient client(espClient);

// ================= SENSOR =================
#define DHTPIN    15
#define DHTTYPE   DHT22
DHT dht(DHTPIN, DHTTYPE);

// BH1750 I2C pins
#define I2C_SDA   13
#define I2C_SCL   22
BH1750 lightMeter;

// ================= AUTO THRESHOLDS (có hysteresis) =================
#define TEMP_ON_THRESHOLD   34.0
#define TEMP_OFF_THRESHOLD  31.0

#define LIGHT_ON_LUX        150.0
#define LIGHT_OFF_LUX       500.0

// Auto mode: true = auto hoạt động, false = auto bị vô hiệu hóa
bool autoEnabled = true;

// ================= KEYPAD 3x4 =================
const byte ROWS = 4, COLS = 3;
char keys[ROWS][COLS] = {
  {'1','2','3'},
  {'4','5','6'},
  {'7','8','9'},
  {'*','0','#'}
};

byte rowPins[ROWS] = {32, 33, 25, 26};
byte colPins[COLS] = {27, 14, 12};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

unsigned long lastKeyTime = 0;
const unsigned long keyGap = 120;

// ================= RELAY =================
int  relays[6]     = {4, 5, 18, 19, 21, 23};
bool relayState[6] = {0,0,0,0,0,0}; // true=ON
// Relay active LOW: LOW=ON, HIGH=OFF

// ================= MQTT TOPICS =================
const char* topic_relay_cmd[6] = {
  "home/classroom/relay1/set",
  "home/classroom/relay2/set",
  "home/classroom/relay3/set",
  "home/classroom/relay4/set",
  "home/classroom/relay5/set",
  "home/classroom/relay6/set"
};
const char* topic_relay_state[6] = {
  "home/classroom/relay1/state",
  "home/classroom/relay2/state",
  "home/classroom/relay3/state",
  "home/classroom/relay4/state",
  "home/classroom/relay5/state",
  "home/classroom/relay6/state"
};

const char* topic_temp  = "home/classroom/temperature";
const char* topic_hum   = "home/classroom/humidity";
const char* topic_light = "home/classroom/light";

//  AUTO topics cho App
const char* topic_auto_cmd   = "home/classroom/auto/set";
const char* topic_auto_state = "home/classroom/auto/state";

// Firebase path lưu auto
const char* fb_auto_path = "/classroom/auto/enabled";

// ================= STATE FLAGS =================
enum Source { SRC_KEYPAD, SRC_MQTT, SRC_FIREBASE };
static bool firebaseInited = false;
static bool streamStarted  = false;
static bool timeSynced     = false;

// ====================== FIREBASE PATH HELPERS ======================
String getDeviceGroup(int id) {
  if (id >= 0 && id <= 2) return "quat";
  if (id >= 3 && id <= 5) return "den";
  return "unknown";
}
String getDeviceName(int id) {
  switch(id) {
    case 0: return "quat1";
    case 1: return "quat2";
    case 2: return "quat3";
    case 3: return "den1";
    case 4: return "den2";
    case 5: return "den3";
  }
  return "unknown";
}
String getRelayPath(int id) {
  return "/classroom/devices/" + getDeviceGroup(id) + "/" + getDeviceName(id);
}

// ====================== APPLY RELAY ======================
void applyRelay(int id, bool newState, Source src) {
  if (id < 0 || id >= 6) return;

  if (relayState[id] == newState) return;

  relayState[id] = newState;
  digitalWrite(relays[id], relayState[id] ? LOW : HIGH);

  // MQTT state
  if (client.connected()) {
    client.publish(topic_relay_state[id], relayState[id] ? "ON" : "OFF", false);
  }

  // Firebase (không ghi ngược nếu nguồn từ Firebase stream)
  if (src != SRC_FIREBASE && firebaseInited && Firebase.ready()) {
    String path = getRelayPath(id);
    Firebase.RTDB.setInt(&fbdo, path.c_str(), relayState[id] ? 1 : 0);
  }

  const char* s = (src == SRC_KEYPAD) ? "KEYPAD" : (src == SRC_MQTT) ? "MQTT" : "FIREBASE";
  Serial.printf("[%s] Relay %d -> %s\n", s, id + 1, relayState[id] ? "ON" : "OFF");
}

// ====================== SET AUTO (sync MQTT + Firebase) ======================
void setAutoEnabled(bool enabled, Source src) {
  if (autoEnabled == enabled) return;
  autoEnabled = enabled;

  // MQTT state cho app
  if (client.connected()) {
    client.publish(topic_auto_state, autoEnabled ? "ON" : "OFF", true);
  }

  // Firebase sync auto
  if (src != SRC_FIREBASE && firebaseInited && Firebase.ready()) {
    Firebase.RTDB.setInt(&fbdo, fb_auto_path, autoEnabled ? 1 : 0);
  }

  Serial.printf("[AUTO] %s (%s)\n", autoEnabled ? "ENABLED" : "DISABLED",
                (src == SRC_KEYPAD) ? "KEYPAD" : (src == SRC_MQTT) ? "MQTT" : "FIREBASE");
}

// ====================== FIREBASE SENSOR UPDATE ======================
void updateFirebaseSensor(float t, float h, float lux) {
  if (!firebaseInited || !Firebase.ready()) return;

  Firebase.RTDB.setFloat(&fbdo, "/classroom/sensor/temperature", t);
  Firebase.RTDB.setFloat(&fbdo, "/classroom/sensor/humidity", h);
  Firebase.RTDB.setFloat(&fbdo, "/classroom/sensor/light", lux);
}

// ====================== MQTT CALLBACK ======================
void mqttCallback(char* topic, byte* message, unsigned int length) {
  String msg;
  for (unsigned int i=0; i<length; i++) msg += (char)message[i];
  msg.trim();

  // ✅ Auto command từ App
  if (String(topic) == topic_auto_cmd) {
    bool en = (msg == "ON" || msg == "1");
    setAutoEnabled(en, SRC_MQTT);
    return;
  }

  // Relay command
  for (int i=0; i<6; i++) {
    if (String(topic) == topic_relay_cmd[i]) {
      bool newState = (msg == "ON" || msg == "1");
      applyRelay(i, newState, SRC_MQTT);
      return;
    }
  }
}

// ====================== FIREBASE STREAM CALLBACK ======================
void firebaseStreamCallback(FirebaseStream data) {
  String path = data.dataPath();
  int value = 0;

  if (data.dataTypeEnum() == fb_esp_rtdb_data_type_integer) value = data.intData();
  else if (data.dataTypeEnum() == fb_esp_rtdb_data_type_boolean) value = data.boolData() ? 1 : 0;
  else return;

  for (int i = 0; i < 6; i++) {
    String expect = "/" + getDeviceGroup(i) + "/" + getDeviceName(i);
    if (path == expect) {
      bool newState = (value == 1);
      applyRelay(i, newState, SRC_FIREBASE);
      return;
    }
  }
}

void firebaseStreamTimeout(bool timeout) {
  if (timeout) Serial.println("[FIREBASE] Stream timeout");
}

// ====================== WIFI NON-BLOCKING ======================
unsigned long lastWiFiAttempt = 0;

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastWiFiAttempt < 5000) return;
  lastWiFiAttempt = now;

  Serial.println("[WIFI] Reconnecting...");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// ====================== TIME SYNC NON-BLOCKING ======================
unsigned long timeSyncStart = 0;

void ensureTimeSynced() {
  if (timeSynced) return;
  if (WiFi.status() != WL_CONNECTED) return;

  if (timeSyncStart == 0) {
    Serial.println("[TIME] Starting NTP sync...");
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    timeSyncStart = millis();
  }

  time_t now = time(nullptr);
  if (now > 100000) {
    timeSynced = true;
    Serial.println("[TIME] OK");
    return;
  }

  if (millis() - timeSyncStart > 12000) {
    Serial.println("[TIME] NTP timeout -> continue offline");
    timeSyncStart = 0;
  }
}

// ====================== FIREBASE INIT + STREAM ======================
unsigned long lastFirebaseAttempt = 0;

void ensureFirebase() {
  if (firebaseInited) return;
  if (WiFi.status() != WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastFirebaseAttempt < 5000) return;
  lastFirebaseAttempt = now;

  Serial.println("[FIREBASE] init...");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  firebaseInited = true;
  Serial.println("[FIREBASE] init called");
}

unsigned long lastStreamAttempt = 0;

void ensureFirebaseStream() {
  if (!firebaseInited) return;
  if (streamStarted) return;
  if (!Firebase.ready()) return;

  unsigned long now = millis();
  if (now - lastStreamAttempt < 3000) return;
  lastStreamAttempt = now;

  Serial.println("[FIREBASE] starting stream...");

  if (Firebase.RTDB.beginStream(&fbStream, "/classroom/devices")) {
    Firebase.RTDB.setStreamCallback(&fbStream, firebaseStreamCallback, firebaseStreamTimeout);
    streamStarted = true;
    Serial.println("[FIREBASE] stream started");
  } else {
    Serial.printf("[FIREBASE] stream error: %s\n", fbStream.errorReason().c_str());
  }
}

// ====================== MQTT NON-BLOCKING ======================
unsigned long lastMQTTAttempt = 0;

void ensureMQTT() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (client.connected()) return;

  unsigned long now = millis();
  if (now - lastMQTTAttempt < 3000) return;
  lastMQTTAttempt = now;

  Serial.print("[MQTT] Connecting...");
  if (client.connect("ESP32_Classroom", mqtt_user, mqtt_pass)) {
    Serial.println("OK");
    client.subscribe("home/classroom/#");

    // ✅ Publish trạng thái auto để app thấy ngay
    client.publish(topic_auto_state, autoEnabled ? "ON" : "OFF", true);

  } else {
    Serial.print("FAIL rc=");
    Serial.println(client.state());
  }
}

// ====================== AUTO APPLY HELPERS ======================
void setAllFans(bool on, Source src) {      // relay 0..2
  for (int i = 0; i <= 2; i++) applyRelay(i, on, src);
}
void setAllLights(bool on, Source src) {    // relay 3..5
  for (int i = 3; i <= 5; i++) applyRelay(i, on, src);
}

// ====================== SETUP ======================
void setup() {
  Serial.begin(9600);

  dht.begin();

  Wire.begin(I2C_SDA, I2C_SCL);
  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println("[BH1750] Ready");
  } else {
    Serial.println("[BH1750] Init failed (check wiring/I2C addr)");
  }

  for (int i=0; i<6; i++) {
    pinMode(relays[i], OUTPUT);
    digitalWrite(relays[i], HIGH);
  }

  keypad.setDebounceTime(60);
  keypad.setHoldTime(600);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.println("[BOOT] Started");

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
}

// ====================== LOOP ======================
void loop() {
  // 1) Keypad
  char key = keypad.getKey();
  if (key) {
    unsigned long now = millis();
    if (now - lastKeyTime > keyGap) {
      lastKeyTime = now;

      if (key == '*') {
        setAutoEnabled(!autoEnabled, SRC_KEYPAD);
      }

      if (key >= '1' && key <= '6') {
        int idx = key - '1';
        applyRelay(idx, !relayState[idx], SRC_KEYPAD);
      }
    }
  }

  // 2) Network
  ensureWiFi();
  ensureTimeSynced();
  ensureMQTT();
  client.loop();

  ensureFirebase();
  ensureFirebaseStream();

  // 3) SENSOR mỗi 5s
  static unsigned long lastSensor = 0;
  if (millis() - lastSensor > 5000) {
    lastSensor = millis();

    float t = dht.readTemperature();
    float h = dht.readHumidity();

    if (isnan(t) || isnan(h)) {
      Serial.println("[SENSOR] DHT read failed");
      return;
    }

    float lux = lightMeter.readLightLevel();
    if (lux < 0) {
      Serial.println("[BH1750] Read error");
      return;
    }

    // ===== AUTO CONTROL =====
    if (autoEnabled) {
      bool anyFanOn = relayState[0] || relayState[1] || relayState[2];
      if (t >= TEMP_ON_THRESHOLD && !anyFanOn) {
        setAllFans(true, SRC_KEYPAD);
        Serial.println("[AUTO] Fans ON (Temp high)");
      } else if (t <= TEMP_OFF_THRESHOLD && anyFanOn) {
        setAllFans(false, SRC_KEYPAD);
        Serial.println("[AUTO] Fans OFF (Temp low)");
      }

      bool anyLightOn = relayState[3] || relayState[4] || relayState[5];
      if (lux < LIGHT_ON_LUX && !anyLightOn) {
        setAllLights(true, SRC_KEYPAD);
        Serial.println("[AUTO] Lights ON (Low lux)");
      } else if (lux > LIGHT_OFF_LUX && anyLightOn) {
        setAllLights(false, SRC_KEYPAD);
        Serial.println("[AUTO] Lights OFF (High lux)");
      }
    }

    // MQTT publish sensor
    if (client.connected()) {
      char buf[20];
      dtostrf(t, 0, 1, buf);
      client.publish(topic_temp, buf,true);

      dtostrf(h, 0, 1, buf);
      client.publish(topic_hum, buf,true);

      dtostrf(lux, 0, 1, buf);
      client.publish(topic_light, buf,true);
    }

    // Firebase sensor
    updateFirebaseSensor(t, h, lux);

    Serial.printf("[SENSOR] T:%.1f H:%.1f Light:%.1f lux | AUTO:%s\n",
                  t, h, lux, autoEnabled ? "ON" : "OFF");
  }
}
