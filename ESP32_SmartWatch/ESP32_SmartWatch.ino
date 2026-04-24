// ============================================================================
// ESP32-S3 Smart Watch — v3 with WiFi, QMI8658 Six-Axis Sensor, MPU6050, and SOS
//
// Hardware: Waveshare ESP32-S3-LCD-1.9 (170x320 ST7789, QMI8658 IMU)
// Features:
//   - 5 screens: Watch Face, Heart Rate, Activity/Steps, Patient, SOS
//   - QMI8658 six-axis IMU (built-in) for step counting & motion detection
//   - MPU6050 external IMU (breadboard) for pitch/roll orientation display
//   - CST816 touchscreen navigation + BOOT fallback
//   - WiFi HTTP POST to Supabase for SOS emergency alerts
// ============================================================================

#include <Arduino.h>
#include <Arduino_GFX_Library.h>
#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <math.h>
#include <time.h>

// ─── Pin mapping (Waveshare ESP32-S3-LCD-1.9) ─────────────────────────────
#define TFT_MOSI  13
#define TFT_SCLK  10
#define TFT_DC    11
#define TFT_CS    12
#define TFT_RST    9
#define TFT_BL    14

#define IMU_SDA   47
#define IMU_SCL   48
#define TP_INT    21

#define SCREEN_W  170
#define SCREEN_H  320

// ─── Display (HWSPI — matches Waveshare official demo) ────────────────────
Arduino_DataBus *bus = new Arduino_HWSPI(TFT_DC, TFT_CS, TFT_SCLK, TFT_MOSI);
Arduino_GFX *gfx = new Arduino_ST7789(bus, TFT_RST, 0, false, SCREEN_W, SCREEN_H, 35, 0, 35, 0);

// ─── Colors ────────────────────────────────────────────────────────────────
#define C_BG      0x0000
#define C_ACCENT  0x06BF   // Cyan
#define C_WHITE   0xFFFF
#define C_GRAY    0x4208
#define C_LGRAY   0x8410
#define C_DKGRAY  0x39E7
#define C_RED     0xF800
#define C_GREEN   0x07E0
#define C_ORANGE  0xFD20
#define C_BLUE    0x001F

// ═══════════════════════════════════════════════════════════════════════════
// WiFi & Supabase Configuration
// *** CHANGE THESE TO YOUR WiFi CREDENTIALS ***
// ═══════════════════════════════════════════════════════════════════════════
const char* WIFI_SSID = "WIFI_NI_KAGRASYA";
const char* WIFI_PASS = "Avyannamae13";

const char* SUPABASE_URL = "https://cnktjnchyyttjvslvdpr.supabase.co";
const char* SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzkyMzksImV4cCI6MjA5MTQ1NTIzOX0.HMF3yowDRciupe3BO-9gn-1vE5IWm7NYQWpQKDmqd4g";
const char* DEVICE_NAME = "ESP32 SmartWatch";
const char* FIRMWARE_VERSION = "v3.5-patient-sync";
String deviceId = "WATCH-SETUP";
String linkedPatientName = "No patient linked";
String linkedPatientCondition = "Waiting for pairing";
String linkedPatientRisk = "Medium";
String linkedPatientNotes = "";
int linkedPatientAge = 0;
bool patientLinked = false;

// ═══════════════════════════════════════════════════════════════════════════
// QMI8658 Six-Axis IMU (Accelerometer + Gyroscope)
// I2C Address 0x6B on Waveshare board, SDA=47, SCL=48
// ═══════════════════════════════════════════════════════════════════════════
#define QMI8658_ADDR    0x6B
#define QMI8658_WHO_AM_I 0x00   // Should return 0x05
#define QMI8658_CTRL2   0x03    // Accelerometer config
#define QMI8658_CTRL3   0x04    // Gyroscope config
#define QMI8658_CTRL7   0x08    // Sensor enable
#define QMI8658_RESET   0x60    // Soft reset register
#define QMI8658_AX_L    0x35    // Accel X low byte

// ═══════════════════════════════════════════════════════════════════════════
// MPU6050 External IMU (I2C 0x68 — AD0 tied to GND)
// Wired externally via breadboard on GPIO47(SDA)/GPIO48(SCL)
// No address conflict with QMI8658 (0x6B)
// ═══════════════════════════════════════════════════════════════════════════
// MPU6050_ADDR is detected at runtime (AD0=GND → 0x68, AD0=float → 0x69)
uint8_t MPU6050_ADDR     = 0x68;  // overwritten by mpu6050_init() if needed
#define MPU6050_WHO_AM_I   0x75   // Returns 0x68 on genuine chip
#define MPU6050_PWR_MGMT   0x6B   // Write 0x00 to wake from sleep
#define MPU6050_GYRO_CFG   0x1B   // 0x00 = ±250 dps
#define MPU6050_ACCEL_CFG  0x1C   // 0x00 = ±2 g (16384 LSB/g)
#define MPU6050_DATA_START 0x3B   // First of 14-byte accel+temp+gyro block

// ─── Watch State ───────────────────────────────────────────────────────────
int heartRate = 72;
int spo2 = 97;
float temperatureF = 98.4f;
int steps = 0;
int battery = 87;
int currentScreen = 0;      // 0=Watch, 1=Heart, 2=Steps, 3=Patient, 4=SOS
bool wifiConnected = false;
bool imuReady = false;
bool touchReady = false;
bool timeSynced = false;
bool sosSent = false;
String sosStatus = "Ready";
unsigned long sosTime = 0;
unsigned long lastTouchMs = 0;
unsigned long lastCloudSyncMs = 0;
unsigned long lastWiFiRetryMs = 0;
unsigned long lastVitalAlertMs = 0;
unsigned long lastSyncOkMs = 0;
unsigned long lastGestureMs = 0;
unsigned long lastPatientFetchMs = 0;
bool touchTracking = false;
bool swipeHandled = false;
bool lastSyncOk = false;
uint8_t touchGesture = 0;
uint16_t touchStartX = 0, touchStartY = 0;
uint16_t touchLastX = 0, touchLastY = 0;
int lastRenderedMinute = -1;
unsigned long lastUiRefreshMs = 0;
String popupMessage = "";
uint16_t popupColor = C_ACCENT;
bool popupVisible = false;
unsigned long popupUntilMs = 0;
int screenScrollOffset = 0;
int touchStartScrollOffset = 0;

// ─── Step Detection State ──────────────────────────────────────────────────
float accMagFiltered = 8192.0;
float gravityBaseline = 8192.0;
float motionDelta = 0.0;
bool stepArmed = false;
unsigned long lastStepTime = 0;

