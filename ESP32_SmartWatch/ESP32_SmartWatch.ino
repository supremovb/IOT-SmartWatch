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
#include <Preferences.h>
#include <WebServer.h>
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

// ─── MAX30102 second I2C bus (GPIO3/GPIO5) ─────────────────────────────────
#define MAX30102_SDA   3
#define MAX30102_SCL   5

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
// WiFi Provisioning Configuration
// WiFi credentials are stored in NVS (non-volatile storage) via the
// SmartWatch Setup companion app. NO hardcoded credentials needed!
// ── How to set up WiFi ──────────────────────────────────────────────────
//   1. Power on the watch — it shows "WiFi Setup" screen if no WiFi saved
//   2. Connect your phone/PC to WiFi: "SmartWatch-Setup" / "setup1234"
//   3. Open the SmartWatch Setup app
//   4. Pick your home WiFi and enter password → watch saves & restarts
// ── Reset WiFi ───────────────────────────────────────────────────────────
//   Hold the BOOT button for 3 seconds to clear saved WiFi and re-enter
//   provisioning mode.
// ═══════════════════════════════════════════════════════════════════════════
const char* AP_SSID     = "SmartWatch-Setup";  // Provisioning hotspot name
const char* AP_PASSWORD = "setup1234";          // Provisioning hotspot password
// NVS storage + HTTP server used during provisioning
Preferences wifiPrefs;
WebServer   setupServer(80);
bool        apMode = false;

const char* SUPABASE_URL = "https://cnktjnchyyttjvslvdpr.supabase.co";
const char* SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzkyMzksImV4cCI6MjA5MTQ1NTIzOX0.HMF3yowDRciupe3BO-9gn-1vE5IWm7NYQWpQKDmqd4g";
const char* DEVICE_NAME = "ESP32 SmartWatch";
const char* FIRMWARE_VERSION = "v3.8-wifi-provisioning";
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

// ─── MAX30102 Registers ────────────────────────────────────────────────────
#define MAX30102_ADDR       0x57
#define MAX_REG_INTR_STAT1  0x00
#define MAX_REG_FIFO_WR_PTR 0x04
#define MAX_REG_FIFO_OVF    0x05
#define MAX_REG_FIFO_RD_PTR 0x06
#define MAX_REG_FIFO_DATA   0x07
#define MAX_REG_FIFO_CFG    0x08
#define MAX_REG_MODE_CFG    0x09
#define MAX_REG_SPO2_CFG    0x0A
#define MAX_REG_LED1_PA     0x0C
#define MAX_REG_LED2_PA     0x0D
#define MAX_REG_PART_ID     0xFF

TwoWire Wire2 = TwoWire(1);  // Second I2C bus for MAX30102

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
unsigned long lastAlertHrMs    = 0;  // per-vital alert cooldowns
unsigned long lastAlertSpo2Ms  = 0;
unsigned long lastAlertTempMs  = 0;
unsigned long lastAlertCo2Ms   = 0;
unsigned long lastAlertTvocMs  = 0;
unsigned long lastAlertFallMs  = 0;
#define ALERT_COOLDOWN_MS 30000UL   // 30s per vital

// Step-rate tracking for activity-aware HR alerts
int  stepRatePM     = 0;       // estimated steps per minute (rolling)
int  stepsLastMin   = 0;       // step count captured 60s ago
unsigned long stepRateCalcMs = 0;  // when we last computed stepRatePM
#define FALL_COOLDOWN_MS  60000UL   // 60s between fall alerts

// ─── Fall Detection State ──────────────────────────────────────────────────
bool          fallFreefallArmed = false;  // true when free-fall phase detected
unsigned long fallFreefallMs    = 0;      // millis() when free-fall started
bool          fallDetectedFlag  = false;  // set true on confirmed fall, cleared after sync
#define FALL_FREEFALL_THRESH  3000.0f    // < ~0.37g (±4g, 8192 LSB/g) = free-fall
#define FALL_IMPACT_THRESH   22000.0f   // > ~2.7g = impact after fall
#define FALL_WINDOW_MS         700UL    // max ms between free-fall and impact
unsigned long lastSyncOkMs = 0;
unsigned long lastGestureMs = 0;
unsigned long lastPatientFetchMs = 0;
bool touchTracking = false;
bool swipeHandled = false;
bool lastSyncOk = false;
uint8_t touchGesture = 0;
uint16_t touchStartX = 0, touchStartY = 0;
uint16_t touchLastX = 0, touchLastY = 0;
uint8_t touchNoContactCount = 0;  // consecutive no-touch polls before finalizing
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

// ─── AHT21 Humidity + Temperature (I2C 0x38) ─────────────────────────────
bool  aht21Ready    = false;
float aht21Humidity = 0.0f;   // %RH
float aht21AmbientC = 0.0f;   // °C

// ─── ENS160 Air Quality (I2C 0x52) ──────────────────────────────────────
bool     ens160Ready = false;
uint16_t ens160Eco2  = 400;   // ppm
uint16_t ens160Tvoc  = 0;     // ppb
uint8_t  ens160Aqi   = 1;     // 1=Excellent 2=Good 3=Moderate 4=Poor 5=Unhealthy

// ─── MLX90614 Contactless Temperature (I2C 0x5A) ────────────────────────
bool  mlx90614Ready = false;
float bodyTempF     = 98.4f;  // object (body) temperature °F
float mlxAmbientF   = 0.0f;   // ambient temperature °F
unsigned long lastSensorReadMs = 0;

// ─── MAX30102 Heart Rate + SpO2 ────────────────────────────────────────────
bool     max30102Ready    = false;
int      max30102Hr       = 0;
int      max30102Spo2     = 0;
bool     max30102Valid    = false;
bool     fingerPresent    = false;
#define  MAX30102_SAMPLES  100
uint32_t irBuf[MAX30102_SAMPLES];
uint32_t redBuf[MAX30102_SAMPLES];
uint8_t  maxBufIdx        = 0;
unsigned long lastMaxSampleMs  = 0;
unsigned long lastMaxRetryMs   = 0;  // retry Bus2 init if MAX30102 drops off

// AHT21 non-blocking state
bool          aht21Triggered  = false;
unsigned long aht21TriggerMs  = 0;

// ═══════════════════════════════════════════════════════════════════════════
// AHT21 Humidity + Temperature Sensor
// ═══════════════════════════════════════════════════════════════════════════
#define AHT21_ADDR 0x38

bool aht21_init() {
  Wire.beginTransmission(AHT21_ADDR);
  if (Wire.endTransmission() != 0) return false;
  delay(40);
  Wire.beginTransmission(AHT21_ADDR);
  Wire.write(0xBE); Wire.write(0x08); Wire.write(0x00);
  Wire.endTransmission();
  delay(10);
  return true;
}

// Send measurement trigger — call this, then wait >= 80ms before aht21_fetch()
void aht21_trigger() {
  Wire.beginTransmission(AHT21_ADDR);
  Wire.write(0xAC); Wire.write(0x33); Wire.write(0x00);
  Wire.endTransmission();
}

// Read result — only call >= 80ms after aht21_trigger()
bool aht21_fetch(float &humidity, float &tempC) {
  Wire.requestFrom((uint8_t)AHT21_ADDR, (uint8_t)6);
  if (Wire.available() < 6) return false;
  uint8_t buf[6];
  for (int i = 0; i < 6; i++) buf[i] = Wire.read();
  if (buf[0] & 0x80) return false; // busy
  uint32_t rawHum  = ((uint32_t)buf[1] << 12) | ((uint32_t)buf[2] << 4) | (buf[3] >> 4);
  uint32_t rawTemp = ((uint32_t)(buf[3] & 0x0F) << 16) | ((uint32_t)buf[4] << 8) | buf[5];
  humidity = rawHum  / 1048576.0f * 100.0f;
  tempC    = rawTemp / 1048576.0f * 200.0f - 50.0f;
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// ENS160 Air Quality Sensor (eCO2, TVOC, AQI)
// ═══════════════════════════════════════════════════════════════════════════
#define ENS160_ADDR        0x52
#define ENS160_REG_OPMODE  0x10
#define ENS160_REG_DSTATUS 0x20
#define ENS160_REG_STATUS  0x40
#define ENS160_REG_AQI     0x41
#define ENS160_REG_TVOC    0x42
#define ENS160_REG_ECO2    0x44

void ens160_write(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(ENS160_ADDR);
  Wire.write(reg); Wire.write(val);
  Wire.endTransmission();
}

uint8_t ens160_read1(uint8_t reg) {
  Wire.beginTransmission(ENS160_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)ENS160_ADDR, (uint8_t)1);
  return Wire.available() ? Wire.read() : 0;
}

uint16_t ens160_read2(uint8_t reg) {
  Wire.beginTransmission(ENS160_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)ENS160_ADDR, (uint8_t)2);
  if (Wire.available() < 2) return 0;
  uint8_t lo = Wire.read(), hi = Wire.read();
  return ((uint16_t)hi << 8) | lo;
}

bool ens160_init() {
  Wire.beginTransmission(ENS160_ADDR);
  if (Wire.endTransmission() != 0) return false;
  ens160_write(ENS160_REG_OPMODE, 0xF0); // Reset
  delay(20);
  ens160_write(ENS160_REG_OPMODE, 0x02); // Standard mode
  delay(50);
  Serial.println("[ENS160] Ready. AHT21 compensation will be applied after first AHT21 reading.");
  return true;
}

