// ============================================================================
// Sensor Test — Read MAX30102, MLX90614, MPU6050 and display on LCD
//
// Upload this AFTER running I2C_Scanner and confirming all 3 sensors found.
// ============================================================================

#include <Arduino.h>
#include <Wire.h>
#include <Arduino_GFX_Library.h>

// Sensor libraries
#include <MAX30105.h>           // SparkFun MAX3010x library
#include <heartRate.h>          // SparkFun heart rate algorithm
#include <Adafruit_MLX90614.h>  // Adafruit MLX90614
#include <Adafruit_MPU6050.h>   // Adafruit MPU6050
#include <Adafruit_Sensor.h>    // Unified sensor

// ─── Pin mapping (same as ESP32_SmartWatch) ────────────────────────────────
#define TFT_MOSI  13
#define TFT_SCLK  10
#define TFT_DC    11
#define TFT_CS    12
#define TFT_RST    9
#define TFT_BL    14
#define I2C_SDA   47
#define I2C_SCL   48
#define SCREEN_W  170
#define SCREEN_H  320

// ─── Display setup (HWSPI — proven working) ───────────────────────────────
Arduino_DataBus *bus = new Arduino_HWSPI(TFT_DC, TFT_CS, TFT_SCLK, TFT_MOSI);
Arduino_GFX *gfx = new Arduino_ST7789(bus, TFT_RST, 0, false, SCREEN_W, SCREEN_H, 35, 0, 35, 0);

// ─── Colors ────────────────────────────────────────────────────────────────
#define C_BG      0x0000
#define C_WHITE   0xFFFF
#define C_GRAY    0x4208
#define C_RED     0xF800
#define C_GREEN   0x07E0
#define C_ORANGE  0xFD20
#define C_CYAN    0x07FF
#define C_YELLOW  0xFFE0

// ─── Sensor objects ────────────────────────────────────────────────────────
MAX30105 max30102;
Adafruit_MLX90614 mlx;
Adafruit_MPU6050 mpu;

// ─── Sensor status flags ───────────────────────────────────────────────────
bool hasMAX30102 = false;
bool hasMLX90614 = false;
bool hasMPU6050  = false;

// ─── Heart rate variables (SparkFun algorithm) ─────────────────────────────
#define HR_SAMPLES 4
byte hrRates[HR_SAMPLES];
byte hrRateSpot = 0;
long lastHRBeat = 0;
float hrBPM = 0;
int hrAvgBPM = 0;

// ─── SpO2 variables (simple ratio method) ──────────────────────────────────
float spo2Value = 0;

// ─── Step counter variables (pedometer) ────────────────────────────────────
int stepCount = 0;
float lastMag = 0;
bool stepPeak = false;
float stepThreshold = 1.3;  // g-force threshold for step detection
unsigned long lastStepTime = 0;

// ─── Temperature ───────────────────────────────────────────────────────────
float bodyTemp = 0;

// ─── LCD update timer ──────────────────────────────────────────────────────
unsigned long lastLCDUpdate = 0;
#define LCD_UPDATE_MS 500  // Refresh LCD every 500ms

// ─── Helper: draw centered text ────────────────────────────────────────────
void drawCentered(const char* text, int y, uint16_t color, uint8_t sz) {
  gfx->setTextSize(sz);
  gfx->setTextColor(color);
  int16_t x1, y1;
  uint16_t w, h;
  gfx->getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  gfx->setCursor((SCREEN_W - w) / 2, y);
  gfx->print(text);
}

// ─── Helper: draw a sensor row on LCD ──────────────────────────────────────
void drawSensorRow(int y, const char* label, const char* value, const char* unit, uint16_t color, bool ok) {
  gfx->fillRect(0, y, SCREEN_W, 36, C_BG);  // Clear row
  
  gfx->setTextSize(1);
  gfx->setTextColor(ok ? color : C_GRAY);
  gfx->setCursor(8, y + 2);
  gfx->print(label);

  gfx->setTextSize(2);
  gfx->setTextColor(ok ? C_WHITE : C_GRAY);
  gfx->setCursor(8, y + 14);
  gfx->print(value);

  gfx->setTextSize(1);
  gfx->setTextColor(ok ? color : C_GRAY);
  int16_t x1, y1;
  uint16_t tw, th;
  gfx->getTextBounds(value, 0, 0, &x1, &y1, &tw, &th);
  // approximate: textSize 2 chars are ~12px wide
  gfx->setCursor(8 + strlen(value) * 12 + 4, y + 20);
  gfx->print(unit);
}

