# ESP32-S3 Smart Watch — Setup Guide

## Your Board
- **Board:** Waveshare ESP32-S3-LCD-1.9 (knockoff compatible)
- **MCU:** ESP32-S3R8, dual-core LX7 @ 240MHz, 8MB PSRAM, 16MB Flash
- **Display:** 1.9" ST7789V2, **170×320** pixels, 262K colors, SPI
- **Connectivity:** WiFi 802.11 b/g/n, BLE 5.0
- **Extras:** QMI8658 IMU, SD card slot, USB-C, LiPo charging

## Pin Mapping (from Waveshare official demo)
| Pin    | GPIO |
|--------|------|
| MOSI   | 4    |
| SCLK   | 5    |
| DC     | 6    |
| CS     | 7    |
| RST    | 14   |
| BL     | 8    |
| BOOT   | 0    |

---

## Step 1: Arduino IDE Board Setup

You already have Arduino IDE 2.3.8 installed. Now:

1. **Add ESP32 board URL:**
   - Go to **File → Preferences**
   - In "Additional Board Manager URLs", paste:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   - Click OK

2. **Install ESP32 board package:**
   - Go to **Tools → Board → Boards Manager**
   - Search `esp32`
   - Install **"esp32 by Espressif Systems"** version **3.0.7 or newer**

3. **Select board settings:**
   - **Tools → Board → esp32 → ESP32S3 Dev Module**
   - **Tools → USB CDC On Boot → Enabled**
   - **Tools → Flash Size → 16MB (128Mb)**
   - **Tools → PSRAM → OPI PSRAM**
   - **Tools → Port → (your COM port)**

---

## Step 2: Install Arduino Libraries

Go to **Sketch → Include Library → Manage Libraries** and install:

| Library                    | Author           | Notes                        |
|---------------------------|------------------|------------------------------|
| **Arduino_GFX_Library**   | moononournation  | v1.5.6+ (display driver)     |
| **ArduinoJson**           | Benoit Blanchon  | v7+ (JSON parsing)           |
| **WebSockets**            | Markus Sattler   | WebSocket server             |

> BLE library is built into the ESP32 board package — no separate install needed.

---

## Step 3: Configure WiFi (Optional)

Edit these lines in `ESP32_SmartWatch.ino` if you want WiFi WebSocket support:

```cpp
const char* WIFI_SSID = "YOUR_WIFI_SSID";     // ← Your WiFi name
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";  // ← Your WiFi password
```

Leave as-is to skip WiFi (BLE + Serial still work).

---

## Step 4: Upload Firmware

1. Connect ESP32-S3 via USB-C
2. If the board doesn't appear as a COM port:
   - Hold **BOOT** button → press **RESET** → release RESET → release BOOT
   - This forces download mode
3. Open `ESP32_SmartWatch/ESP32_SmartWatch.ino` in Arduino IDE
4. Click **Upload** (→ arrow button)
5. Open **Tools → Serial Monitor** (115200 baud)
6. You should see:
   ```
   =============================
     ESP32-S3 Smart Watch v1.0
     Waveshare LCD-1.9 170x320
   =============================
   [BLE] Advertising as 'ESP32-SmartWatch'
   [READY] Waiting for connections...
   ```
7. The display shows "Ready!" with connection info

---

## Step 5: Flutter App Setup

### Install dependencies
```powershell
cd C:\Users\primo\Desktop\SmartWatchArduino\IOT-Smart-Watch-SDCA
flutter pub get
```

### Enable Developer Mode (Windows)
Run this once:
```powershell
start ms-settings:developers
```
Toggle "Developer Mode" ON.

### Android BLE permissions
Already configured in `AndroidManifest.xml`. Just build and run:
```
flutter run
```

---

## Step 6: Connect App to ESP32

1. Run the Flutter app on your phone/emulator
2. Swipe to the **Settings** screen (last page)
3. Scroll down to **ESP32 CONNECTION**

### BLE (Bluetooth):
- Tap **Connect BLE**
- It scans for "ESP32-SmartWatch" and auto-connects
- Data syncs every second

### WiFi WebSocket:
- Check ESP32 Serial Monitor for its IP address
- Enter the IP in the text field (e.g., `192.168.1.105`)
- Tap **Connect WiFi**

### USB Serial (Testing):
Paste this in Serial Monitor and hit Enter:
```json
{"t":"14:30","d":"Monday, Apr 14","ap":"PM","hr":72,"st":5234,"sg":10000,"bt":87,"tp":24.5,"wt":"Cloudy"}
```

---

## Quick Test Commands (Serial Monitor)

Switch screens:
```json
{"sc":0}
```
(0=Watch Face, 1=Heart Rate, 2=Steps, 3=Timer, 4=Notifications)

Update heart rate:
```json
{"hr":95}
```

Send notification:
```json
{"nf":[{"t":"Message","b":"Hello from Flutter!"}],"ur":1}
```

Change accent color to green:
```json
{"ac":"00FF88"}
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Display blank | Check backlight: try `TFT_BL = -1` or different GPIO |
| Upload fails | Hold BOOT + press RESET, then upload |
| BLE not found | Enable Bluetooth + Location on phone |
| WiFi fails | Check SSID/password, same network |
| Display colors wrong | Normal — ST7789V2 uses IPS=true |
| Can't find COM port | Install CH340/CP2102 USB driver |
