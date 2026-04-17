// ============================================================================
// MINIMAL LCD TEST — Waveshare ESP32-S3-Touch-LCD-1.9
// This sketch ONLY tests the display. No BLE, no WiFi, no JSON.
// If this works, the pins are correct. If not, we try different pins.
// ============================================================================

#include <Arduino.h>
#include <Arduino_GFX_Library.h>

// ─── Correct pins from seller's product listing ────────────────────────────
// LCD_DIN  = GPIO13 (MOSI / Data In)
// LCD_CLK  = GPIO10 (SPI Clock)
// LCD_DC   = GPIO11 (Command/Data select)
// LCD_CS   = GPIO12 (Chip Select)
// LCD_RST  = GPIO9  (Reset)
// LCD_BL   = GPIO14 (Backlight)
#define TFT_MOSI  13
#define TFT_SCLK  10
#define TFT_DC    11
#define TFT_CS    12
#define TFT_RST    9
#define TFT_BL    14   // Backlight

// ─── Display: ST7789V2, 170x320 ────────────────────────────────────────────
// Using Arduino_ESP32SPI (hardware SPI with explicit pins for ESP32-S3)
Arduino_DataBus *bus = new Arduino_ESP32SPI(
  TFT_DC,    // DC
  TFT_CS,    // CS
  TFT_SCLK,  // SCK
  TFT_MOSI,  // MOSI
  -1          // MISO (not used)
);

Arduino_ST7789 *gfx = new Arduino_ST7789(
  bus,
  TFT_RST,   // RST
  0,          // rotation
  false,      // IPS = false (matches official demo: 0)
  170,        // width
  320,        // height
  35,         // col_offset1
  0,          // row_offset1
  35,         // col_offset2
  0           // row_offset2
);

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== MINIMAL LCD TEST ===");
  Serial.printf("MOSI=%d SCK=%d DC=%d CS=%d RST=%d BL=%d\n",
                TFT_MOSI, TFT_SCLK, TFT_DC, TFT_CS, TFT_RST, TFT_BL);

  // Backlight ON
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);
  Serial.println("Backlight HIGH");

  // Init display
  Serial.println("Calling gfx->begin()...");
  if (!gfx->begin()) {
    Serial.println("gfx->begin() FAILED!");
    // Try backlight LOW (some boards are inverted)
    digitalWrite(TFT_BL, LOW);
    Serial.println("Trying backlight LOW...");
  } else {
    Serial.println("gfx->begin() OK");
  }

  // Try WITHOUT invert first
  Serial.println("\n--- TEST 1: No inversion ---");
  gfx->fillScreen(0xF800); // RED
  Serial.println("Filled RED - do you see RED?");
  delay(2000);

  gfx->fillScreen(0x07E0); // GREEN
  Serial.println("Filled GREEN - do you see GREEN?");
  delay(2000);

  gfx->fillScreen(0x001F); // BLUE
  Serial.println("Filled BLUE - do you see BLUE?");
  delay(2000);

  // Now try WITH invert
  Serial.println("\n--- TEST 2: With invertDisplay(true) ---");
  gfx->invertDisplay(true);

  gfx->fillScreen(0xF800); // RED
  Serial.println("Filled RED (inverted) - do you see RED?");
  delay(2000);

  gfx->fillScreen(0x07E0); // GREEN
  Serial.println("Filled GREEN (inverted) - do you see GREEN?");
  delay(2000);

  gfx->fillScreen(0x001F); // BLUE
  Serial.println("Filled BLUE (inverted) - do you see BLUE?");
  delay(2000);

  // Now try with IPS toggled — reinit display
  Serial.println("\n--- TEST 3: Trying IPS=true ---");
  // We can't re-create the object, but we can try display invert off
  gfx->invertDisplay(false);
  gfx->fillScreen(0xFFFF); // WHITE
  Serial.println("Filled WHITE - do you see WHITE?");
  delay(2000);

  gfx->fillScreen(0x0000); // BLACK
  Serial.println("Filled BLACK - do you see BLACK?");
  delay(2000);

  // Final: show text
  Serial.println("\n--- TEST 4: Text ---");
  gfx->invertDisplay(true);
  gfx->fillScreen(0x0000);
  gfx->setTextColor(0xFFFF);
  gfx->setTextSize(3);
  gfx->setCursor(20, 100);
  gfx->println("HELLO");
  gfx->setCursor(20, 140);
  gfx->println("WORLD");
  gfx->setTextSize(1);
  gfx->setTextColor(0x07E0);
  gfx->setCursor(10, 200);
  gfx->println("If you see this,");
  gfx->setCursor(10, 215);
  gfx->println("display works!");
  Serial.println("Drew text. If you see HELLO WORLD, display is working!");

  // Try backlight LOW if HIGH didn't work
  Serial.println("\n--- TEST 5: Backlight toggle ---");
  Serial.println("Toggling backlight LOW in 5 seconds...");
  delay(5000);
  digitalWrite(TFT_BL, LOW);
  Serial.println("Backlight LOW now. If screen went dark, BL=HIGH is correct.");
  delay(3000);
  digitalWrite(TFT_BL, HIGH);
  Serial.println("Backlight HIGH again.");

  Serial.println("\n=== TEST COMPLETE ===");
  Serial.println("If NOTHING appeared on screen, pins may be wrong.");
  Serial.println("Open Serial Monitor and report what you saw.");
}

void loop() {
  // Nothing - just a test
  delay(1000);
}