// ════════════════════════════════════════════════════════════════════════════
// SETUP
// ════════════════════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== SENSOR TEST — MAX30102 + MLX90614 + MPU6050 ===");

  // --- Init I2C ---
  Wire.begin(I2C_SDA, I2C_SCL);
  Serial.printf("I2C: SDA=%d SCL=%d\n", I2C_SDA, I2C_SCL);

  // --- Init Display ---
  if (!gfx->begin()) {
    Serial.println("Display init FAILED!");
  }
  gfx->fillScreen(C_BG);
  gfx->invertDisplay(true);
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, LOW);

  drawCentered("Sensor Test", 10, C_CYAN, 2);
  drawCentered("Initializing...", 40, C_GRAY, 1);

  // --- Init MAX30102 ---
  Serial.print("MAX30102... ");
  if (max30102.begin(Wire, I2C_SPEED_FAST, 0x57)) {
    hasMAX30102 = true;
    max30102.setup();                    // Default settings
    max30102.setPulseAmplitudeRed(0x0A); // Low for proximity detection
    max30102.setPulseAmplitudeGreen(0);  // Turn off green LED
    Serial.println("OK");
  } else {
    Serial.println("NOT FOUND");
  }

  // --- Init MLX90614 ---
  Serial.print("MLX90614... ");
  if (mlx.begin(0x5A, &Wire)) {
    hasMLX90614 = true;
    Serial.println("OK");
  } else {
    Serial.println("NOT FOUND");
  }

  // --- Init MPU6050 ---
  Serial.print("MPU6050... ");
  if (mpu.begin(0x68, &Wire)) {
    hasMPU6050 = true;
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    Serial.println("OK");
  } else {
    Serial.println("NOT FOUND");
  }

  // --- Draw initial LCD layout ---
  gfx->fillScreen(C_BG);
  drawCentered("SENSOR TEST", 5, C_CYAN, 2);
  gfx->drawFastHLine(0, 25, SCREEN_W, C_CYAN);

  // Status line
  char statusBuf[40];
  snprintf(statusBuf, sizeof(statusBuf), "HR:%s TMP:%s STP:%s",
           hasMAX30102 ? "OK" : "--",
           hasMLX90614 ? "OK" : "--",
           hasMPU6050  ? "OK" : "--");
  drawCentered(statusBuf, 28, C_GREEN, 1);

  Serial.println("\nSensor init complete. Starting readings...\n");
}