// ─── IMU Raw Data ──────────────────────────────────────────────────────────
int16_t accelX = 0, accelY = 0, accelZ = 0;
int16_t gyroX = 0, gyroY = 0, gyroZ = 0;
int16_t prevAccelX = 0, prevAccelY = 0, prevAccelZ = 0;

// ─── MPU6050 State ─────────────────────────────────────────────────────────
bool    mpu6050Ready = false;
int16_t mpuAccX = 0, mpuAccY = 0, mpuAccZ = 0;
int16_t mpuGyroX = 0, mpuGyroY = 0, mpuGyroZ = 0;
float   mpuPitch = 0.0f, mpuRoll = 0.0f;

// ═══════════════════════════════════════════════════════════════════════════
// QMI8658 IMU Functions
// ═══════════════════════════════════════════════════════════════════════════

void qmi8658_write(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

uint8_t qmi8658_read(uint8_t reg) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)1);
  return Wire.available() ? Wire.read() : 0;
}

bool qmi8658_init() {
  Wire.begin(IMU_SDA, IMU_SCL);
  delay(10);

  // Soft reset
  qmi8658_write(QMI8658_RESET, 0xB0);
  delay(20);

  // Verify chip ID
  uint8_t id = qmi8658_read(QMI8658_WHO_AM_I);
  Serial.printf("[IMU] WHO_AM_I: 0x%02X (expected 0x05)\n", id);

  if (id != 0x05) {
    Serial.println("[IMU] QMI8658 not found! Check I2C wiring.");
    return false;
  }

  // Configure accelerometer: ±4g, 125Hz ODR
  // Bits [6:4]=001 (±4g), Bits [3:0]=0110 (125Hz)
  qmi8658_write(QMI8658_CTRL2, 0x16);

  // Configure gyroscope: ±512dps, 125Hz ODR
  // Bits [6:4]=010 (±512dps), Bits [3:0]=0110 (125Hz)
  qmi8658_write(QMI8658_CTRL3, 0x26);

  // Enable accelerometer + gyroscope
  // Bit 0=aEN, Bit 1=gEN
  qmi8658_write(QMI8658_CTRL7, 0x03);

  delay(30);
  Serial.println("[IMU] QMI8658 initialized — Accel +/-4g 125Hz, Gyro +/-512dps 125Hz");
  return true;
}

void qmi8658_readAccel(int16_t &ax, int16_t &ay, int16_t &az) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(QMI8658_AX_L);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)6);

  if (Wire.available() >= 6) {
    ax = Wire.read() | ((int16_t)Wire.read() << 8);
    ay = Wire.read() | ((int16_t)Wire.read() << 8);
    az = Wire.read() | ((int16_t)Wire.read() << 8);
  }
}

void qmi8658_readGyro(int16_t &gx, int16_t &gy, int16_t &gz) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(0x3B);  // Gyro X low byte
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)6);

  if (Wire.available() >= 6) {
    gx = Wire.read() | ((int16_t)Wire.read() << 8);
    gy = Wire.read() | ((int16_t)Wire.read() << 8);
    gz = Wire.read() | ((int16_t)Wire.read() << 8);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MPU6050 External IMU Functions
// ═══════════════════════════════════════════════════════════════════════════

void mpu6050_write(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

uint8_t mpu6050_readReg(uint8_t reg) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)MPU6050_ADDR, (uint8_t)1);
  return Wire.available() ? Wire.read() : 0xFF;
}

bool mpu6050_init() {
  // Wire is already started by QMI8658 init.
  // Auto-detect: try 0x68 (AD0=GND) then 0x69 (AD0=floating/HIGH)
  bool found = false;
  for (uint8_t candidate : {(uint8_t)0x68, (uint8_t)0x69}) {
    Wire.beginTransmission(candidate);
    if (Wire.endTransmission() == 0) {
      MPU6050_ADDR = candidate;
      found = true;
      Serial.printf("[MPU6050] Found at I2C address 0x%02X%s\n", candidate,
        candidate == 0x69 ? " (AD0 not grounded — wire AD0 to GND for 0x68)" : "");
      break;
    }
  }
  if (!found) {
    Serial.println("[MPU6050] Not found on I2C bus at 0x68 or 0x69.");
    return false;
  }

  uint8_t id = mpu6050_readReg(MPU6050_WHO_AM_I);
  Serial.printf("[MPU6050] WHO_AM_I: 0x%02X (expected 0x68)\n", id);
  if (id != 0x68) {
    Serial.println("[MPU6050] Wrong chip ID — aborting.");
    return false;
  }

  mpu6050_write(MPU6050_PWR_MGMT,  0x00);  // Wake from sleep
  delay(10);
  mpu6050_write(MPU6050_GYRO_CFG,  0x00);  // ±250 dps
  mpu6050_write(MPU6050_ACCEL_CFG, 0x00);  // ±2 g (16384 LSB/g)
  delay(10);
  Serial.println("[MPU6050] Ready — Accel ±2g, Gyro ±250 dps");
  return true;
}

void mpu6050_readAll() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(MPU6050_DATA_START);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)MPU6050_ADDR, (uint8_t)14);

  if (Wire.available() >= 14) {
    mpuAccX  = (int16_t)((Wire.read() << 8) | Wire.read());
    mpuAccY  = (int16_t)((Wire.read() << 8) | Wire.read());
    mpuAccZ  = (int16_t)((Wire.read() << 8) | Wire.read());
    Wire.read(); Wire.read();  // Skip temperature bytes
    mpuGyroX = (int16_t)((Wire.read() << 8) | Wire.read());
    mpuGyroY = (int16_t)((Wire.read() << 8) | Wire.read());
    mpuGyroZ = (int16_t)((Wire.read() << 8) | Wire.read());

    // Compute pitch and roll in degrees from accelerometer (±2g, 16384 LSB/g)
    float ax = mpuAccX / 16384.0f;
    float ay = mpuAccY / 16384.0f;
    float az = mpuAccZ / 16384.0f;
    mpuPitch = atan2f(ay, sqrtf(ax * ax + az * az)) * 57.2958f;
    mpuRoll  = atan2f(-ax, az) * 57.2958f;
  }
}

void initUniqueDeviceId() {
  uint64_t chipId = ESP.getEfuseMac();
  char idBuf[24];
  snprintf(idBuf, sizeof(idBuf), "WATCH-%04X%08X", (uint16_t)(chipId >> 32), (uint32_t)chipId);
  deviceId = String(idBuf);
  Serial.printf("[DEVICE] Unique ID: %s\n", deviceId.c_str());
}

