// ============================================================================
// I2C Scanner — Find all sensors connected to GPIO47(SDA) / GPIO48(SCL)
// Upload this FIRST after wiring sensors on the breadboard.
// ============================================================================
#include <Wire.h>

#define I2C_SDA 47
#define I2C_SCL 48

// Known sensor addresses for this project
struct KnownDevice {
  byte addr;
  const char* name;
};

KnownDevice known[] = {
  {0x57, "MAX30102 (Heart Rate/SpO2)"},
  {0x5A, "MLX90614 (Body Temperature)"},
  {0x68, "MPU6050 (Accelerometer/Steps)"},
  {0x6B, "QMI8658 (Onboard IMU)"},
};
const int knownCount = sizeof(known) / sizeof(known[0]);

const char* getDeviceName(byte addr) {
  for (int i = 0; i < knownCount; i++) {
    if (known[i].addr == addr) return known[i].name;
  }
  return "Unknown";
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Wire.begin(I2C_SDA, I2C_SCL);
  
  Serial.println("\n============================================");
  Serial.println("  I2C Bus Scanner — ESP32-S3-LCD-1.9");
  Serial.printf("  SDA=GPIO%d  SCL=GPIO%d\n", I2C_SDA, I2C_SCL);
  Serial.println("============================================\n");
}

void loop() {
  int found = 0;
  
  Serial.println("Scanning I2C bus...\n");
  Serial.println("ADDR  | STATUS | DEVICE");
  Serial.println("------+--------+---------------------------");
  
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    byte error = Wire.endTransmission();
    
    if (error == 0) {
      Serial.printf("0x%02X  |  FOUND | %s\n", addr, getDeviceName(addr));
      found++;
    }
  }
  
  Serial.println("------+--------+---------------------------");
  Serial.printf("\nTotal devices found: %d\n", found);
  
  // Check which expected sensors are missing
  Serial.println("\n--- Expected Sensor Checklist ---");
  for (int i = 0; i < knownCount; i++) {
    Wire.beginTransmission(known[i].addr);
    byte err = Wire.endTransmission();
    Serial.printf("[%s] 0x%02X %s\n", 
                  err == 0 ? "OK" : "MISSING",
                  known[i].addr, 
                  known[i].name);
  }
  
  Serial.println("\n(Next scan in 10 seconds...)\n");
  delay(10000);
}