// ════════════════════════════════════════════════════════════════════════════
// LOOP
// ════════════════════════════════════════════════════════════════════════════
void loop() {

  // ─── Read MAX30102 (heart rate + SpO2) ─────────────────────────────────
  if (hasMAX30102) {
    long irValue = max30102.getIR();

    if (irValue > 50000) {  // Finger is on the sensor
      if (checkForBeat(irValue)) {
        long delta = millis() - lastHRBeat;
        lastHRBeat = millis();

        hrBPM = 60.0 / (delta / 1000.0);

        if (hrBPM > 20 && hrBPM < 255) {
          hrRates[hrRateSpot++ % HR_SAMPLES] = (byte)hrBPM;

          // Average
          int total = 0;
          for (byte i = 0; i < HR_SAMPLES; i++) total += hrRates[i];
          hrAvgBPM = total / HR_SAMPLES;
        }
      }

      // Simple SpO2 estimation from red/IR ratio
      long redValue = max30102.getRed();
      if (redValue > 0 && irValue > 0) {
        float ratio = (float)redValue / (float)irValue;
        // Simplified SpO2 formula (approximate, not medical-grade)
        spo2Value = constrain(110.0 - 25.0 * ratio, 70, 100);
      }
    } else {
      hrAvgBPM = 0;  // No finger detected
      spo2Value = 0;
    }
  }

  // ─── Read MLX90614 (body temperature) ──────────────────────────────────
  if (hasMLX90614) {
    bodyTemp = mlx.readObjectTempC();
    // Filter out obviously wrong readings
    if (bodyTemp < 15.0 || bodyTemp > 50.0) {
      bodyTemp = 0;
    }
  }

  // ─── Read MPU6050 (step counter) ───────────────────────────────────────
  if (hasMPU6050) {
    sensors_event_t a, g, temp;
    mpu.getEvent(&a, &g, &temp);

    // Calculate acceleration magnitude in g
    float mag = sqrt(a.acceleration.x * a.acceleration.x +
                     a.acceleration.y * a.acceleration.y +
                     a.acceleration.z * a.acceleration.z) / 9.81;

    // Simple peak detection pedometer
    unsigned long now = millis();
    if (mag > stepThreshold && !stepPeak && (now - lastStepTime > 300)) {
      stepPeak = true;
      stepCount++;
      lastStepTime = now;
    }
    if (mag < stepThreshold - 0.2) {
      stepPeak = false;
    }
    lastMag = mag;
  }

  // ─── Update LCD (throttled) ────────────────────────────────────────────
  if (millis() - lastLCDUpdate >= LCD_UPDATE_MS) {
    lastLCDUpdate = millis();

    char buf[32];

    // Heart Rate row (y=45)
    if (hasMAX30102 && hrAvgBPM > 0) {
      snprintf(buf, sizeof(buf), "%d", hrAvgBPM);
      drawSensorRow(45, "HEART RATE", buf, "bpm", C_RED, true);
    } else {
      drawSensorRow(45, "HEART RATE", hasMAX30102 ? "---" : "N/A", "bpm", C_RED, hasMAX30102);
    }

    // SpO2 row (y=90)
    if (hasMAX30102 && spo2Value > 0) {
      snprintf(buf, sizeof(buf), "%.0f%%", spo2Value);
      drawSensorRow(90, "SpO2", buf, "", C_CYAN, true);
    } else {
      drawSensorRow(90, "SpO2", hasMAX30102 ? "---" : "N/A", "", C_CYAN, hasMAX30102);
    }

    // Temperature row (y=135)
    if (hasMLX90614 && bodyTemp > 0) {
      char tempStr[16];
      dtostrf(bodyTemp, 4, 1, tempStr);
      drawSensorRow(135, "BODY TEMP", tempStr, "C", C_ORANGE, true);
    } else {
      drawSensorRow(135, "BODY TEMP", hasMLX90614 ? "---" : "N/A", "C", C_ORANGE, hasMLX90614);
    }

    // Steps row (y=180)
    if (hasMPU6050) {
      snprintf(buf, sizeof(buf), "%d", stepCount);
      drawSensorRow(180, "STEPS", buf, "steps", C_GREEN, true);
    } else {
      drawSensorRow(180, "STEPS", "N/A", "steps", C_GREEN, false);
    }

    // Accel magnitude (y=225) — useful for debugging step detection
    if (hasMPU6050) {
      char magStr[16];
      dtostrf(lastMag, 4, 2, magStr);
      drawSensorRow(225, "ACCEL MAG", magStr, "g", C_YELLOW, true);
    }

    // Divider
    gfx->drawFastHLine(0, 265, SCREEN_W, C_CYAN);

    // Uptime
    gfx->fillRect(0, 270, SCREEN_W, 20, C_BG);
    char uptimeBuf[32];
    unsigned long sec = millis() / 1000;
    snprintf(uptimeBuf, sizeof(uptimeBuf), "Uptime: %lum %lus", sec / 60, sec % 60);
    drawCentered(uptimeBuf, 275, C_GRAY, 1);

    // Serial output
    Serial.printf("HR=%d bpm  SpO2=%.0f%%  Temp=%.1fC  Steps=%d  Mag=%.2fg\n",
                  hrAvgBPM, spo2Value, bodyTemp, stepCount, lastMag);
  }

  delay(10);  // Small delay for stability
}