void pushPopup(const String &message, uint16_t color, unsigned long durationMs = 4500) {
  popupMessage = message;
  popupColor = color;
  popupVisible = true;
  popupUntilMs = millis() + durationMs;
}

// ═══════════════════════════════════════════════════════════════════════════
// CST816 Touch Controller (I2C 0x15)
// ═══════════════════════════════════════════════════════════════════════════
#define TOUCH_ADDR 0x15

bool touchInit() {
  pinMode(TP_INT, INPUT_PULLUP);

  Wire.beginTransmission(TOUCH_ADDR);
  if (Wire.endTransmission() != 0) {
    Serial.println("[TOUCH] CST816 not found.");
    return false;
  }

  Wire.beginTransmission(TOUCH_ADDR);
  Wire.write(0x00);
  Wire.write(0x00);  // normal mode
  Wire.endTransmission();

  Serial.println("[TOUCH] CST816 ready.");
  return true;
}

bool getTouchXY(uint16_t &tx, uint16_t &ty) {
  uint8_t buf[7] = {0};
  touchGesture = 0;

  Wire.beginTransmission(TOUCH_ADDR);
  Wire.write(0x00);
  if (Wire.endTransmission(false) != 0) return false;

  int got = Wire.requestFrom((uint8_t)TOUCH_ADDR, (uint8_t)7);
  if (got < 7) return false;

  for (int i = 0; i < 7; i++) {
    buf[i] = Wire.read();
  }

  if (buf[2] == 0) return false;

  uint16_t rawX = ((uint16_t)(buf[3] & 0x0F) << 8) | buf[4];
  uint16_t rawY = ((uint16_t)(buf[5] & 0x0F) << 8) | buf[6];

  if (rawX > SCREEN_W || rawY > SCREEN_H) {
    uint16_t tmp = rawX;
    rawX = rawY;
    rawY = tmp;
  }

  if (rawX >= SCREEN_W) rawX = SCREEN_W - 1;
  if (rawY >= SCREEN_H) rawY = SCREEN_H - 1;

  tx = rawX;
  ty = rawY;
  return true;
}

int getMaxScrollForScreen() {
  switch (currentScreen) {
    case 1: return 34;
    case 2: return 44;
    case 3: return 92;
    default: return 0;
  }
}

void showCurrentScreen() {
  switch (currentScreen) {
    case 0: drawWatchFace(); break;
    case 1: drawHeartScreen(); break;
    case 2: drawStepsScreen(); break;
    case 3: drawPatientScreen(); break;
    case 4: drawSOSScreen(); break;
  }
  lastUiRefreshMs = millis();
}

void handleTap(uint16_t x, uint16_t y) {
  Serial.printf("[TOUCH] tap x=%u y=%u\n", x, y);

  if (y >= 286) {
    int target = x / (SCREEN_W / 5);
    if (target < 0) target = 0;
    if (target > 4) target = 4;

    if (currentScreen != target) {
      currentScreen = target;
      screenScrollOffset = 0;
      showCurrentScreen();
    }
    return;
  }

  if (currentScreen == 4) {
    int dx = (int)x - (SCREEN_W / 2);
    int dy = (int)y - 165;
    if ((dx * dx + dy * dy) <= (45 * 45)) {
      Serial.println("[SOS] Touch pressed — sending SOS alert...");
      sosStatus = "Sending...";
      drawSOSScreen();
      sosSent = sendSOSAlert();
      sosTime = millis();
      drawSOSScreen();
    }
  }
}

void processTouchPoint(uint16_t x, uint16_t y) {
  if (!touchTracking) {
    touchTracking = true;
    swipeHandled = false;
    touchStartX = x;
    touchStartY = y;
    touchStartScrollOffset = screenScrollOffset;
  }

  touchLastX = x;
  touchLastY = y;

  int dx = (int)x - (int)touchStartX;
  int dy = (int)y - (int)touchStartY;

  if (!swipeHandled && y < 280 && abs(dx) > 75 && abs(dy) < 28 && millis() - lastGestureMs > 320) {
    swipeHandled = true;
    lastGestureMs = millis();
    screenScrollOffset = 0;
    currentScreen = dx < 0 ? (currentScreen + 1) % 5 : (currentScreen + 4) % 5;
    Serial.printf("[TOUCH] swipe -> screen %d\n", currentScreen);
    showCurrentScreen();
    return;
  }

  if ((currentScreen == 1 || currentScreen == 2 || currentScreen == 3) && y < 280 && abs(dx) < 42 && abs(dy) > 16) {
    int maxScroll = getMaxScrollForScreen();
    if (maxScroll > 0) {
      swipeHandled = true;
      int newOffset = touchStartScrollOffset + ((int)touchStartY - (int)y);
      if (newOffset < 0) newOffset = 0;
      if (newOffset > maxScroll) newOffset = maxScroll;
      if (newOffset != screenScrollOffset) {
        screenScrollOffset = newOffset;
        if (millis() - lastUiRefreshMs > 40) showCurrentScreen();
      }
    }
  }
}

void finalizeTouch() {
  if (!touchTracking) return;

  if (!swipeHandled) {
    handleTap(touchLastX, touchLastY);
  }

  touchTracking = false;
  swipeHandled = false;
}

void calibrateMotionBaseline() {
  if (!imuReady) return;

  long total = 0;
  for (int i = 0; i < 40; i++) {
    int16_t ax, ay, az;
    qmi8658_readAccel(ax, ay, az);
    float mag = sqrt((float)ax * ax + (float)ay * ay + (float)az * az);
    total += (long)mag;
    delay(20);
  }

  gravityBaseline = total / 40.0f;
  accMagFiltered = gravityBaseline;
  Serial.printf("[IMU] Baseline calibrated: %.1f\n", gravityBaseline);
}

void updateLiveMetrics() {
  // Use the watch as the live source of truth for vitals so the admin panel can
  // mirror exactly what the device is showing.
  heartRate = 72 + (int)(4.0f * sin(millis() / 2600.0f));
  if (heartRate < 60) heartRate = 60;
  if (heartRate > 110) heartRate = 110;

  spo2 = 97 + (int)(1.0f * sin(millis() / 3200.0f));
  if (spo2 < 95) spo2 = 95;
  if (spo2 > 100) spo2 = 100;

  temperatureF = 98.4f + 0.25f * sin(millis() / 9000.0f);

  int liveBattery = 87 - (int)(millis() / 300000UL);
  battery = liveBattery < 15 ? 15 : liveBattery;
}

String currentTimestampText() {
  struct tm timeinfo;
  if (timeSynced && getLocalTime(&timeinfo, 50)) {
    char buf[32];
    strftime(buf, sizeof(buf), "%b %d %I:%M %p", &timeinfo);
    return String(buf);
  }
  return "Uptime: " + String(millis() / 1000) + "s";
}

