// ============================================================================
// MAX30102 Direct Register Test
// Disconnect ALL other sensors before running this.
// Only MAX30102 VIN, GND, SCL, SDA should be connected.
// Open Serial Monitor at 115200 baud.
// ============================================================================
#include <Wire.h>

#define I2C_SDA     47
#define I2C_SCL     48
#define MAX30102_ADDR 0x57
#define REG_PART_ID   0xFF   // Always returns 0x15 if chip is alive
#define REG_REV_ID    0xFE   // Revision ID

// Send 9 clock pulses to unstick frozen I2C device
void i2cBusRecover() {
  pinMode(I2C_SDA, OUTPUT); digitalWrite(I2C_SDA, HIGH);
  pinMode(I2C_SCL, OUTPUT); digitalWrite(I2C_SCL, HIGH);
  for (int i = 0; i < 9; i++) {
    digitalWrite(I2C_SCL, LOW);  delayMicroseconds(5);
    digitalWrite(I2C_SCL, HIGH); delayMicroseconds(5);
  }
  digitalWrite(I2C_SDA, LOW);  delayMicroseconds(5);
  digitalWrite(I2C_SCL, HIGH); delayMicroseconds(5);
  digitalWrite(I2C_SDA, HIGH); delayMicroseconds(5);
}

uint8_t readRegister(uint8_t reg) {
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom(MAX30102_ADDR, 1);
  if (Wire.available()) return Wire.read();
  return 0xFF;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n========================================");
  Serial.println("  MAX30102 Direct Register Test");
  Serial.println("  Disconnect ALL other sensors first!");
  Serial.println("========================================\n");

  i2cBusRecover();
  Wire.begin(I2C_SDA, I2C_SCL);
  delay(100);

  // Step 1: Check if address responds
  Wire.beginTransmission(MAX30102_ADDR);
  byte err = Wire.endTransmission();

  Serial.printf("I2C Address 0x57: %s\n\n", err == 0 ? "RESPONDING" : "NOT FOUND");

  if (err != 0) {
    Serial.println("RESULT: MAX30102 not detected.");
    Serial.println("  - Check VIN, GND, SCL, SDA wires");
    Serial.println("  - Try swapping SCL and SDA wires");
    Serial.println("  - Module may be damaged");
    return;
  }

  // Step 2: Read Part ID — must be 0x15
  uint8_t partID = readRegister(REG_PART_ID);
  uint8_t revID  = readRegister(REG_REV_ID);

  Serial.printf("Part ID register (0xFF): 0x%02X  ", partID);
  Serial.println(partID == 0x15 ? "CORRECT (chip is genuine MAX30102)" : "WRONG (expected 0x15 — chip may be fake or damaged)");

  Serial.printf("Rev ID  register (0xFE): 0x%02X\n\n", revID);

  if (partID == 0x15) {
    Serial.println("RESULT: MAX30102 is WORKING correctly.");
    Serial.println("  The problem is interaction with other sensors on the bus.");
    Serial.println("  Try adding sensors back one by one.");
  } else {
    Serial.println("RESULT: MAX30102 chip is NOT responding correctly.");
    Serial.println("  The module is likely damaged or counterfeit.");
  }
}

void loop() {}
