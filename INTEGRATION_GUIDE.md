# ESP32-S3 Smart Watch — Full Integration Guide
## St. Dominic Health Monitoring System

---

## SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                     WEARABLE DEVICE (Breadboard)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ ESP32-S3     │  │ Sensors      │  │ Battery              │  │
│  │ LCD 1.9"     │  │ MAX30102     │  │ 502030 250mAh        │  │
│  │ (Watch Face) │  │ MLX90614     │  │ + TP4056 USB-C       │  │
│  │              │  │ MPU6050      │  │   (resisted to 250mA)│  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────┘  │
│         │     I2C Bus      │                                    │
│         └──────────────────┘                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │  WiFi HTTP POST (every 5-10 seconds)
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SUPABASE CLOUD                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ patients │  │ alerts   │  │ devices  │  │ vitals_history│  │
│  │ (vitals) │  │          │  │          │  │ (NEW TABLE)   │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘  │
│         Real-time subscriptions (WebSocket)                     │
└────────────────────┬────────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              CLINIC WEBAPP (Flutter Web)                         │
│  Dashboard → Patients → Alerts → Devices → Reports             │
│  Real-time vitals display + automated alerts                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## SENSORS — What They Measure

| Sensor | Measures | How It Works |
|--------|----------|--------------|
| MAX30102 | Heart Rate + SpO2 | Red/IR LED shines through finger/wrist, photodetector reads pulse |
| MLX90614 | Body Temperature | Infrared sensor measures skin temp without contact |
| MPU6050 | Steps (pedometer) | Accelerometer detects walking "bounce" pattern |

---

## BREADBOARD WIRING — Step by Step

Your ESP32-S3-LCD-1.9 is already on the breadboard (see photo). 
All 3 sensors share the SAME 4 wires: 3V3, GND, SDA (GPIO47), SCL (GPIO48).

### Where Are the 4 Pins? (ALL on the LEFT side!)

Hold the board with USB-C on top and display facing you.
All 4 pins are on the LEFT edge, counting down from the USB-C port:

```
USB-C port (top)
    │
    ├── Pin 40  VBUS
    ├── Pin 39  VSYS
    ├── Pin 38  GND         ← ⚫ BLACK wire  (3rd pin down)
    ├── Pin 37  3V3_EN
    ├── Pin 36  3V3         ← 🔴 RED wire    (5th pin down)
    ├── Pin 35  VREF
    ├── Pin 34  GPIO48/SCL  ← 🟡 YELLOW wire (7th pin down)
    ├── Pin 33  GND
    ├── Pin 32  GPIO47/SDA  ← 🔵 BLUE wire   (9th pin down)
    │   ...
```

These are the same I2C pins the onboard QMI8658 IMU uses — your
external sensors will share this bus (each has a unique address).

### Wiring Step by Step

**STEP 1: Connect 4 jumper wires from LEFT side of ESP32 to breadboard**

Count down from the USB-C port on the LEFT edge:
- 3rd pin (Pin 38) → ⚫ BLACK wire → GND (ground)
- 5th pin (Pin 36) → 🔴 RED wire   → 3V3 (3.3V power)
- 7th pin (Pin 34) → 🟡 YELLOW wire → GPIO48 (SCL — clock)
- 9th pin (Pin 32) → 🔵 BLUE wire   → GPIO47 (SDA — data)

Run these 4 wires to an open area of the breadboard where your sensors will go.

**STEP 2: Connect MAX30102 (Heart Rate + SpO2)**

```
MAX30102 Module    →    Breadboard Bus
─────────────────────────────────────
VIN                →    3V3 (red)
GND                →    GND (black)
SDA                →    GPIO47 (blue)
SCL                →    GPIO48 (yellow)
INT                →    (leave unconnected for now)
```

**STEP 3: Connect MLX90614 (Body Temperature)**

```
MLX90614 Module    →    Breadboard Bus
─────────────────────────────────────
VIN                →    3V3 (red)
GND                →    GND (black)
SDA                →    GPIO47 (blue)
SCL                →    GPIO48 (yellow)
```

**STEP 4: Connect MPU6050 (Steps/Accelerometer)**

```
MPU6050 Module     →    Breadboard Bus
─────────────────────────────────────
VCC                →    3V3 (red)
GND                →    GND (black)
SDA                →    GPIO47 (blue)
SCL                →    GPIO48 (yellow)
AD0                →    GND (sets address to 0x68)
INT                →    (leave unconnected for now)
```

### Visual Layout on Breadboard