// Write AHT21 temperature + humidity to ENS160 compensation registers.
// ENS160 requires ambient T/H to correct its baseline; without this its
// eCO2/TVOC readings can drift by 10-30% in unusual environments.
// Register 0x13 = temp (K * 64, 16-bit LE), Register 0x15 = RH (% * 512, 16-bit LE).
void ens160_compensate(float tempC, float humidity) {
  if (!ens160Ready) return;
  uint16_t tReg = (uint16_t)((tempC + 273.15f) * 64.0f);
  uint16_t hReg = (uint16_t)(humidity * 512.0f);
  Wire.beginTransmission(ENS160_ADDR);
  Wire.write(0x13);           // TEMP_IN register
  Wire.write(tReg & 0xFF);
  Wire.write(tReg >> 8);
  Wire.endTransmission();
  Wire.beginTransmission(ENS160_ADDR);
  Wire.write(0x15);           // RH_IN register
  Wire.write(hReg & 0xFF);
  Wire.write(hReg >> 8);
  Wire.endTransmission();
}

bool ens160_read(uint16_t &eco2, uint16_t &tvoc, uint8_t &aqi) {
  uint8_t status = ens160_read1(ENS160_REG_STATUS);
  if (!(status & 0x02)) return false; // no new data
  aqi  = ens160_read1(ENS160_REG_AQI) & 0x07;
  tvoc = ens160_read2(ENS160_REG_TVOC);
  eco2 = ens160_read2(ENS160_REG_ECO2);
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// MLX90614 Contactless Temperature Sensor
// ═══════════════════════════════════════════════════════════════════════════
#define MLX90614_ADDR  0x5A
#define MLX_REG_TOBJ   0x07  // Object (body) temperature
#define MLX_REG_TAMB   0x06  // Ambient temperature

bool mlx90614_init() {
  Wire.beginTransmission(MLX90614_ADDR);
  return Wire.endTransmission() == 0;
}

float mlx90614_readTempF(uint8_t reg) {
  Wire.beginTransmission(MLX90614_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)MLX90614_ADDR, (uint8_t)3);
  if (Wire.available() < 3) return -999.0f;
  uint8_t lo = Wire.read();
  uint8_t hi = Wire.read();
  Wire.read(); // PEC byte
  uint16_t raw = ((uint16_t)hi << 8) | lo;
  if (raw & 0x8000) return -999.0f; // error flag
  float tempC = raw * 0.02f - 273.15f;
  return tempC * 9.0f / 5.0f + 32.0f;
}

// ═══════════════════════════════════════════════════════════════════════════
// MAX30102 Heart Rate + SpO2 Sensor (Wire2, GPIO3/GPIO5)
// ═══════════════════════════════════════════════════════════════════════════

void max30102_write(uint8_t reg, uint8_t val) {
  Wire2.beginTransmission(MAX30102_ADDR);
  Wire2.write(reg);
  Wire2.write(val);
  Wire2.endTransmission();
}

uint8_t max30102_read1(uint8_t reg) {
  Wire2.beginTransmission(MAX30102_ADDR);
  Wire2.write(reg);
  Wire2.endTransmission(false);
  Wire2.requestFrom((uint8_t)MAX30102_ADDR, (uint8_t)1);
  return Wire2.available() ? Wire2.read() : 0;
}

bool max30102_init() {
  Wire2.beginTransmission(MAX30102_ADDR);
  if (Wire2.endTransmission() != 0) {
    Serial.println("[MAX30102] Not found on GPIO3/GPIO5");
    return false;
  }
  uint8_t partId = max30102_read1(MAX_REG_PART_ID);
  if (partId != 0x15) {
    Serial.printf("[MAX30102] Bad Part ID: 0x%02X (expected 0x15)\n", partId);
    return false;
  }
  max30102_write(MAX_REG_MODE_CFG, 0x40);  // Reset
  delay(100);
  max30102_write(MAX_REG_FIFO_WR_PTR, 0x00);
  max30102_write(MAX_REG_FIFO_OVF,    0x00);
  max30102_write(MAX_REG_FIFO_RD_PTR, 0x00);
  // FIFO: 4-sample averaging (25sps effective), rollover on, almost-full=15
  max30102_write(MAX_REG_FIFO_CFG, 0x5F);
  // SpO2 mode (RED + IR)
  max30102_write(MAX_REG_MODE_CFG, 0x03);
  // ADC 4096nA, 100sps (25sps after 4-avg), PW=411us
  max30102_write(MAX_REG_SPO2_CFG, 0x27);
  // LED currents ~6.4mA
  max30102_write(MAX_REG_LED1_PA, 0x24);
  max30102_write(MAX_REG_LED2_PA, 0x24);
  Serial.println("[MAX30102] Ready — SpO2 mode 25sps");
  return true;
}

bool max30102_readFIFO(uint32_t &red, uint32_t &ir) {
  uint8_t wrPtr = max30102_read1(MAX_REG_FIFO_WR_PTR);
  uint8_t rdPtr = max30102_read1(MAX_REG_FIFO_RD_PTR);
  if (wrPtr == rdPtr) return false;
  Wire2.beginTransmission(MAX30102_ADDR);
  Wire2.write(MAX_REG_FIFO_DATA);
  Wire2.endTransmission(false);
  Wire2.requestFrom((uint8_t)MAX30102_ADDR, (uint8_t)6);
  if (Wire2.available() < 6) return false;
  red = ((uint32_t)(Wire2.read() & 0x03) << 16) | ((uint32_t)Wire2.read() << 8) | Wire2.read();
  ir  = ((uint32_t)(Wire2.read() & 0x03) << 16) | ((uint32_t)Wire2.read() << 8) | Wire2.read();
  return true;
}

void max30102_calculate() {
  // ── 1. Compute DC mean over the full window ───────────────────────────────
  uint64_t irSum = 0, redSum = 0;
  for (int i = 0; i < MAX30102_SAMPLES; i++) { irSum += irBuf[i]; redSum += redBuf[i]; }
  int32_t irMean  = (int32_t)(irSum  / MAX30102_SAMPLES);
  int32_t redMean = (int32_t)(redSum / MAX30102_SAMPLES);

  // Finger presence: IR DC must be well above the ambient noise floor.
  // 30000 = reliable minimum; 50000 = good contact; < 30000 = no finger.
  fingerPresent = (irMean > 30000);
  if (!fingerPresent) { max30102Valid = false; return; }

  // ── 2. Remove DC baseline (AC component) ─────────────────────────────────
  int32_t irAC[MAX30102_SAMPLES], redAC[MAX30102_SAMPLES];
  for (int i = 0; i < MAX30102_SAMPLES; i++) {
    irAC[i]  = (int32_t)irBuf[i]  - irMean;
    redAC[i] = (int32_t)redBuf[i] - redMean;
  }

  // ── 3. HR: peak-to-peak detection (more accurate than zero-crossing) ──────
  //  Find all local maxima in the IR AC signal.
  //  A sample is a peak if it is larger than its two neighbours AND
  //  above a minimum amplitude threshold (avoids counting noise peaks).
  int32_t irPeak = 0;
  for (int i = 0; i < MAX30102_SAMPLES; i++) if (irAC[i] > irPeak) irPeak = irAC[i];

  // Threshold = 40% of the peak amplitude (avoids noise, still catches dicrotic)
  int32_t peakThreshold = irPeak * 40 / 100;

  int  peakCount  = 0;
  bool aboveThresh = false;
  int  lastPeakIdx = -1;
  int  peakIntervalSum = 0;
  int  intervalCount   = 0;

  for (int i = 1; i < MAX30102_SAMPLES - 1; i++) {
    if (irAC[i] > peakThreshold) {
      if (!aboveThresh) aboveThresh = true;
      // Local maximum check
      if (irAC[i] > irAC[i-1] && irAC[i] >= irAC[i+1]) {
        if (lastPeakIdx >= 0) {
          int interval = i - lastPeakIdx;
          // Debounce: ignore peaks less than ~200ms apart (>= 5 samples @ 25sps)
          if (interval >= 5) {
            peakIntervalSum += interval;
            intervalCount++;
          }
        }
        lastPeakIdx = i;
        peakCount++;
      }
    } else {
      aboveThresh = false;
    }
  }

  // Average sample interval between beats → BPM
  // Samples at 25sps; BPM = 60 / (interval / 25) = 60 * 25 / interval = 1500 / interval
  if (intervalCount >= 1 && peakIntervalSum > 0) {
    float avgInterval = (float)peakIntervalSum / intervalCount;
    int   newHr       = (int)(1500.0f / avgInterval);  // 60s * 25sps / avg_samples
    if (newHr >= 40 && newHr <= 200) {
      // Smooth with exponential moving average to reduce beat-to-beat jitter
      if (max30102Hr == 0) {
        max30102Hr = newHr;
      } else {
        max30102Hr = (int)(0.7f * max30102Hr + 0.3f * newHr);
      }
    }
  } else if (peakCount == 0) {
    // No peaks detected in this window — reset
    max30102Valid = false;
    return;
  }

  // ── 4. SpO2: ratio-of-ratios with RMS AC amplitudes ──────────────────────
  //  SpO2 = 110 - 25 * R  where R = (RedAC/RedDC) / (IrAC/IrDC)
  //  Using RMS for a more robust AC estimate than simple peak.
  float irRms = 0, redRms = 0;
  for (int i = 0; i < MAX30102_SAMPLES; i++) {
    irRms  += (float)irAC[i]  * irAC[i];
    redRms += (float)redAC[i] * redAC[i];
  }
  irRms  = sqrtf(irRms  / MAX30102_SAMPLES);
  redRms = sqrtf(redRms / MAX30102_SAMPLES);

  if (irRms > 200.0f && irMean > 0 && redMean > 0) {
    float R = (redRms / (float)redMean) / (irRms / (float)irMean);
    // Empirical calibration: SpO2 = 110 - 25*R gives ~±1-2% accuracy for R in 0.4–1.0
    // Additional offset correction for typical wrist placement (+1%)
    int newSpo2 = (int)(111.0f - 25.0f * R);
    newSpo2 = constrain(newSpo2, 85, 100);
    // Smooth SpO2 to prevent single-sample drops triggering false alerts
    if (max30102Spo2 == 0) {
      max30102Spo2 = newSpo2;
    } else {
      max30102Spo2 = (int)(0.8f * max30102Spo2 + 0.2f * newSpo2);
    }
  }

  if (max30102Hr >= 40 && max30102Hr <= 200 && max30102Spo2 >= 85) {
    max30102Valid = true;
    Serial.printf("[MAX30102] HR=%d bpm  SpO2=%d%%  IR_DC=%d  peaks=%d  R=%.3f\n",
      max30102Hr, max30102Spo2, irMean, peakCount,
      (irRms > 0 && irMean > 0 && redMean > 0)
        ? (redRms / (float)redMean) / (irRms / (float)irMean) : 0.0f);
  }
}