String sanitizeJsonText(String value) {
  value.replace("\"", "'");
  value.replace("\n", " ");
  return value;
}

String extractJsonString(const String &json, const String &key, const String &fallback = "") {
  String token = "\"" + key + "\":";
  int keyPos = json.indexOf(token);
  if (keyPos < 0) return fallback;

  int start = keyPos + token.length();
  while (start < json.length() && json[start] == ' ') start++;

  if (start < json.length() && json[start] == '"') {
    start++;
    int end = json.indexOf('"', start);
    if (end > start) return json.substring(start, end);
  }

  int end = json.indexOf(',', start);
  int brace = json.indexOf('}', start);
  if (end < 0 || (brace >= 0 && brace < end)) end = brace;
  if (end > start) return json.substring(start, end);
  return fallback;
}

int extractJsonInt(const String &json, const String &key, int fallback = 0) {
  String value = extractJsonString(json, key, String(fallback));
  value.trim();
  return value.toInt();
}

float extractJsonFloat(const String &json, const String &key, float fallback = 0.0f) {
  String value = extractJsonString(json, key, String(fallback, 1));
  value.trim();
  return value.toFloat();
}

void syncClock() {
  if (!wifiConnected) return;
  configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    timeSynced = true;
    Serial.println("[TIME] Clock synced from NTP.");
  } else {
    timeSynced = false;
    Serial.println("[TIME] NTP sync failed, using uptime fallback.");
  }
}

bool postAlertToCloud(const String &title, const String &severity, const String &value) {
  if (WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    connectWiFi();
  }

  if (!wifiConnected) {
    Serial.println("[ALERT] No WiFi connection!");
    return false;
  }

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/alerts";
  http.begin(url);
  http.setTimeout(8000);
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");

  String patientName = patientLinked ? linkedPatientName : "Unassigned Patient";
  String body = "{";
  body += "\"id\":\"ALR-" + String(millis()) + "\",";
  body += "\"title\":\"" + sanitizeJsonText(title) + "\",";
  body += "\"patient\":\"" + sanitizeJsonText(patientName) + "\",";
  body += "\"severity\":\"" + severity + "\",";
  body += "\"status\":\"new\",";
  body += "\"timestamp\":\"" + currentTimestampText() + "\",";
  body += "\"value\":\"" + sanitizeJsonText(value) + "\"";
  body += "}";

  int httpCode = http.POST(body);
  String response = http.getString();
  http.end();
  Serial.printf("[ALERT] HTTP %d: %s\n", httpCode, response.c_str());
  return httpCode >= 200 && httpCode < 300;
}

void fetchAssignedPatient() {
  if (!wifiConnected) return;

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/patients?device_id=eq." + deviceId + "&select=name,age,condition,risk_level,notes,device_status,heart_rate,spo2,temperature,steps&limit=1";
  http.begin(url);
  http.setTimeout(700);
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  int code = http.GET();
  String body = http.getString();
  http.end();

  if (code >= 200 && code < 300 && body.indexOf("[{") >= 0) {
    bool wasLinked = patientLinked;
    String previousName = linkedPatientName;

    linkedPatientName = extractJsonString(body, "name", "No patient linked");
    linkedPatientCondition = extractJsonString(body, "condition", "Waiting for pairing");
    linkedPatientRisk = extractJsonString(body, "risk_level", "Medium");
    linkedPatientNotes = extractJsonString(body, "notes", "");
    linkedPatientAge = extractJsonInt(body, "age", 0);
    patientLinked = linkedPatientName.length() > 0 && linkedPatientName != "No patient linked";

    if (patientLinked) {
      heartRate = extractJsonInt(body, "heart_rate", heartRate);
      spo2 = extractJsonInt(body, "spo2", spo2);
      temperatureF = extractJsonFloat(body, "temperature", temperatureF);
      steps = extractJsonInt(body, "steps", steps);
    }

    if (patientLinked && (!wasLinked || previousName != linkedPatientName)) {
      pushPopup("Patient linked", C_GREEN, 5000);
      postAlertToCloud("Patient linked to device", "warning", linkedPatientName + " linked on " + deviceId);
    }
  } else {
    patientLinked = false;
    linkedPatientName = "No patient linked";
    linkedPatientCondition = "Waiting for pairing";
    linkedPatientRisk = "Medium";
    linkedPatientNotes = "";
    linkedPatientAge = 0;
  }
}

void maybeSendVitalAlerts() {
  if (!patientLinked || !wifiConnected) return;
  if (millis() - lastVitalAlertMs < 30000) return;

  String title = "";
  String severity = "warning";
  String value = "";

  if (heartRate >= 120 || heartRate <= 50) {
    title = "Critical heart rate detected";
    severity = "critical";
    value = "Heart rate is " + String(heartRate) + " bpm on " + deviceId;
  } else if (spo2 < 94) {
    title = (spo2 < 90) ? "Critical SpO2 detected" : "Low SpO2 warning";
    severity = (spo2 < 90) ? "critical" : "warning";
    value = "SpO2 is " + String(spo2) + "% on " + deviceId;
  } else if (temperatureF >= 100.4f || temperatureF <= 95.5f) {
    title = "Temperature warning";
    severity = temperatureF >= 101.0f ? "critical" : "warning";
    value = "Temperature is " + String(temperatureF, 1) + "F on " + deviceId;
  }

  if (title.length() > 0 && postAlertToCloud(title, severity, value)) {
    lastVitalAlertMs = millis();
    pushPopup(title, severity == "critical" ? C_RED : C_ORANGE, 4000);
  }
}

