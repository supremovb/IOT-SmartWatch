// ============================================================================
// Dual I2C Bus Test
// Bus 1 (GPIO47/48): All existing sensors — MPU6050, AHT21, ENS160, QMI8658
// Bus 2 (GPIO1/GPIO2): MAX30102 only — isolated so it can't affect other sensors
//
// MAX30102 wiring for this test:
//   VIN  → breadboard + rail  (unchanged)
//   GND  → breadboard - rail  (unchanged)
//   SCL  → Row 15 + ESP32 GPIO2
//   SDA  → Row 16 + ESP32 GPIO1
// ============================================================================
#include <Wire.h>

// Main I2C bus — all existing sensors
#define I2C_SDA   47
#define I2C_SCL   48

// Second I2C bus — MAX30102 only
#define I2C2_SDA   1
#define I2C2_SCL   2

#define MAX30102_ADDR  0x57
#define REG_PART_ID    0xFF  // Should return 0x15

TwoWire Wire2 = TwoWire(1);  // Second I2C instance

struct KnownDevice {
  byte addr;
  const char* name;
};

KnownDevice mainBus[] = {
  {0x38, "AHT21 (Humidity/Temperature)"},
  {0x52, "ENS160 (CO2/TVOC Air Quality)"},
  {0x68, "MPU6050 (Accelerometer/Steps)"},
  {0x6B, "QMI8658 (Onboard IMU)"},
};
const int mainCount = sizeof(mainBus) / sizeof(mainBus[0]);

void i2cBusRecover(int sda, int scl) {
  pinMode(sda, OUTPUT); digitalWrite(sda, HIGH);
  pinMode(scl, OUTPUT); digitalWrite(scl, HIGH);
  for (int i = 0; i < 9; i++) {
    digitalWrite(scl, LOW);  delayMicroseconds(5);
    digitalWrite(scl, HIGH); delayMicroseconds(5);
  }
  digitalWrite(sda, LOW);  delayMicroseconds(5);
  digitalWrite(scl, HIGH); delayMicroseconds(5);
  digitalWrite(sda, HIGH); delayMicroseconds(5);
}

uint8_t readRegister(TwoWire &bus, uint8_t addr, uint8_t reg) {
  bus.beginTransmission(addr);
  bus.write(reg);
  bus.endTransmission(false);
  bus.requestFrom(addr, (uint8_t)1);
  if (bus.available()) return bus.read();
  return 0xFF;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  i2cBusRecover(I2C_SDA, I2C_SCL);
  i2cBusRecover(I2C2_SDA, I2C2_SCL);

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire2.begin(I2C2_SDA, I2C2_SCL);

  Serial.println("\n============================================");
  Serial.println("  Dual I2C Bus Test");
  Serial.printf("  Bus 1: SDA=GPIO%d  SCL=GPIO%d\n", I2C_SDA, I2C_SCL);
  Serial.printf("  Bus 2: SDA=GPIO%d   SCL=GPIO%d\n", I2C2_SDA, I2C2_SCL);
  Serial.println("============================================\n");
}

void loop() {
  // --- Scan Bus 1 ---
  Serial.println("=== BUS 1 (GPIO47/48) — Existing Sensors ===");
  Serial.println("ADDR  | STATUS | DEVICE");
  Serial.println("------+--------+---------------------------");
  for (int i = 0; i < mainCount; i++) {
    Wire.beginTransmission(mainBus[i].addr);
    byte err = Wire.endTransmission();
    Serial.printf("0x%02X  |  %s | %s\n",
                  mainBus[i].addr,
                  err == 0 ? " FOUND" : "MISSING",
                  mainBus[i].name);
  }

  // --- Test Bus 2 (MAX30102) ---
  Serial.println("\n=== BUS 2 (GPIO1/GPIO2) — MAX30102 ===");
  Wire2.beginTransmission(MAX30102_ADDR);
  byte err = Wire2.endTransmission();

  if (err != 0) {
    Serial.println("0x57  |  MISSING | MAX30102 (Heart Rate/SpO2)");
    Serial.println("  → Check SCL→Row15→GPIO2 and SDA→Row16→GPIO1");
  } else {
    uint8_t partID = readRegister(Wire2, MAX30102_ADDR, REG_PART_ID);
    Serial.printf("0x57  |  FOUND  | MAX30102 (Heart Rate/SpO2)\n");
    Serial.printf("  Part ID: 0x%02X — %s\n", partID,
                  partID == 0x15 ? "GENUINE chip confirmed" : "unexpected value, may be fake");
  }

  Serial.println("\n(Next scan in 10 seconds...)\n");
  delay(10000);
}