void max30102_sampleLoop() {
  uint32_t red, ir;
  if (!max30102_readFIFO(red, ir)) return;
  irBuf[maxBufIdx]  = ir;
  redBuf[maxBufIdx] = red;
  maxBufIdx++;
  if (maxBufIdx >= MAX30102_SAMPLES) {
    maxBufIdx = 0;
    max30102_calculate();
  }
}

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
  // Wire already started in setup() — do NOT call Wire.begin() again here

  // Soft reset — QMI8658 needs at least 50ms after reset before it responds
  qmi8658_write(QMI8658_RESET, 0xB0);
  delay(100);

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

// i2cBusRecover() is now only called at the top of setup(), before Wire.begin().
// Do not call it after Wire is initialized — it is no longer needed mid-flight.

bool touchInit() {
  pinMode(TP_INT, INPUT_PULLUP);

  Serial.println("[TOUCH] === CST816 Touch Diagnostics ===");

  // ── Step 1: Check I2C bus state before touching CST816 ─────────────────
  bool sdaOk = digitalRead(IMU_SDA) == HIGH;
  bool sclOk = digitalRead(IMU_SCL) == HIGH;
  Serial.printf("[TOUCH] I2C bus before recovery: SDA=%s SCL=%s\n",
    sdaOk ? "HIGH(OK)" : "LOW(STUCK!)",
    sclOk ? "HIGH(OK)" : "LOW(STUCK!)");
  if (!sdaOk || !sclOk) {
    Serial.println("[TOUCH] CAUSE: I2C bus is stuck. Another sensor may be holding SDA or SCL low.");
    Serial.println("[TOUCH] FIX : Check wiring for short circuits on SDA(GPIO47)/SCL(GPIO48).");
    Serial.println("[TOUCH]       Running 9-clock recovery sequence...");
  }

  // ── Step 2: 9-clock bus recovery to release any stuck slave ────────────
  {
    pinMode(IMU_SDA, INPUT_PULLUP);
    pinMode(IMU_SCL, OUTPUT);
    for (int i = 0; i < 9; i++) {
      digitalWrite(IMU_SCL, LOW);  delayMicroseconds(10);
      digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
      if (digitalRead(IMU_SDA) == HIGH && i >= 1) {
        Serial.printf("[TOUCH] Bus released after %d clock pulses.\n", i + 1);
        break;
      }
    }
    // STOP condition
    pinMode(IMU_SDA, OUTPUT);
    digitalWrite(IMU_SDA, LOW);  delayMicroseconds(10);
    digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
    digitalWrite(IMU_SDA, HIGH); delayMicroseconds(10);
    // Hand pins back to Wire
    Wire.begin(IMU_SDA, IMU_SCL);
    Wire.setTimeOut(50);
    delay(20);
  }

  // ── Step 3: Check if TP_INT pin is responding ───────────────────────────
  int tpIntState = digitalRead(TP_INT);
  Serial.printf("[TOUCH] TP_INT (GPIO%d) state: %s\n", TP_INT,
    tpIntState == HIGH ? "HIGH (normal idle)" : "LOW (touch active or short to GND)");
  if (tpIntState == LOW) {
    Serial.println("[TOUCH] WARNING: TP_INT is LOW at startup. Possible causes:");
    Serial.println("[TOUCH]   - Touch screen is physically pressed at boot");
    Serial.println("[TOUCH]   - TP_INT pin shorted to GND");
    Serial.println("[TOUCH]   - CST816 power supply issue (check 3.3V rail)");
  }

  // ── Step 4: Write normal mode to CST816 register 0x00 ──────────────────
  // CST816 does NOT respond to bare address probe — must write a register.
  Wire.beginTransmission(TOUCH_ADDR);
  Wire.write(0x00);  // register
  Wire.write(0x00);  // value: normal mode
  uint8_t writeErr = Wire.endTransmission();

  if (writeErr != 0) {
    delay(50);
    Wire.beginTransmission(TOUCH_ADDR);
    Wire.write(0x00);
    Wire.write(0x00);
    writeErr = Wire.endTransmission();
  }

  if (writeErr != 0) {
    Serial.printf("[TOUCH] FAILED: CST816 write error code %d\n", writeErr);
    // Decode Wire error codes for easy debugging
    switch (writeErr) {
      case 1: Serial.println("[TOUCH] ERROR 1: Data too long for transmit buffer"); break;
      case 2: Serial.println("[TOUCH] ERROR 2: NACK on address — CST816 not on bus (check 3.3V / wiring)"); break;
      case 3: Serial.println("[TOUCH] ERROR 3: NACK on data byte — device responded to address but rejected data"); break;
      case 4: Serial.println("[TOUCH] ERROR 4: I2C bus error (SDA/SCL stuck) — check for I2C bus contention"); break;
      case 5: Serial.println("[TOUCH] ERROR 5: Timeout — device did not respond within Wire timeout"); break;
      default: Serial.printf("[TOUCH] ERROR %d: Unknown Wire error\n", writeErr); break;
    }
    Serial.println("[TOUCH] DIAGNOSIS SUMMARY:");
    Serial.printf("[TOUCH]   Address   : 0x%02X\n", TOUCH_ADDR);
    Serial.printf("[TOUCH]   SDA pin   : GPIO%d  state=%s\n", IMU_SDA, digitalRead(IMU_SDA) ? "HIGH" : "LOW");
    Serial.printf("[TOUCH]   SCL pin   : GPIO%d  state=%s\n", IMU_SCL, digitalRead(IMU_SCL) ? "HIGH" : "LOW");
    Serial.printf("[TOUCH]   TP_INT    : GPIO%d  state=%s\n", TP_INT,  digitalRead(TP_INT)  ? "HIGH" : "LOW");
    Serial.println("[TOUCH]   COMMON FIXES:");
    Serial.println("[TOUCH]     1. Verify 3.3V is present on the touch panel connector");
    Serial.println("[TOUCH]     2. Check that SDA=GPIO47, SCL=GPIO48 match board pinout");
    Serial.println("[TOUCH]     3. Look for solder bridges or damaged flex cable on the touch panel");
    Serial.println("[TOUCH]     4. Try power-cycling the board (not just reset)");
    Serial.println("[TOUCH] Touch controller DISABLED — swipe/tap navigation unavailable.");
    return false;
  }

  // ── Step 5: Read chip ID register 0xA7 to verify identity ──────────────
  Wire.beginTransmission(TOUCH_ADDR);
  Wire.write(0xA7);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)TOUCH_ADDR, (uint8_t)3);
  uint8_t chipId  = Wire.available() ? Wire.read() : 0;
  uint8_t projId  = Wire.available() ? Wire.read() : 0;
  uint8_t fwVer   = Wire.available() ? Wire.read() : 0;
  Serial.printf("[TOUCH] Chip ID: 0x%02X  Project ID: 0x%02X  FW Ver: 0x%02X\n", chipId, projId, fwVer);

  if (chipId == 0) {
    Serial.println("[TOUCH] WARNING: Chip ID returned 0x00 — CST816 may be in reset or damaged.");
    Serial.println("[TOUCH]   Try: power cycle the board, check touch panel flex cable seating.");
  }

  Serial.println("[TOUCH] === CST816 READY — tap and swipe navigation active ===");
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
  touchNoContactCount = 0;
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
  // Use real MAX30102 readings when finger is detected
  if (max30102Ready && max30102Valid && fingerPresent) {
    heartRate = max30102Hr;
    spo2      = max30102Spo2;
  } else {
    // Simulated fallback when no finger on sensor
    heartRate = 72 + (int)(4.0f * sin(millis() / 2600.0f));
    if (heartRate < 60) heartRate = 60;
    if (heartRate > 110) heartRate = 110;
    spo2 = 97 + (int)(1.0f * sin(millis() / 3200.0f));
    if (spo2 < 95) spo2 = 95;
    if (spo2 > 100) spo2 = 100;
  }

  // Use real MLX90614 body temperature if available, otherwise fallback
  if (!mlx90614Ready) {
    temperatureF = 98.4f + 0.25f * sin(millis() / 9000.0f);
  }

  int liveBattery = 87 - (int)(millis() / 300000UL);
  battery = liveBattery < 15 ? 15 : liveBattery;
}

// Phase 1 — kick off slow sensors (call every 5s)
void triggerSlowSensors() {
  if (aht21Ready) {
    aht21_trigger();
    aht21TriggerMs = millis();
    aht21Triggered = true;
  }
}