void syncWatchToCloud() {
  if (!wifiConnected) return;

  // Patient metadata changes rarely, so fetch it less often to keep the UI responsive.
  if (millis() - lastPatientFetchMs > 8000 || !patientLinked) {
    lastPatientFetchMs = millis();
    fetchAssignedPatient();
  }

  String syncText = currentTimestampText();

  HTTPClient http;
  String deviceUrl = String(SUPABASE_URL) + "/rest/v1/devices?on_conflict=id";
  http.begin(deviceUrl);
  http.setTimeout(700);
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "resolution=merge-duplicates,return=minimal");

  String deviceBody = "{";
  deviceBody += "\"id\":\"" + deviceId + "\",";
  deviceBody += "\"name\":\"" + String(DEVICE_NAME) + "\",";
  deviceBody += "\"patient_name\":\"" + sanitizeJsonText(patientLinked ? linkedPatientName : "") + "\",";
  deviceBody += "\"status\":\"Online\",";
  deviceBody += "\"battery\":" + String(battery) + ",";
  deviceBody += "\"last_sync\":\"" + syncText + "\",";
  deviceBody += "\"firmware\":\"" + String(FIRMWARE_VERSION) + "\"";
  deviceBody += "}";
  int deviceCode = http.POST(deviceBody);
  http.end();

  int patientCode = -1;
  if (patientLinked) {
    HTTPClient patientHttp;
    String patientUrl = String(SUPABASE_URL) + "/rest/v1/patients?device_id=eq." + deviceId;
    patientHttp.begin(patientUrl);
    patientHttp.setTimeout(700);
    patientHttp.addHeader("apikey", SUPABASE_KEY);
    patientHttp.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
    patientHttp.addHeader("Content-Type", "application/json");
    patientHttp.addHeader("Prefer", "return=minimal");

    String patientBody = "{";
    patientBody += "\"device_status\":\"Online\",";
    patientBody += "\"last_sync\":\"" + syncText + "\",";
    patientBody += "\"steps\":" + String(steps);
    patientBody += "}";
    patientCode = patientHttp.sendRequest("PATCH", patientBody);
    patientHttp.end();
  }

  lastSyncOk = (deviceCode >= 200 && deviceCode < 300) && (!patientLinked || (patientCode >= 200 && patientCode < 300));
  if (lastSyncOk) {
    lastSyncOkMs = millis();
  }

  maybeSendVitalAlerts();
  Serial.printf("[SYNC] device=%s devices=%d patients=%d hr=%d spo2=%d temp=%.1f steps=%d ok=%d\n", deviceId.c_str(), deviceCode, patientCode, heartRate, spo2, temperatureF, steps, lastSyncOk);
}

// ═══════════════════════════════════════════════════════════════════════════
// Step Detection using Accelerometer
// At ±4g: 8192 LSB/g, so 1g gravity = ~8192 raw magnitude
// Walking step peak = ~1.1-1.3g = 9000-10600 raw
// ═══════════════════════════════════════════════════════════════════════════