```
    ┌─── USB-C Cable ───┐
    │                    │
    │  ┌──────────────┐  │
    │  │  ESP32-S3    │  │
    │  │  LCD 1.9"    │  │
    │  │              │  │
    │  │  [Display]   │  │
    │  │              │  │
    │  └──┬──┬──┬──┬──┘  │
    │     │  │  │  │     │
    │    3V3 GND 47 48   │
    │     │  │  │  │     │          ┌──────────┐
    │     ├──┼──┼──┼─────────────→ │ MAX30102 │ (finger sensor)
    │     │  │  │  │     │          └──────────┘
    │     ├──┼──┼──┼─────────────→ ┌──────────┐
    │     │  │  │  │     │          │ MLX90614 │ (point at skin)
    │     │  │  │  │     │          └──────────┘
    │     ├──┼──┼──┼─────────────→ ┌──────────┐
    │     │  │  │  │     │          │ MPU6050  │ (motion/steps)
    │     │  │  │  │     │          └──────────┘
    └─────┴──┴──┴──┴─────┘
         (all share same 4 wires)
```

> **IMPORTANT:** All 3 sensors connect to the SAME 4 wires in parallel.
> I2C is a bus — each sensor has a unique address so they don't conflict.

---

## STEP-BY-STEP IMPLEMENTATION PLAN

### PHASE 1: Install Libraries + I2C Scanner (DO THIS FIRST)

**Step 1.1 — Install Arduino Libraries**
In Arduino IDE → Sketch → Include Library → Manage Libraries, search and install:
- "SparkFun MAX3010x Pulse and Proximity Sensor Library" (for MAX30102)
- "Adafruit MLX90614" (for GY-906 temperature)
- "Adafruit MPU6050" (for GY-521 accelerometer/steps)
- "Adafruit Unified Sensor" (required by MPU6050 library)
- "ArduinoJson" (for sending data to Supabase)

**Step 1.2 — Wire sensors on breadboard (see wiring section above)**

**Step 1.3 — Upload I2C Scanner sketch**
Open `I2C_Scanner/I2C_Scanner.ino` and upload.
Check Serial Monitor — you should see:
```
0x57  |  FOUND | MAX30102 (Heart Rate/SpO2)
0x5A  |  FOUND | MLX90614 (Body Temperature)
0x68  |  FOUND | MPU6050 (Accelerometer/Gyro)
```
If any sensor shows MISSING, check its wiring.

---

### PHASE 2: Sensor Test Sketch
**Goal:** Read real data from all 3 sensors and display on LCD.

Upload `Sensor_Test/Sensor_Test.ino` (created for you).
This reads all sensors and prints values to Serial + LCD.

---

### PHASE 3: WiFi + Supabase Integration
**Goal:** ESP32 sends real vitals to Supabase every 5-10 seconds.

The ESP32 will:
1. Connect to your WiFi network
2. Read sensors every second
3. Every 10 seconds, HTTP POST data to Supabase REST API
4. Update the `patients` table with current vitals
5. Insert into `vitals_history` for historical tracking
6. Auto-create alerts when vitals are out of range

The clinic-webapp ALREADY has real-time Supabase subscriptions,
so the dashboard will update INSTANTLY when data arrives.

---

### PHASE 4: Full Watch Firmware
**Goal:** Combined sensor reading + watch face display + WiFi upload.

The final ESP32_SmartWatch.ino will:
- Show real HR/SpO2/Temp/Steps on the watch LCD (not hardcoded)
- Upload to Supabase in background via WiFi
- Trigger alerts for: HR<50 or HR>120, SpO2<90, Temp>38.5°C

---

### PHASE 5: Clinic Webapp Enhancements
**Goal:** Historical vitals charts + real-time alerts.

Updates to clinic-webapp:
- Query `vitals_history` table for time-series charts
- Show real-time sensor updates on patient dashboard
- Configure alert thresholds per patient

---

## WHAT YOU DON'T NEED

| Item | Status |
|------|--------|
| ESP32-S3 3.5" LCD | NOT AVAILABLE — skip |
| M5Stack Watch Case | NOT AVAILABLE — skip |
| ECG sensor | NOT PURCHASED — HR/SpO2 via MAX30102 PPG instead |
| ENS160+AHT21 | OPTIONAL — can add later for air quality if needed |

---

## PRIORITY ORDER

1. ✅ Display working on breadboard (DONE!)
2. 🔜 Install sensor libraries in Arduino IDE
3. 🔜 Wire 3 sensors on breadboard
4. 🔜 Run I2C Scanner to verify connections
5. 🔜 Run Sensor Test sketch
6. 🔜 Add WiFi + Supabase upload
7. 🔜 Combine everything into final watch firmware
8. 🔜 Update clinic-webapp for real-time data
9. 🔜 Battery + TP4056 charging setup
10. 🔜 Final assembly and testing