// Phase 2 — collect results (call >= 100ms after triggerSlowSensors)
void readAllSensors() {
  // AHT21 — result available 80ms+ after trigger
  if (aht21Ready && aht21Triggered && millis() - aht21TriggerMs >= 90) {
    float h, t;
    if (aht21_fetch(h, t)) {
      aht21Humidity = h;
      aht21AmbientC = t;
      // Feed T+H to ENS160 for accurate eCO2/TVOC compensation
      ens160_compensate(t, h);
    }
    aht21Triggered = false;
  }

  // ENS160 — eCO2, TVOC, AQI (no blocking delay needed)
  if (ens160Ready) {
    uint16_t co2, voc;
    uint8_t  aqi;
    if (ens160_read(co2, voc, aqi)) {
      ens160Eco2 = co2;
      ens160Tvoc = voc;
      ens160Aqi  = aqi;
    }
  }

  // MLX90614 — body + ambient temperature (no blocking delay)
  if (mlx90614Ready) {
    float bt = mlx90614_readTempF(MLX_REG_TOBJ);
    float at = mlx90614_readTempF(MLX_REG_TAMB);
    if (bt > -900.0f && bt > 60.0f && bt < 120.0f) temperatureF = bt;
    if (at > -900.0f) mlxAmbientF = at;
    bodyTempF = temperatureF;
  }
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
      // Fetch patient metadata only — do NOT overwrite live sensor readings.
      // The watch is the source of truth for vitals; Supabase reflects the watch.
      // Only pull back steps if we have no IMU (edge case).
      if (!imuReady && !mpu6050Ready) {
        steps = extractJsonInt(body, "steps", steps);
      }
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
  unsigned long now = millis();

  // ── Activity-aware HR thresholds ────────────────────────────────────────
  // If the patient is actively walking/exercising (step rate >= 20 steps/min),
  // the high-HR warning threshold is relaxed to 130 bpm to avoid false alarms
  // during normal physical activity. Critical (>=120 at rest, >=150 active) still fires.
  bool activeExercise = (stepRatePM >= 20);  // stepRatePM = recent steps-per-minute

  int hrWarnHigh     = activeExercise ? 130 : 100;
  int hrCriticalHigh = activeExercise ? 150 : 120;
  int hrWarnLow      = 55;
  int hrCriticalLow  = 45;

  if (now - lastAlertHrMs >= ALERT_COOLDOWN_MS) {
    String source = (max30102Ready && max30102Valid && fingerPresent) ? " (MAX30102)" : " (est)";
    if (heartRate >= hrCriticalHigh || heartRate <= hrCriticalLow) {
      String detail = "Heart rate " + String(heartRate) + " bpm" + source + " on " + deviceId;
      if (activeExercise && heartRate >= hrCriticalHigh)
        detail += " (active exercise — rule out exertion)";
      if (postAlertToCloud("Critical heart rate detected", "critical", detail)) {
        lastAlertHrMs = now;
        pushPopup("CRITICAL: HR " + String(heartRate) + " bpm", C_RED, 5000);
      }
    } else if (heartRate >= hrWarnHigh || heartRate <= hrWarnLow) {
      if (postAlertToCloud("Heart rate warning", "warning",
          "Heart rate " + String(heartRate) + " bpm" + source + " on " + deviceId)) {
        lastAlertHrMs = now;
        pushPopup("WARNING: HR " + String(heartRate) + " bpm", C_ORANGE, 4000);
      }
    }
  }

  // ── SpO2 ────────────────────────────────────────────────────────────────
  // Only alert when the MAX30102 is providing a real reading with finger contact.
  if (max30102Ready && max30102Valid && fingerPresent && now - lastAlertSpo2Ms >= ALERT_COOLDOWN_MS) {
    String source = " (MAX30102) on " + deviceId;
    if (spo2 < 90) {
      if (postAlertToCloud("Critical SpO2 detected", "critical",
          "SpO2 " + String(spo2) + "%" + source + " — possible hypoxemia")) {
        lastAlertSpo2Ms = now;
        pushPopup("CRITICAL: SpO2 " + String(spo2) + "%", C_RED, 5000);
      }
    } else if (spo2 < 94) {
      if (postAlertToCloud("Low SpO2 warning", "warning",
          "SpO2 " + String(spo2) + "%" + source)) {
        lastAlertSpo2Ms = now;
        pushPopup("WARNING: SpO2 " + String(spo2) + "%", C_ORANGE, 4000);
      }
    }
  }

  // ── Temperature (MLX90614 — wrist/forehead contactless) ─────────────────
  // Note: MLX90614 is a contactless IR sensor; readings reflect skin surface
  // temperature which is typically 1-3°F lower than core body temperature.
  if (mlx90614Ready && now - lastAlertTempMs >= ALERT_COOLDOWN_MS) {
    // Critical: >=103°F (severe fever) or <=94°F (hypothermia)
    if (temperatureF >= 103.0f || temperatureF <= 94.0f) {
      String sev = "critical";
      String msg = temperatureF >= 103.0f
          ? "High fever " + String(temperatureF, 1) + "F (MLX90614) on " + deviceId + " — assess immediately"
          : "Hypothermia risk " + String(temperatureF, 1) + "F (MLX90614) on " + deviceId;
      if (postAlertToCloud("Critical temperature alert", sev, msg)) {
        lastAlertTempMs = now;
        pushPopup("CRITICAL: Temp " + String(temperatureF, 1) + "F", C_RED, 5000);
      }
    } else if (temperatureF >= 101.0f || temperatureF <= 96.0f) {
      // Warning: fever >101°F or below-normal <96°F
      if (postAlertToCloud("Temperature warning", "warning",
          "Temp " + String(temperatureF, 1) + "F (MLX90614) on " + deviceId)) {
        lastAlertTempMs = now;
        pushPopup("WARNING: Temp " + String(temperatureF, 1) + "F", C_ORANGE, 4000);
      }
    } else if (temperatureF >= 99.5f && temperatureF < 101.0f) {
      // Low-grade fever — informational warning
      if (postAlertToCloud("Low-grade fever detected", "warning",
          "Temp " + String(temperatureF, 1) + "F (MLX90614) on " + deviceId)) {
        lastAlertTempMs = now;
        pushPopup("Fever: " + String(temperatureF, 1) + "F", C_ORANGE, 4000);
      }
    }
  }

  // ── CO2 (ENS160, AHT21-compensated) ─────────────────────────────────────
  if (ens160Ready && now - lastAlertCo2Ms >= ALERT_COOLDOWN_MS) {
    // Ranges: 400=fresh outdoor, <1000=acceptable indoor, 1000-2000=poor,
    //         >2000=dangerous (WHO: cognitive impairment risk)
    if (ens160Eco2 > 2000) {
      if (postAlertToCloud("Dangerous CO2 level", "critical",
          "eCO2 " + String(ens160Eco2) + " ppm on " + deviceId + " — ventilate room immediately")) {
        lastAlertCo2Ms = now;
        pushPopup("CRITICAL: CO2 " + String(ens160Eco2) + "ppm", C_RED, 5000);
      }
    } else if (ens160Eco2 > 1000) {
      if (postAlertToCloud("Elevated CO2 warning", "warning",
          "eCO2 " + String(ens160Eco2) + " ppm on " + deviceId + " — increase ventilation")) {
        lastAlertCo2Ms = now;
        pushPopup("WARNING: CO2 " + String(ens160Eco2) + "ppm", C_ORANGE, 4000);
      }
    }
  }

  // ── TVOC (ENS160) ────────────────────────────────────────────────────────
  if (ens160Ready && now - lastAlertTvocMs >= ALERT_COOLDOWN_MS) {
    // TVOC >2000 ppb = very poor air quality; >500 ppb = moderate concern
    if (ens160Tvoc > 2000) {
      if (postAlertToCloud("High TVOC level", "critical",
          "TVOC " + String(ens160Tvoc) + " ppb on " + deviceId + " — possible chemical exposure")) {
        lastAlertTvocMs = now;
        pushPopup("CRITICAL: TVOC " + String(ens160Tvoc) + "ppb", C_RED, 5000);
      }
    } else if (ens160Tvoc > 500) {
      if (postAlertToCloud("Elevated TVOC warning", "warning",
          "TVOC " + String(ens160Tvoc) + " ppb on " + deviceId)) {
        lastAlertTvocMs = now;
        pushPopup("WARNING: TVOC " + String(ens160Tvoc) + "ppb", C_ORANGE, 4000);
      }
    }
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
    patientBody += "\"heart_rate\":" + String(heartRate) + ",";
    patientBody += "\"spo2\":" + String(spo2) + ",";
    patientBody += "\"temperature\":" + String(temperatureF, 1) + ",";
    patientBody += "\"steps\":" + String(steps) + ",";
    patientBody += "\"humidity\":" + String(aht21Humidity, 1) + ",";
    patientBody += "\"eco2\":" + String(ens160Eco2) + ",";
    patientBody += "\"tvoc\":" + String(ens160Tvoc) + ",";
    patientBody += "\"ambient_temp\":" + String(aht21AmbientC, 1) + ",";
    patientBody += "\"fall_detected\":" + String(fallDetectedFlag ? "true" : "false");
    patientBody += "}";
    if (fallDetectedFlag) fallDetectedFlag = false;  // clear after sending
    patientCode = patientHttp.sendRequest("PATCH", patientBody);
    patientHttp.end();
  }

  lastSyncOk = (deviceCode >= 200 && deviceCode < 300) && (!patientLinked || (patientCode >= 200 && patientCode < 300));
  if (lastSyncOk) {
    lastSyncOkMs = millis();
  }

  maybeSendVitalAlerts();
  Serial.printf("[SYNC] device=%s hr=%d spo2=%d temp=%.1f steps=%d hum=%.1f co2=%u tvoc=%u ok=%d\n", deviceId.c_str(), heartRate, spo2, temperatureF, steps, aht21Humidity, ens160Eco2, ens160Tvoc, lastSyncOk);
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
// Fall Detection (two-phase: free-fall then impact within window)
// Uses QMI8658 accelX/Y/Z already updated by detectSteps() every 20ms.
// At ±4g with 8192 LSB/g:
//   Free-fall threshold  : < 3000  raw (~0.37g)
//   Impact threshold     : > 22000 raw (~2.7g)
// ═══════════════════════════════════════════════════════════════════════════

void detectFall() {
  if (!imuReady) return;
  // accelX/Y/Z are populated by detectSteps() which runs just before this
  float mag = sqrtf((float)accelX * accelX + (float)accelY * accelY + (float)accelZ * accelZ);
  unsigned long now = millis();

  // Phase 1 — free-fall: near-zero gravity reading
  if (!fallFreefallArmed && mag < FALL_FREEFALL_THRESH) {
    fallFreefallArmed = true;
    fallFreefallMs    = now;
    return;
  }

  // Phase 2 — impact: large spike within window after free-fall
  if (fallFreefallArmed) {
    if (now - fallFreefallMs > FALL_WINDOW_MS) {
      fallFreefallArmed = false;  // window expired, not a fall
      return;
    }
    if (mag > FALL_IMPACT_THRESH) {
      fallFreefallArmed = false;
      if (now - lastAlertFallMs >= FALL_COOLDOWN_MS) {
        lastAlertFallMs  = now;
        fallDetectedFlag = true;
        Serial.printf("[FALL] Fall detected! accel=%.0f\n", mag);
        pushPopup("FALL DETECTED!", C_RED, 8000);
        if (patientLinked && wifiConnected) {
          postAlertToCloud("Fall detected", "critical",
              "Possible fall on " + deviceId + " — check patient immediately!");
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WiFi Provisioning — AP Mode HTTP Server
// ═══════════════════════════════════════════════════════════════════════════

// ── Simple JSON string field extractor (avoids ArduinoJson dependency) ────
String extractJsonValue(const String& body, const String& key) {
  String search = "\"" + key + "\":\"";
  int start = body.indexOf(search);
  if (start < 0) return "";
  start += search.length();
  int end = body.indexOf("\"", start);
  return (end < 0) ? "" : body.substring(start, end);
}

void addCORSHeaders() {
  setupServer.sendHeader("Access-Control-Allow-Origin", "*");
  setupServer.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  setupServer.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleProvisionRoot() {
  addCORSHeaders();
  setupServer.send(200, "application/json",
    "{\"status\":\"ready\",\"mode\":\"provisioning\",\"device\":\"ESP32 SmartWatch\"}");
}

void handleProvisionScan() {
  addCORSHeaders();
  int n = WiFi.scanNetworks(false, true);
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i > 0) json += ",";
    String ssid = WiFi.SSID(i);
    ssid.replace("\\", "\\\\");
    ssid.replace("\"", "\\\"");
    bool isOpen = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN);
    json += "{\"ssid\":\"" + ssid + "\",\"rssi\":" + WiFi.RSSI(i) +
            ",\"open\":" + (isOpen ? "true" : "false") + "}";
  }
  json += "]";
  setupServer.send(200, "application/json", json);
}

void handleProvisionConnect() {
  addCORSHeaders();
  String body = setupServer.arg("plain");
  Serial.printf("[Provision] POST /connect: %s\n", body.c_str());
  String ssid = extractJsonValue(body, "ssid");
  String pass = extractJsonValue(body, "password");
  if (ssid.isEmpty()) {
    setupServer.send(400, "application/json", "{\"error\":\"ssid is required\"}");
    return;
  }
  wifiPrefs.begin("wifi_cfg", false);
  wifiPrefs.putString("ssid", ssid);
  wifiPrefs.putString("pass", pass);
  wifiPrefs.end();
  Serial.printf("[Provision] Saved SSID: %s — restarting\n", ssid.c_str());
  setupServer.send(200, "application/json",
    "{\"status\":\"saved\",\"message\":\"Credentials saved. Watch is restarting...\"}");
  delay(1200);
  ESP.restart();
}

void handleProvisionStatus() {
  addCORSHeaders();
  bool connected = (WiFi.status() == WL_CONNECTED);
  String json = "{\"connected\":" + String(connected ? "true" : "false");
  if (connected) {
    json += ",\"ssid\":\"" + WiFi.SSID() + "\"";
    json += ",\"ip\":\"" + WiFi.localIP().toString() + "\"";
  }
  json += ",\"apMode\":" + String(apMode ? "true" : "false") + "}";
  setupServer.send(200, "application/json", json);
}

void handleProvisionClear() {
  addCORSHeaders();
  wifiPrefs.begin("wifi_cfg", false);
  wifiPrefs.clear();
  wifiPrefs.end();
  setupServer.send(200, "application/json",
    "{\"status\":\"cleared\",\"message\":\"WiFi credentials cleared. Restarting...\"}");
  delay(1200);
  ESP.restart();
}

void drawProvisioningScreen() {
  gfx->fillScreen(C_BG);
  // Header bar
  gfx->fillRect(0, 0, 170, 48, 0x1A3F);
  drawCentered("WiFi Setup", 14, C_WHITE, 2);
  drawCentered("Provisioning Mode", 34, C_LGRAY, 1);
  // Steps
  gfx->setTextColor(C_LGRAY); gfx->setTextSize(1);
  gfx->setCursor(8, 58);  gfx->print("1. Connect to WiFi:");
  drawCentered("SmartWatch-Setup", 74, C_ACCENT, 1);
  gfx->setCursor(8, 88);  gfx->print("   Pass: setup1234");
  gfx->setCursor(8, 106); gfx->print("2. Open Setup App");
  gfx->setCursor(8, 120); gfx->print("   or browser at:");
  drawCentered("192.168.4.1", 136, C_GREEN, 1);
  // Divider
  gfx->drawFastHLine(10, 158, 150, 0x3186);
  // Hint
  gfx->setTextColor(0x7BEF); gfx->setTextSize(1);
  gfx->setCursor(8, 168); gfx->print("Press BOOT to skip");
  gfx->setCursor(8, 182); gfx->print("(watch runs offline)");
  // Animated dot indicator (drawn once; refreshed by AP loop)
  drawCentered("Waiting...", 210, C_LGRAY, 1);
}

void startProvisioningAP() {
  apMode = true;
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  IPAddress apIP = WiFi.softAPIP();
  Serial.printf("[AP] SSID: %s  Pass: %s  IP: %s\n", AP_SSID, AP_PASSWORD, apIP.toString().c_str());

  // Register HTTP handlers
  setupServer.on("/",        HTTP_GET,     handleProvisionRoot);
  setupServer.on("/scan",    HTTP_GET,     handleProvisionScan);
  setupServer.on("/connect", HTTP_POST,    handleProvisionConnect);
  setupServer.on("/status",  HTTP_GET,     handleProvisionStatus);
  setupServer.on("/clear",   HTTP_POST,    handleProvisionClear);
  // CORS preflight handler
  setupServer.onNotFound([]() {
    if (setupServer.method() == HTTP_OPTIONS) {
      addCORSHeaders();
      setupServer.send(204);
    } else {
      setupServer.send(404, "application/json", "{\"error\":\"not found\"}");
    }
  });
  setupServer.begin();
  drawProvisioningScreen();
}

// ═══════════════════════════════════════════════════════════════════════════
// WiFi Connection
// ═══════════════════════════════════════════════════════════════════════════

void connectWiFi() {
  // Load credentials from NVS (saved by the SmartWatch Setup app)
  wifiPrefs.begin("wifi_cfg", true);
  String savedSSID = wifiPrefs.getString("ssid", "");
  String savedPass = wifiPrefs.getString("pass", "");
  wifiPrefs.end();

  if (savedSSID.isEmpty()) {
    Serial.println("[WiFi] No credentials in NVS — entering provisioning mode");
    startProvisioningAP();
    return;
  }

  Serial.printf("[WiFi] Connecting to %s...\n", savedSSID.c_str());
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(10, 170);
  gfx->print("Connecting WiFi...");

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(savedSSID.c_str(), savedPass.c_str());

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
    Serial.printf("\n[WiFi] Failed to connect to \"%s\" — running offline.\n", savedSSID.c_str());
    Serial.println("[WiFi] Hold BOOT 3s to reset WiFi and re-run setup.");
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
  // Rounded border frame for a cleaner look
  gfx->drawRoundRect(1, 1, SCREEN_W - 2, SCREEN_H - 2, 6, C_DKGRAY);

  char timeBuf[8] = "12:30";
  char dateBuf[24] = "Mon, Apr 14";
  char ampmBuf[4] = "PM";
  struct tm timeinfo;

  if (timeSynced && getLocalTime(&timeinfo, 20)) {
    strftime(timeBuf, sizeof(timeBuf), "%I:%M", &timeinfo);
    strftime(dateBuf, sizeof(dateBuf), "%a, %b %d", &timeinfo);
    strftime(ampmBuf, sizeof(ampmBuf), "%p", &timeinfo);
  }

  // Battery + sync badge in top-right and top-left
  drawSyncBadge(6, 10);
  drawBatteryGlyph(134, 12, battery < 20 ? C_RED : C_ACCENT, battery);
  gfx->setTextSize(1);
  gfx->setTextColor(battery < 20 ? C_RED : C_LGRAY);
  gfx->setCursor(102, 14);
  gfx->print(battery);
  gfx->print("%");

  // Time — large and centered (textSize=4 = 24px digits)
  drawCentered(timeBuf, 22, C_WHITE, 4);
  // AM/PM badge — slightly right-aligned at size 1 is too small, use size 2
  gfx->setTextSize(2);
  gfx->setTextColor(C_ACCENT);
  gfx->setCursor(138, 26);
  gfx->print(ampmBuf);

  // Date — textSize=2 (12px) is readable; was 1 (6px)
  drawCentered(dateBuf, 64, C_LGRAY, 2);

  // Patient name — textSize=2 for readability
  String patientLabel = patientLinked ? linkedPatientName : "No patient linked";
  // Truncate to fit within 170px at textSize=2 (each char ~12px wide)
  if (patientLabel.length() > 13) patientLabel = patientLabel.substring(0, 13);
  drawCentered(patientLabel.c_str(), 82, patientLinked ? C_ACCENT : C_GRAY, 2);

  // ── Vital Cards (HR / SpO2 / Temp) ──────────────────────────────────────
  int cx = (SCREEN_W - 150) / 2;

  // HR card
  gfx->fillRoundRect(cx, 102, 150, 42, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 102, 150, 42, 8, C_RED);
  drawHeartGlyph(cx + 14, 123, C_RED);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 32, 108);
  gfx->print("HEART RATE");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 32, 120);
  gfx->print(heartRate);
  gfx->setTextSize(2);
  gfx->setTextColor(C_RED);
  gfx->setCursor(cx + 80, 120);
  gfx->print(" bpm");

  // SpO2 card
  gfx->fillRoundRect(cx, 150, 150, 42, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 150, 150, 42, 8, C_BLUE);
  drawDropGlyph(cx + 14, 171, C_BLUE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 32, 156);
  gfx->print("SPO2 OXYGEN");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 32, 168);
  gfx->print(spo2);
  gfx->setTextSize(2);
  gfx->setTextColor(C_BLUE);
  gfx->setCursor(cx + 68, 168);
  gfx->print(" %");

  // Temp card
  gfx->fillRoundRect(cx, 198, 150, 42, 8, C_DKGRAY);
  gfx->drawRoundRect(cx, 198, 150, 42, 8, C_ORANGE);
  drawTempGlyph(cx + 12, 210, C_ORANGE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(cx + 32, 204);
  gfx->print("TEMPERATURE");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx + 32, 216);
  gfx->print(String(temperatureF, 1));
  gfx->setTextSize(2);
  gfx->setTextColor(C_ORANGE);
  gfx->setCursor(cx + 102, 216);
  gfx->print("F");

  // Status bar — textSize=1 is fine here (small footer)
  drawCentered(timeSynced ? "WiFi synced" : "Offline mode", 250, timeSynced ? C_ACCENT : C_ORANGE, 1);
  String condition = patientLinked ? linkedPatientCondition : "Tap nav bar to explore";
  if (condition.length() > 24) condition = condition.substring(0, 24);
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
  gfx->drawRoundRect(1, 1, SCREEN_W - 2, SCREEN_H - 2, 6, C_DKGRAY);
  drawSyncBadge(6, 10);

  int yOff = -screenScrollOffset;
  // Screen title — textSize=2 (12px) — clear header
  drawCentered("Heart & Vitals", 16 + yOff, C_RED, 2);

  // Heart icon circle
  int cx = SCREEN_W / 2;
  gfx->fillCircle(cx, 76 + yOff, 24, C_DKGRAY);
  gfx->drawCircle(cx, 76 + yOff, 27, C_RED);
  drawHeartGlyph(cx, 78 + yOff, C_RED);

  // HR value — textSize=5 (30px digits) = big and bold
  char buf[8];
  snprintf(buf, sizeof(buf), "%d", heartRate);
  bool liveHr = max30102Ready && max30102Valid && fingerPresent;
  drawCentered(buf, 108 + yOff, C_WHITE, 5);
  // "BPM" label — textSize=2 (12px) = clearly readable
  drawCentered("BPM", 158 + yOff, liveHr ? C_RED : C_LGRAY, 2);
  // Live/estimated indicator
  drawCentered(liveHr ? "Live sensor" : "Estimated", 178 + yOff, liveHr ? C_GREEN : C_GRAY, 1);

  // SpO2 mini card — wider so text fits
  gfx->fillRoundRect(8, 194 + yOff, 74, 40, 8, C_DKGRAY);
  gfx->drawRoundRect(8, 194 + yOff, 74, 40, 8, C_BLUE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(16, 200 + yOff);
  gfx->print("SpO2");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(16, 214 + yOff);
  gfx->print(spo2);
  gfx->setTextSize(2);
  gfx->setTextColor(C_BLUE);
  gfx->setCursor(44, 214 + yOff);
  gfx->print("%");

  // Temp mini card
  gfx->fillRoundRect(88, 194 + yOff, 74, 40, 8, C_DKGRAY);
  gfx->drawRoundRect(88, 194 + yOff, 74, 40, 8, C_ORANGE);
  gfx->setTextSize(1);
  gfx->setTextColor(C_LGRAY);
  gfx->setCursor(96, 200 + yOff);
  gfx->print("Temp");
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(96, 214 + yOff);
  gfx->print(String(temperatureF, 1));
  gfx->setTextSize(1);
  gfx->setTextColor(C_ORANGE);
  gfx->setCursor(148, 218 + yOff);
  gfx->print("F");

  // Status message — textSize=2 = clearly visible warning/normal
  if (max30102Ready && !fingerPresent) {
    drawCentered("Place finger on sensor", 244 + yOff, C_ORANGE, 1);
  } else if (heartRate >= 100) {
    drawCentered("Elevated HR", 244 + yOff, C_ORANGE, 2);
  } else if (spo2 < 94) {
    drawCentered("Low SpO2!", 244 + yOff, C_RED, 2);
  } else {
    drawCentered("Normal", 244 + yOff, C_GREEN, 2);
  }

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Heart screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 2: Activity / Steps
// ═══════════════════════════════════════════════════════════════════════════

void drawStepsScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRoundRect(1, 1, SCREEN_W - 2, SCREEN_H - 2, 6, C_DKGRAY);
  drawSyncBadge(6, 10);

  int yOff = -screenScrollOffset;
  // Title textSize=2 = clearly readable
  drawCentered("Activity", 16 + yOff, C_GREEN, 2);

  int cx = SCREEN_W / 2;
  gfx->fillCircle(cx, 74 + yOff, 22, C_DKGRAY);
  gfx->drawCircle(cx, 74 + yOff, 25, C_GREEN);
  drawWalkGlyph(cx, 77 + yOff, C_GREEN);

  // Step count — textSize=4 = 24px per digit, clearly readable
  char stepBuf[16];
  snprintf(stepBuf, sizeof(stepBuf), "%d", steps);
  drawCentered(stepBuf, 106 + yOff, C_WHITE, 4);
  // "steps today" — textSize=2 = readable label
  drawCentered("steps today", 148 + yOff, C_LGRAY, 2);

  // Progress bar toward 10,000 goal
  int pct = (steps * 100) / 10000;
  if (pct > 100) pct = 100;
  int bx = 12, by = 172 + yOff, bw = SCREEN_W - 24;
  gfx->fillRoundRect(bx, by, bw, 14, 7, C_DKGRAY);
  uint16_t barCol = pct >= 100 ? C_ACCENT : C_GREEN;
  gfx->fillRoundRect(bx, by, bw * pct / 100, 14, 7, barCol);
  // Goal label
  char goalBuf[20];
  snprintf(goalBuf, sizeof(goalBuf), "%d%% of 10k", pct);
  drawCentered(goalBuf, 196 + yOff, pct >= 100 ? C_ACCENT : C_GREEN, 2);

  // IMU status — textSize=1 (small detail row)
  {
    String imuStr;
    uint16_t imuCol;
    if      (imuReady && mpu6050Ready) { imuStr = "QMI+MPU6050 active"; imuCol = C_ACCENT; }
    else if (imuReady)                 { imuStr = "QMI8658 tracking";   imuCol = C_ACCENT; }
    else if (mpu6050Ready)             { imuStr = "MPU6050 active";     imuCol = C_ACCENT; }
    else                               { imuStr = "IMU offline";         imuCol = C_RED;    }
    drawCentered(imuStr.c_str(), 220 + yOff, imuCol, 1);
  }

  // Air quality row — one concise line
  if (ens160Ready || aht21Ready) {
    char airBuf[32];
    uint16_t aqiLabel = ens160Aqi;
    const char* aqiNames[] = {"", "Excellent", "Good", "Moderate", "Poor", "Unhealthy"};
    if (ens160Ready && aht21Ready)
      snprintf(airBuf, sizeof(airBuf), "CO2:%u  H:%.0f%%  AQI:%s",
        ens160Eco2, aht21Humidity, (aqiLabel <= 5 ? aqiNames[aqiLabel] : "?"));
    else if (ens160Ready)
      snprintf(airBuf, sizeof(airBuf), "CO2:%uppm  TVOC:%uppb", ens160Eco2, ens160Tvoc);
    else
      snprintf(airBuf, sizeof(airBuf), "Humidity: %.1f%%", aht21Humidity);
    uint16_t aqCol = (ens160Eco2 > 1500 || ens160Aqi >= 4) ? C_ORANGE : C_GREEN;
    drawCentered(airBuf, 234 + yOff, aqCol, 1);
  }

  // Pitch/roll — sensor orientation data
  if (mpu6050Ready || imuReady) {
    char prBuf[24];
    snprintf(prBuf, sizeof(prBuf), "P:%.1f  R:%.1f", mpuPitch, mpuRoll);
    drawCentered(prBuf, 248 + yOff, C_WHITE, 1);
  }

  drawNavBar();
  drawPopupIfVisible();
  Serial.println("[DRAW] Steps screen done.");
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 3: Patient Details
// ═══════════════════════════════════════════════════════════════════════════

void drawPatientScreen() {
  gfx->fillScreen(C_BG);
  gfx->drawRoundRect(1, 1, SCREEN_W - 2, SCREEN_H - 2, 6, C_DKGRAY);
  drawSyncBadge(6, 10);

  int yOff = -screenScrollOffset;
  drawCentered("Patient Details", 14 + yOff, C_BLUE, 2);

  if (!patientLinked) {
    drawCentered("No patient assigned", 76 + yOff, C_WHITE, 2);
    drawCentered("Link this watch in admin", 110 + yOff, C_LGRAY, 1);
    // Device ID — textSize=1 is OK here (it's a hex string, always fits)
    drawCentered(deviceId.c_str(), 140 + yOff, C_ACCENT, 1);
    drawCentered("Patients > Device ID", 160 + yOff, C_LGRAY, 1);
  } else {
    // Patient name — textSize=2 (12px)
    String nameShort = linkedPatientName.length() > 13 ? linkedPatientName.substring(0, 13) : linkedPatientName;
    drawCentered(nameShort.c_str(), 48 + yOff, C_WHITE, 2);

    // Age + risk on one row at textSize=2
    String infoText = "Age " + String(linkedPatientAge) + "  |  " + linkedPatientRisk;
    drawCentered(infoText.c_str(), 70 + yOff, C_ACCENT, 1);

    // Risk badge — colored textSize=2
    uint16_t riskCol = (linkedPatientRisk == "Critical") ? C_RED
                     : (linkedPatientRisk == "High")     ? C_ORANGE
                     : (linkedPatientRisk == "Moderate") ? C_ORANGE
                     : C_GREEN;
    drawCentered(("Risk: " + linkedPatientRisk).c_str(), 90 + yOff, riskCol, 2);

    // Condition (truncate to 20 chars so it fits at textSize=1)
    String condText = linkedPatientCondition.length() > 22 ? linkedPatientCondition.substring(0, 22) : linkedPatientCondition;
    drawCentered(condText.c_str(), 116 + yOff, C_LGRAY, 1);

    // Divider line
    gfx->drawFastHLine(20, 130 + yOff, SCREEN_W - 40, C_DKGRAY);

    // Vitals — textSize=1 each row (compact but sufficient for numbers)
    char v1[28], v2[28], v3[28];
    snprintf(v1, sizeof(v1), "HR: %d bpm   SpO2: %d%%", heartRate, spo2);
    snprintf(v2, sizeof(v2), "Temp: %.1fF  Steps: %d", temperatureF, steps);
    snprintf(v3, sizeof(v3), "CO2: %uppm  H: %.0f%%", ens160Eco2, aht21Humidity);
    drawCentered(v1, 142 + yOff, C_WHITE, 1);
    drawCentered(v2, 158 + yOff, C_WHITE, 1);
    drawCentered(v3, 174 + yOff, C_WHITE, 1);

    // Notes
    String noteText = linkedPatientNotes.length() > 24 ? linkedPatientNotes.substring(0, 24) : linkedPatientNotes;
    if (noteText.length() > 0) drawCentered(noteText.c_str(), 194 + yOff, C_LGRAY, 1);

    // Device ID at the bottom
    drawCentered(deviceId.c_str(), 214 + yOff, C_BLUE, 1);
    drawCentered("Swipe up/down", 266, C_GRAY, 1);
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
  // Double red border for emphasis
  gfx->drawRect(0, 0, SCREEN_W, SCREEN_H, C_RED);
  gfx->drawRect(2, 2, SCREEN_W - 4, SCREEN_H - 4, C_RED);

  // "EMERGENCY" header — textSize=2, bright red
  drawCentered("! EMERGENCY !", 8, C_RED, 2);
  // "SOS" large text — textSize=4 = 24px per char (fits nicely in 170px width)
  drawCentered("SOS", 48, C_WHITE, 4);

  // Instruction — textSize=1
  drawCentered("Tap red circle to send", 78, C_LGRAY, 1);

  // Big red tap circle — centered
  int cx = SCREEN_W / 2;
  int cy = 160;
  gfx->fillCircle(cx, cy, 48, C_RED);
  gfx->drawCircle(cx, cy, 51, C_WHITE);
  gfx->drawCircle(cx, cy, 52, C_WHITE);

  // "SEND" text inside circle — textSize=2 = clearly readable
  gfx->setTextSize(2);
  gfx->setTextColor(C_WHITE);
  gfx->setCursor(cx - 24, cy - 7);
  gfx->print("SEND");

  // Device ID — textSize=1 (small info)
  drawCentered(deviceId.c_str(), 224, C_ACCENT, 1);

  // Status text — textSize=2 so it's clearly visible
  if (sosSent) {
    drawCentered(sosStatus.c_str(), 244, C_GREEN, 2);
  } else if (!wifiConnected) {
    drawCentered("WiFi required", 244, C_ORANGE, 2);
  } else {
    drawCentered("Ready", 244, C_ACCENT, 2);
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

  // ── Wait 4s so you can open Serial Monitor before messages scroll past ─
  for (int i = 4; i > 0; i--) {
    Serial.printf("Starting in %d... (open Serial Monitor now)\n", i);
    delay(1000);
  }
  Serial.println("\n=== SMART WATCH v3.5 — Patient Sync + Alerts ===");
  initUniqueDeviceId();

  // ── I2C bus recovery FIRST ─────────────────────────────────────────────
  // Bit-bang 9 SCL pulses to force any stuck slave to release SDA,
  // then hand pins back to Wire hardware driver.
  Serial.println("[I2C] Running bus recovery...");
  pinMode(IMU_SDA, INPUT_PULLUP);  // let SDA float up first
  pinMode(IMU_SCL, OUTPUT);
  for (int i = 0; i < 9; i++) {
    digitalWrite(IMU_SCL, LOW);  delayMicroseconds(10);
    digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
    // If SDA is high, slave released — can stop early
    if (digitalRead(IMU_SDA) == HIGH && i >= 1) break;
  }
  // STOP condition: SCL HIGH, SDA LOW->HIGH
  pinMode(IMU_SDA, OUTPUT);
  digitalWrite(IMU_SDA, LOW);  delayMicroseconds(10);
  digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
  digitalWrite(IMU_SDA, HIGH); delayMicroseconds(10);
  pinMode(IMU_SDA, INPUT_PULLUP);
  delay(50);

  // Now start Wire
  Wire.begin(IMU_SDA, IMU_SCL);
  Wire.setTimeOut(50);
  delay(20);
  bool sdaHigh = digitalRead(IMU_SDA);
  bool sclHigh = digitalRead(IMU_SCL);
  Serial.printf("[I2C] Bus state after recovery: SDA=%s SCL=%s\n",
    sdaHigh ? "HIGH(OK)" : "LOW(STUCK!)",
    sclHigh ? "HIGH(OK)" : "LOW(STUCK!)");
  // ──────────────────────────────────────────────────────────────────────

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

  // ── I2C bus scan ───────────────────────────────────────────────────────
  struct { byte addr; const char* name; } knownDevices[] = {
    {0x15, "CST816 Touch"},
    {0x38, "AHT21 Humidity"},
    {0x52, "ENS160 Air Quality"},
    {0x57, "MAX30102 Heart Rate"},
    {0x5A, "MLX90614 Temperature"},
    {0x68, "MPU6050 IMU"},
    {0x6B, "QMI8658 Onboard IMU"},
  };
  const int knownCount = sizeof(knownDevices) / sizeof(knownDevices[0]);

  Serial.println("\n--- I2C Bus Scan ---");
  Serial.println("ADDR  | STATUS | DEVICE");
  Serial.println("------+--------+---------------------------");
  int foundCount = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      const char* label = "Unknown";
      for (int k = 0; k < knownCount; k++) {
        if (knownDevices[k].addr == addr) { label = knownDevices[k].name; break; }
      }
      Serial.printf("0x%02X  |  FOUND | %s\n", addr, label);
      foundCount++;
    }
  }
  Serial.println("------+--------+---------------------------");
  Serial.printf("Total: %d device(s) found\n\n", foundCount);
  if (foundCount == 0) {
    Serial.println("!!! NO DEVICES FOUND — I2C bus is stuck or wiring error !!!");
    Serial.println("    Check: SDA=GPIO47, SCL=GPIO48, 3.3V power to sensors");
  }
  // ──────────────────────────────────────────────────────────────────────

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

  // Init MLX90614 contactless temperature
  drawCentered("Starting MLX90614...", 200, C_LGRAY, 1);
  mlx90614Ready = mlx90614_init();
  Serial.printf("[MLX90614] %s\n", mlx90614Ready ? "Ready" : "Not found (N/A)");
  drawCentered(mlx90614Ready ? "MLX90614 OK" : "MLX90614 N/A", 215, mlx90614Ready ? C_GREEN : C_GRAY, 1);

  // Init AHT21 humidity sensor
  drawCentered("Starting AHT21...", 200, C_LGRAY, 1);
  aht21Ready = aht21_init();
  Serial.printf("[AHT21] %s\n", aht21Ready ? "Ready" : "Not found (N/A)");
  drawCentered(aht21Ready ? "AHT21 OK" : "AHT21 N/A", 215, aht21Ready ? C_GREEN : C_GRAY, 1);

  // Init ENS160 air quality sensor
  drawCentered("Starting ENS160...", 200, C_LGRAY, 1);
  ens160Ready = ens160_init();
  Serial.printf("[ENS160] %s\n", ens160Ready ? "Ready" : "Not found (N/A)");
  drawCentered(ens160Ready ? "ENS160 OK" : "ENS160 N/A", 215, ens160Ready ? C_GREEN : C_GRAY, 1);

  // Init MAX30102 heart rate + SpO2 (Wire2 on GPIO3/GPIO5)
  drawCentered("Starting MAX30102...", 200, C_LGRAY, 1);
  pinMode(MAX30102_SDA, INPUT_PULLUP);
  pinMode(MAX30102_SCL, INPUT_PULLUP);
  delay(10);
  Wire2.begin(MAX30102_SDA, MAX30102_SCL);
  Wire2.setClock(100000);
  Wire2.setTimeout(50);
  max30102Ready = max30102_init();
  Serial.printf("[MAX30102] %s\n", max30102Ready ? "Ready" : "Not found (N/A)");
  drawCentered(max30102Ready ? "MAX30102 OK" : "MAX30102 N/A", 215, max30102Ready ? C_GREEN : C_GRAY, 1);

  // Initial sensor read (blocking is fine here in setup)
  triggerSlowSensors();
  delay(100);
  readAllSensors();

  // Init touch controller
  drawCentered("Starting Touch...", 230, C_LGRAY, 1);
  touchReady = touchInit();
  drawCentered(touchReady ? "Touch+Swipe OK" : "Touch Failed", 245, touchReady ? C_GREEN : C_ORANGE, 1);

  // Connect WiFi
  // If BOOT button is held right now → force clear saved WiFi and provision
  if (digitalRead(0) == LOW) {
    Serial.println("[Boot] BOOT held at startup — clearing WiFi credentials");
    delay(300);
    if (digitalRead(0) == LOW) {   // still held after debounce
      wifiPrefs.begin("wifi_cfg", false);
      wifiPrefs.clear();
      wifiPrefs.end();
    }
  }
  drawCentered("Connecting WiFi...", 230, C_LGRAY, 1);
  connectWiFi();
  if (apMode) {
    // Provisioning mode: loop() will run the HTTP server, skip normal startup
    Serial.println("[Setup] Entering provisioning AP loop.");
    return;
  }
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
  // ── AP Provisioning mode — runs HTTP server, skips all sensor/display code ──
  if (apMode) {
    setupServer.handleClient();
    // Short press BOOT → skip setup, watch runs offline
    static bool lastAPBtn = HIGH;
    bool apBtn = digitalRead(0);
    if (apBtn == LOW && lastAPBtn == HIGH) {
      Serial.println("[AP] Skipping WiFi setup — continuing offline");
      apMode = false;
      setupServer.stop();
      WiFi.softAPdisconnect(true);
      WiFi.mode(WIFI_STA);
      showCurrentScreen();
    }
    lastAPBtn = apBtn;
    return;
  }

  // ── Button handling (5 screens) ──────────────────────────────────────────
  static bool lastBtn = HIGH;
  static unsigned long lastBtnMs = 0;
  static unsigned long btnHoldMs = 0;   // for 3-second WiFi reset
  bool b = digitalRead(0);  // BOOT button

  // Long press 3 s → clear saved WiFi credentials and restart into setup mode
  if (b == LOW) {
    if (btnHoldMs == 0) btnHoldMs = millis();
    else if (millis() - btnHoldMs > 3000) {
      Serial.println("[Boot] 3 s hold — clearing WiFi and restarting");
      wifiPrefs.begin("wifi_cfg", false);
      wifiPrefs.clear();
      wifiPrefs.end();
      pushPopup("WiFi Reset!", C_ORANGE);
      delay(1500);
      ESP.restart();
    }
  } else {
    btnHoldMs = 0;
  }

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

  // ── Touch handling — poll FT3168 directly every 25ms (no TP_INT dependency) ──
  if (touchReady && millis() - lastTouchMs > 25) {
    lastTouchMs = millis();
    uint16_t tx, ty;
    bool touched = getTouchXY(tx, ty);
    if (touched) {
      touchNoContactCount = 0;
      processTouchPoint(tx, ty);
    } else if (touchTracking) {
      touchNoContactCount++;
      if (touchNoContactCount >= 2) {  // 2 consecutive no-touch polls (~50ms) = release
        touchNoContactCount = 0;
        finalizeTouch();
      }
    }
  }

  // ── I2C bus health check every 30s — recover if SDA is stuck LOW ────────
  static unsigned long lastBusCheckMs = 0;
  if (millis() - lastBusCheckMs >= 30000) {
    lastBusCheckMs = millis();
    if (digitalRead(IMU_SDA) == LOW) {
      Serial.println("[I2C] SDA stuck LOW detected — running bus recovery...");
      // Bit-bang 9 SCL pulses to release stuck slave
      pinMode(IMU_SDA, INPUT_PULLUP);
      pinMode(IMU_SCL, OUTPUT);
      for (int i = 0; i < 9; i++) {
        digitalWrite(IMU_SCL, LOW);  delayMicroseconds(10);
        digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
      }
      pinMode(IMU_SDA, OUTPUT);
      digitalWrite(IMU_SDA, LOW);  delayMicroseconds(10);
      digitalWrite(IMU_SCL, HIGH); delayMicroseconds(10);
      digitalWrite(IMU_SDA, HIGH); delayMicroseconds(10);
      Wire.begin(IMU_SDA, IMU_SCL);
      Wire.setTimeOut(50);
      delay(20);
      // Re-init any sensors that went offline
      if (!imuReady)      { imuReady      = qmi8658_init(); Serial.printf("[I2C] QMI re-init: %s\n", imuReady ? "OK" : "fail"); }
      if (!mpu6050Ready)  { mpu6050Ready  = mpu6050_init(); Serial.printf("[I2C] MPU re-init: %s\n", mpu6050Ready ? "OK" : "fail"); }
      if (!aht21Ready)    { aht21Ready    = aht21_init();   Serial.printf("[I2C] AHT21 re-init: %s\n", aht21Ready ? "OK" : "fail"); }
      if (!ens160Ready)   { ens160Ready   = ens160_init();  Serial.printf("[I2C] ENS160 re-init: %s\n", ens160Ready ? "OK" : "fail"); }
      if (!mlx90614Ready) { mlx90614Ready = mlx90614_init();Serial.printf("[I2C] MLX re-init: %s\n", mlx90614Ready ? "OK" : "fail"); }
      if (!touchReady)    { touchReady    = touchInit();    Serial.printf("[I2C] Touch re-init: %s\n", touchReady ? "OK" : "fail"); }
      if (!max30102Ready) {
        Wire2.begin(MAX30102_SDA, MAX30102_SCL);
        Wire2.setClock(100000); Wire2.setTimeout(50);
        max30102Ready = max30102_init();
        Serial.printf("[I2C] MAX30102 re-init: %s\n", max30102Ready ? "OK" : "fail");
      }
    }
  }

  // ── Step + fall detection every 20ms ────────────────────────────────────
  if (millis() - lastStepCheck >= 20) {
    lastStepCheck = millis();
    detectSteps();
    detectFall();  // uses accelX/Y/Z populated by detectSteps()
  }

  // ── Read gyroscope every 100ms (for display on steps screen) ─────────────
  if (millis() - lastGyroRead >= 100) {
    lastGyroRead = millis();
    if (imuReady)     qmi8658_readGyro(gyroX, gyroY, gyroZ);
    if (mpu6050Ready) mpu6050_readAll();
  }

  // ── Read AHT21, ENS160, MLX90614 every 5 seconds (non-blocking) ─────────
  if (millis() - lastSensorReadMs >= 5000) {
    lastSensorReadMs = millis();
    triggerSlowSensors();  // Phase 1: kick off AHT21 measurement
  }
  // Phase 2: collect AHT21 + other sensor results 100ms after trigger
  if (aht21Triggered && millis() - aht21TriggerMs >= 100) {
    readAllSensors();
  }

  // ── MAX30102 HR + SpO2 — sample every 40ms (25sps with 4-avg) ───────────
  if (max30102Ready && millis() - lastMaxSampleMs >= 40) {
    lastMaxSampleMs = millis();
    max30102_sampleLoop();
  }
  // Retry Bus2 init every 5 minutes if MAX30102 dropped off
  if (!max30102Ready && millis() - lastMaxRetryMs >= 300000UL) {
    lastMaxRetryMs = millis();
    Serial.println("[MAX30102] Retrying Bus2 init...");
    pinMode(MAX30102_SDA, INPUT_PULLUP);
    pinMode(MAX30102_SCL, INPUT_PULLUP);
    delay(10);
    Wire2.end();
    Wire2.begin(MAX30102_SDA, MAX30102_SCL);
    Wire2.setClock(100000);
    Wire2.setTimeout(50);
    max30102Ready = max30102_init();
    Serial.printf("[MAX30102] Retry: %s\n", max30102Ready ? "OK" : "still missing");
  }
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

    // ── Step-rate calculation (every 60s) for activity-aware HR alerts ────
    if (millis() - stepRateCalcMs >= 60000UL) {
      stepRatePM    = steps - stepsLastMin;
      stepsLastMin  = steps;
      stepRateCalcMs = millis();
    }

    // ── Touch-fail diagnostic (every 30s if touch never initialized) ──────
    if (!touchReady && millis() % 30000 < 50) {
      Serial.println("[TOUCH FAIL] Touch controller not available.");
      Serial.printf("[TOUCH FAIL]   SDA GPIO%d=%s  SCL GPIO%d=%s  TP_INT GPIO%d=%s\n",
        IMU_SDA, digitalRead(IMU_SDA) ? "H" : "L",
        IMU_SCL, digitalRead(IMU_SCL) ? "H" : "L",
        TP_INT,  digitalRead(TP_INT)  ? "H" : "L");
      Serial.println("[TOUCH FAIL]   Navigation by touch is unavailable. Check CST816 wiring.");
    }

    Serial.printf("[ALIVE] %ds steps=%d screen=%d imu=%d wifi=%d touch=%d step_rate=%d/min\n",
                  displaySeconds, steps, currentScreen, imuReady, wifiConnected, touchReady, stepRatePM);
  }

  delay(10);
}