void detectSteps() {
  if (!imuReady) return;

  int16_t ax, ay, az;
  qmi8658_readAccel(ax, ay, az);
  accelX = ax;
  accelY = ay;
  accelZ = az;

  float mag = sqrt((float)ax * ax + (float)ay * ay + (float)az * az);
  accMagFiltered = accMagFiltered * 0.85f + mag * 0.15f;
  gravityBaseline = gravityBaseline * 0.998f + accMagFiltered * 0.002f;
  motionDelta = fabs(accMagFiltered - gravityBaseline);

  int jerk = abs(ax - prevAccelX) + abs(ay - prevAccelY) + abs(az - prevAccelZ);
  int gyroMotion = abs(gyroX) + abs(gyroY) + abs(gyroZ);
  prevAccelX = ax;
  prevAccelY = ay;
  prevAccelZ = az;

  if (!stepArmed && motionDelta > 1400.0f && jerk > 2600 && gyroMotion > 1200 && millis() - lastStepTime > 650) {
    stepArmed = true;
    steps++;
    lastStepTime = millis();
  }

  if (motionDelta < 120.0f && gyroMotion < 400) {
    stepArmed = false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WiFi Connection
// ═══════════════════════════════════════════════════════════════════════════

void connectWiFi() {
  Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(10, 170);
  gfx->print("Connecting WiFi...");

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    if (!timeSynced) syncClock();
  } else {
    wifiConnected = false;
    Serial.println("\n[WiFi] Connection failed — SOS will be unavailable.");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Send SOS Alert to Supabase (HTTP POST to alerts table)
// ═══════════════════════════════════════════════════════════════════════════
//
// NOTE: Your Supabase 'alerts' table needs RLS policy allowing anon inserts:
//   CREATE POLICY "allow_sos_insert" ON public.alerts
//     FOR INSERT TO anon WITH CHECK (true);
// Or temporarily disable RLS on the alerts table for demo.
// ═══════════════════════════════════════════════════════════════════════════

bool sendSOSAlert() {
  if (!wifiConnected && WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (!wifiConnected) {
    sosStatus = "WiFi required";
    Serial.println("[SOS] No WiFi connection!");
    return false;
  }

  bool ok = postAlertToCloud("SOS Emergency Alert", "critical", "Emergency SOS triggered from " + deviceId);
  sosStatus = ok ? "SOS SENT!" : "Send failed";
  return ok;
}

// ═══════════════════════════════════════════════════════════════════════════
// Drawing Helpers
// ═══════════════════════════════════════════════════════════════════════════

void drawCentered(const char* text, int y, uint16_t color, uint8_t sz) {
  gfx->setTextSize(sz);
  gfx->setTextColor(color);
  int16_t x1, y1;
  uint16_t w, h;
  gfx->getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  gfx->setCursor((SCREEN_W - w) / 2, y);
  gfx->print(text);
}

void drawHeartGlyph(int cx, int cy, uint16_t color) {
  gfx->fillCircle(cx - 5, cy - 4, 5, color);
  gfx->fillCircle(cx + 5, cy - 4, 5, color);
  gfx->fillTriangle(cx - 10, cy - 1, cx + 10, cy - 1, cx, cy + 11, color);
}

void drawWalkGlyph(int cx, int cy, uint16_t color) {
  gfx->fillCircle(cx, cy - 9, 3, color);
  gfx->drawLine(cx, cy - 5, cx, cy + 5, color);
  gfx->drawLine(cx, cy - 1, cx - 6, cy + 3, color);
  gfx->drawLine(cx, cy - 1, cx + 6, cy + 1, color);
  gfx->drawLine(cx, cy + 5, cx - 5, cy + 12, color);
  gfx->drawLine(cx, cy + 5, cx + 5, cy + 12, color);
}

void drawBatteryGlyph(int x, int y, uint16_t color, int level) {
  int fill = level;
  if (fill < 0) fill = 0;
  if (fill > 100) fill = 100;

  gfx->drawRoundRect(x, y, 22, 12, 3, color);
  gfx->fillRect(x + 22, y + 3, 2, 6, color);
  gfx->fillRoundRect(x + 2, y + 2, (18 * fill) / 100, 8, 2, level > 25 ? C_GREEN : C_ORANGE);
}

void drawDropGlyph(int cx, int cy, uint16_t color) {
  gfx->fillTriangle(cx, cy - 9, cx - 7, cy + 5, cx + 7, cy + 5, color);
  gfx->fillCircle(cx, cy + 1, 5, color);
}

void drawTempGlyph(int x, int y, uint16_t color) {
  gfx->drawRoundRect(x, y, 8, 18, 3, color);
  gfx->fillCircle(x + 4, y + 18, 5, color);
  gfx->fillRect(x + 3, y + 5, 2, 11, color);
}

void drawPopupIfVisible() {
  if (!popupVisible) return;
  if (millis() > popupUntilMs) {
    popupVisible = false;
    return;
  }

  gfx->fillRoundRect(8, 8, SCREEN_W - 16, 28, 8, C_DKGRAY);
  gfx->drawRoundRect(8, 8, SCREEN_W - 16, 28, 8, popupColor);
  gfx->setTextSize(1);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(14, 18);
  String message = popupMessage.length() > 24 ? popupMessage.substring(0, 24) : popupMessage;
  gfx->print(message);
}

void drawSyncBadge(int x = 10, int y = 14) {
  bool live = lastSyncOk && (millis() - lastSyncOkMs < 5000);
  uint16_t color = live ? C_GREEN : (wifiConnected ? C_ORANGE : C_GRAY);
  const char* label = live ? "LIVE" : (wifiConnected ? "SYNC" : "OFF");
  gfx->fillRoundRect(x, y, 44, 16, 6, C_DKGRAY);
  gfx->drawRoundRect(x, y, 44, 16, 6, color);
  gfx->fillCircle(x + 8, y + 8, 3, color);
  gfx->setTextSize(1);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(x + 15, y + 4);
  gfx->print(label);
}

void drawNavBar() {
  const int y = 289;
  const int h = 24;
  const int gap = 3;
  const int w = 30;
  const char* labels[5] = {"W", "H", "A", "P", "SOS"};
  const uint16_t colors[5] = {C_ACCENT, C_RED, C_GREEN, C_BLUE, C_RED};

  for (int i = 0; i < 5; i++) {
    int x = 4 + i * (w + gap);
    uint16_t fill = (i == currentScreen) ? colors[i] : C_DKGRAY;
    uint16_t textColor = (i == currentScreen) ? C_BG : C_WHITE;
    gfx->fillRoundRect(x, y, w, h, 6, fill);
    gfx->drawRoundRect(x, y, w, h, 6, colors[i]);
    gfx->setTextSize(1);
    gfx->setTextColor(textColor);
    gfx->setCursor(x + (i == 4 ? 4 : 11), y + 8);
    gfx->print(labels[i]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 0: Watch Face
// ═══════════════════════════════════════════════════════════════════════════

void drawWatchFace() {
  gfx->fillScreen(C_BG);
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_GRAY);

  char timeBuf[8] = "12:30";
  char dateBuf[24] = "Mon, Apr 14";
  char ampmBuf[4] = "PM";
  struct tm timeinfo;

  if (timeSynced && getLocalTime(&timeinfo, 20)) {
    strftime(timeBuf, sizeof(timeBuf), "%I:%M", &timeinfo);
    strftime(dateBuf, sizeof(dateBuf), "%a, %b %d", &timeinfo);
    strftime(ampmBuf, sizeof(ampmBuf), "%p", &timeinfo);
  }

  drawSyncBadge(8, 12);
  drawBatteryGlyph(136, 14, C_ACCENT, battery);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(104, 16);
  gfx->print(battery);
  gfx->print("%");

  drawCentered(timeBuf, 28, C_WHITE, 4);
  gfx->setTextSize(1);
  gfx->setTextColor(C_ACCENT);
  gfx->setCursor(144, 32);
  gfx->print(ampmBuf);
  drawCentered(dateBuf, 68, C_LGRAY, 1);

  String patientLabel = patientLinked ? linkedPatientName : "No patient linked";
  drawCentered(patientLabel.c_str(), 84, patientLinked ? C_ACCENT : C_GRAY, 1);

  int cx = (SCREEN_W - 150) / 2;

  gfx->fillRoundRect(cx, 100, 150, 38, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 100, 150, 38, 8, C_RED);
  drawHeartGlyph(cx + 15, 119, C_RED);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 30, 106);
  gfx->print("Heart");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 30, 118);
  gfx->print(heartRate);
  gfx->setTextSize(1);
  gfx->setCursor(cx + 78, 122);
  gfx->print("bpm");

  gfx->fillRoundRect(cx, 145, 150, 38, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 145, 150, 38, 8, C_BLUE);
  drawDropGlyph(cx + 16, 163, C_BLUE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 30, 151);
  gfx->print("SpO2");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 30, 163);
  gfx->print(spo2);
  gfx->setTextSize(1);
  gfx->setCursor(cx + 72, 167);
  gfx->print("%");

  gfx->fillRoundRect(cx, 190, 150, 48, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 190, 150, 48, 8, C_ORANGE);
  drawTempGlyph(cx + 12, 202, C_ORANGE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 30, 197);
  gfx->print("Temp");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 30, 211);
  gfx->print(String(temperatureF, 1));
  gfx->setTextSize(1);
  gfx->setCursor(cx + 96, 216);
  gfx->print("F");

  drawCentered(timeSynced ? "Realtime sync active" : "Clock fallback active", 250, C_ACCENT, 1);
  String condition = patientLinked ? linkedPatientCondition : "Waiting for pairing";
  if (condition.length() > 22) condition = condition.substring(0, 22);
  drawCentered(condition.c_str(), 264, C_LGRAY, 1);

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Watch face done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 1: Heart Rate + vital details
// ═══════════════════════════════════════════════════════════════════════════

void drawHeartScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_GRAY);
  drawSyncBadge(8, 12);

  int yOff = -screenScrollOffset;
  drawCentered("Heart & Vitals", 18 + yOff, C_RED, 2);

  int cx = SCREEN_W / 2;
  gfx->fillCircle(cx, 80 + yOff, 24, C_DKGRAY);
  gfx->drawCircle(cx, 80 + yOff, 27, C_RED);
  drawHeartGlyph(cx, 82 + yOff, C_RED);

  char buf[8];
  snprintf(buf, sizeof(buf), "%d", heartRate);
  drawCentered(buf, 114 + yOff, C_WHITE, 5);
  drawCentered("BPM", 164 + yOff, C_LGRAY, 2);

  gfx->fillRoundRect(18, 196 + yOff, 60, 34, 8, C_DKGRAY);
  gfx->drawRoundRect(18, 196 + yOff, 60, 34, 8, C_BLUE);
  drawDropGlyph(30, 212 + yOff, C_BLUE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(42, 207 + yOff);
  gfx->print(spo2);
  gfx->print("%");

  gfx->fillRoundRect(92, 196 + yOff, 60, 34, 8, C_DKGRAY);
  gfx->drawRoundRect(92, 196 + yOff, 60, 34, 8, C_ORANGE);
  drawTempGlyph(104, 202 + yOff, C_ORANGE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(116, 207 + yOff);
  gfx->print(String(temperatureF, 1));
  gfx->print("F");

  drawCentered(heartRate > 100 ? "Elevated" : "Normal zone", 244 + yOff, heartRate > 100 ? C_ORANGE : C_GREEN, 2);
  drawCentered(screenScrollOffset > 0 ? "Swipe down to top" : "Swipe up/down", 270, C_LGRAY, 1);
  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Heart screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 2: Activity / Steps
// ═══════════════════════════════════════════════════════════════════════════

void drawStepsScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_GRAY);
  drawSyncBadge(8, 12);

  int yOff = -screenScrollOffset;
  drawCentered("Activity", 18 + yOff, C_GREEN, 2);

  int cx = SCREEN_W / 2;
  gfx->fillCircle(cx, 78 + yOff, 24, C_DKGRAY);
  gfx->drawCircle(cx, 78 + yOff, 26, C_GREEN);
  drawWalkGlyph(cx, 82 + yOff, C_GREEN);

  char stepBuf[16];
  snprintf(stepBuf, sizeof(stepBuf), "%d", steps);
  drawCentered(stepBuf, 114 + yOff, C_WHITE, 4);
  drawCentered("steps today", 150 + yOff, C_LGRAY, 1);

  int pct = (steps * 100) / 10000;
  if (pct > 100) pct = 100;
  int bx = 15, by = 178 + yOff, bw = SCREEN_W - 30;
  gfx->fillRoundRect(bx, by, bw, 12, 6, C_DKGRAY);
  gfx->fillRoundRect(bx, by, bw * pct / 100, 12, 6, C_GREEN);

  char pctBuf[8];
  snprintf(pctBuf, sizeof(pctBuf), "%d%%", pct);
  drawCentered(pctBuf, 202 + yOff, C_GREEN, 2);
  drawCentered("Goal 10,000", 226 + yOff, C_LGRAY, 1);

  // IMU status row
  {
    String imuStr;
    uint16_t imuCol;
    if      (imuReady && mpu6050Ready) { imuStr = "QMI+MPU6050 active"; imuCol = C_ACCENT; }
    else if (imuReady)                 { imuStr = "QMI tracking live";  imuCol = C_ACCENT; }
    else if (mpu6050Ready)             { imuStr = "MPU6050 active";     imuCol = C_ACCENT; }
    else                               { imuStr = "IMU offline";         imuCol = C_RED;    }
    drawCentered(imuStr.c_str(), 246 + yOff, imuCol, 1);
  }

  // MPU6050 pitch / roll
  if (mpu6050Ready) {
    char prBuf[24];
    snprintf(prBuf, sizeof(prBuf), "P:%.1f  R:%.1f", mpuPitch, mpuRoll);
    drawCentered("MPU6050 Tilt", 260 + yOff, C_BLUE, 1);
    drawCentered(prBuf, 272 + yOff, C_WHITE, 1);
  }

  drawCentered(screenScrollOffset > 0 ? "Swipe down to top" : "Swipe up/down", 283, C_LGRAY, 1);

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Steps screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 3: Patient Details
// ═══════════════════════════════════════════════════════════════════════════

void drawPatientScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_GRAY);
  drawSyncBadge(8, 12);

  int yOff = -screenScrollOffset;
  drawCentered("Patient Details", 16 + yOff, C_BLUE, 2);

  if (!patientLinked) {
    drawCentered("No patient assigned", 82 + yOff, C_WHITE, 2);
    drawCentered("Link this watch in admin", 118 + yOff, C_LGRAY, 1);
    drawCentered(deviceId.c_str(), 150 + yOff, C_ACCENT, 1);
    drawCentered("Patients tab -> Device ID", 176 + yOff, C_LGRAY, 1);
  } else {
    String ageText = "Age " + String(linkedPatientAge);
    String riskText = "Risk: " + linkedPatientRisk;
    String condText = linkedPatientCondition.length() > 20 ? linkedPatientCondition.substring(0, 20) : linkedPatientCondition;
    String noteText = linkedPatientNotes.length() > 22 ? linkedPatientNotes.substring(0, 22) : linkedPatientNotes;
    String vitalsText = "HR " + String(heartRate) + "  SpO2 " + String(spo2) + "%";
    String tempText = "Temp " + String(temperatureF, 1) + "F  Steps " + String(steps);

    drawCentered(linkedPatientName.c_str(), 56 + yOff, C_WHITE, 2);
    drawCentered(ageText.c_str(), 82 + yOff, C_ACCENT, 1);
    drawCentered(riskText.c_str(), 104 + yOff, linkedPatientRisk == "Critical" ? C_RED : C_GREEN, 1);
    drawCentered(condText.c_str(), 128 + yOff, C_LGRAY, 1);
    drawCentered(vitalsText.c_str(), 164 + yOff, C_WHITE, 1);
    drawCentered(tempText.c_str(), 184 + yOff, C_WHITE, 1);
    drawCentered(noteText.length() > 0 ? noteText.c_str() : "No notes", 214 + yOff, C_LGRAY, 1);
    drawCentered(deviceId.c_str(), 242 + yOff, C_BLUE, 1);
    drawCentered("Swipe up/down for more", 270, C_LGRAY, 1);
  }

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Patient screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 4: SOS Emergency
// ═══════════════════════════════════════════════════════════════════════════

void drawSOSScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_RED);
  gfx->drawRect(1, 1, SCREEN_W - 2, SCREEN_H - 2, C_RED);

  drawCentered("EMERGENCY", 20, C_RED, 2);
  drawSyncBadge(8, 12);
  drawCentered("SOS", 60, C_WHITE, 5);

  int cx = SCREEN_W / 2;
  int cy = 165;
  gfx->fillCircle(cx, cy, 45, C_RED);
  gfx->drawCircle(cx, cy, 48, C_WHITE);
  gfx->drawCircle(cx, cy, 49, C_WHITE);

  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx - 18, cy - 7);
  gfx->print("SOS");

  drawCentered("Tap circle to send", 226, C_LGRAY, 1);
  drawCentered(deviceId.c_str(), 242, C_ACCENT, 1);

  if (sosSent) {
    drawCentered(sosStatus.c_str(), 268, C_GREEN, 2);
  } else if (!wifiConnected) {
    drawCentered(sosStatus.c_str(), 268, C_ORANGE, 1);
  } else {
    drawCentered(sosStatus.c_str(), 268, C_ACCENT, 1);
  }

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] SOS screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== SMART WATCH v3.5 — Patient Sync + Alerts ===");
  initUniqueDeviceId();

  // Init display (before backlight, like Waveshare demo)
  if (!gfx->begin()) {
    Serial.println("gfx->begin() FAILED!");
  }
  gfx->fillScreen(C_BG);
  gfx->invertDisplay(true);

  // Backlight
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, LOW);  // Waveshare default

  // Show loading screen
  drawCentered("Smart Watch v3", 100, C_WHITE, 2);
  drawCentered("Initializing...", 140, C_ACCENT, 1);

  // Init QMI8658 six-axis sensor
  drawCentered("Starting IMU...", 170, C_LGRAY, 1);
  imuReady = qmi8658_init();
  if (imuReady) {
    calibrateMotionBaseline();
    drawCentered("IMU OK", 185, C_GREEN, 1);
  } else {
    drawCentered("IMU Failed", 185, C_RED, 1);
  }

  // Init MPU6050 external IMU
  drawCentered("Starting MPU6050...", 200, C_LGRAY, 1);
  mpu6050Ready = mpu6050_init();
  drawCentered(mpu6050Ready ? "MPU6050 OK" : "MPU6050 N/A", 215, mpu6050Ready ? C_GREEN : C_GRAY, 1);

  // Init touch controller
  drawCentered("Starting Touch...", 230, C_LGRAY, 1);
  touchReady = touchInit();
  drawCentered(touchReady ? "Touch+Swipe OK" : "Touch Failed", 245, touchReady ? C_GREEN : C_ORANGE, 1);

  // Connect WiFi
  drawCentered("Connecting WiFi...", 230, C_LGRAY, 1);
  connectWiFi();
  if (wifiConnected) {
    drawCentered("WiFi OK", 245, C_GREEN, 1);
  } else {
    drawCentered("WiFi Failed", 245, C_ORANGE, 1);
  }

  delay(1000);

  // Push initial device heartbeat and draw the UI
  if (wifiConnected) {
    syncWatchToCloud();
    lastCloudSyncMs = millis();
  }

  showCurrentScreen();
  Serial.println("Setup complete.");
}

// ═══════════════════════════════════════════════════════════════════════════
// LOOP
// ═══════════════════════════════════════════════════════════════════════════

static unsigned long lastSecond = 0;
static int displaySeconds = 0;
static unsigned long lastStepCheck = 0;
static unsigned long lastGyroRead = 0;

void loop() {
  // ── Button handling (5 screens) ──────────────────────────────────────────
  static bool lastBtn = HIGH;
  static unsigned long lastBtnMs = 0;
  bool b = digitalRead(0);  // BOOT button

  if (b == LOW && lastBtn == HIGH && millis() - lastBtnMs > 300) {
    lastBtnMs = millis();

    if (currentScreen == 4) {
      // On SOS screen: button triggers SOS alert
      Serial.println("[SOS] Button pressed — sending SOS alert...");
      drawCentered("Sending...", 275, C_ORANGE, 1);
      sosSent = sendSOSAlert();
      sosTime = millis();
      drawSOSScreen();  // Refresh to show result
    } else {
      // Navigate to next screen
      currentScreen = (currentScreen + 1) % 5;
      Serial.printf("[BTN] Screen -> %d\n", currentScreen);
      showCurrentScreen();
    }
  }
  lastBtn = b;

  // ── Touch handling with tap + swipe ──────────────────────────────────────
  if (touchReady && millis() - lastTouchMs > 25) {
    lastTouchMs = millis();
    uint16_t tx, ty;
    if (digitalRead(TP_INT) == LOW) {
      if (getTouchXY(tx, ty)) {
        processTouchPoint(tx, ty);
      }
    } else if (touchTracking) {
      finalizeTouch();
    }
  }

  // ── Step detection every 20ms ────────────────────────────────────────────
  if (millis() - lastStepCheck >= 20) {
    lastStepCheck = millis();
    detectSteps();
  }

  // ── Read gyroscope every 100ms (for display on steps screen) ─────────────
  if (millis() - lastGyroRead >= 100) {
    lastGyroRead = millis();
    if (imuReady)     qmi8658_readGyro(gyroX, gyroY, gyroZ);
    if (mpu6050Ready) mpu6050_readAll();
  }

  // ── Update display every second ──────────────────────────────────────────
  if (millis() - lastSecond >= 1000) {
    lastSecond = millis();
    displaySeconds++;
    updateLiveMetrics();

    if (WiFi.status() != WL_CONNECTED && millis() - lastWiFiRetryMs > 20000) {
      lastWiFiRetryMs = millis();
      connectWiFi();
    } else {
      wifiConnected = (WiFi.status() == WL_CONNECTED);
    }

    struct tm nowInfo;
    bool haveTime = timeSynced && getLocalTime(&nowInfo, 20);
    int minuteNow = haveTime ? nowInfo.tm_min : displaySeconds / 60;

    if (currentScreen == 0 && (minuteNow != lastRenderedMinute || millis() - lastUiRefreshMs > 2000 || popupVisible)) {
      lastRenderedMinute = minuteNow;
      drawWatchFace();
      lastUiRefreshMs = millis();
    } else if (currentScreen == 1 && (millis() - lastUiRefreshMs > 1500 || popupVisible)) {
      drawHeartScreen();
      lastUiRefreshMs = millis();
    } else if (currentScreen == 2 && (millis() - lastUiRefreshMs > 1500 || popupVisible)) {
      drawStepsScreen();
      lastUiRefreshMs = millis();
    } else if (currentScreen == 3 && (millis() - lastUiRefreshMs > 2000 || popupVisible)) {
      drawPatientScreen();
      lastUiRefreshMs = millis();
    } else if (currentScreen == 4 && (sosSent || millis() - lastUiRefreshMs > 2000 || popupVisible)) {
      drawSOSScreen();
      lastUiRefreshMs = millis();
    }

    if (wifiConnected && millis() - lastCloudSyncMs > 3000) {
      lastCloudSyncMs = millis();
      syncWatchToCloud();
    }

    if (sosSent && millis() - sosTime > 10000) {
      sosSent = false;
      sosStatus = wifiConnected ? "Ready" : "WiFi required";
      if (currentScreen == 4) drawSOSScreen();
    }

    if (popupVisible && millis() > popupUntilMs) {
      popupVisible = false;
      showCurrentScreen();
    }

    Serial.printf("[ALIVE] %ds steps=%d screen=%d imu=%d wifi=%d\n",
                  displaySeconds, steps, currentScreen, imuReady, wifiConnected);
  }

  delay(10);
}
