# Smart Watch Hardware Wiring Guide

## Your complete hardware kit

| # | Item | Purpose |
|---|---|---|
| 1 | diymore ESP32-S3 1.9" LCD (170�320, Type-C) | The brain � runs the watch firmware |
| 2 | 830 tie-point breadboard set | Prototyping base � connects everything without soldering |
| 3 | MPU6050 GY-521 module | 6-axis IMU � pitch, roll, gyroscope |
| 4 | MAX30102 module | Heart rate + SpO2 (blood oxygen) sensor |
| 5 | GY-906 MLX90614 module | Contactless temperature sensor |
| 6 | ENS160 + AHT21 module | Air quality (CO2, TVOC) + humidity + temperature |
| 7 | TP4056 USB-C module | Battery charger + protection circuit |
| 8 | 502030 LiPo battery (200mAh) | Portable power source |

---

## Setup order � do one at a time

| Priority | Sensor | Reason |
|---|---|---|
| **1st** | **MPU6050** | Firmware already done. Easiest wiring. Just 5 wires. |
| **2nd** | **MAX30102** | Most medically useful � live heart rate + SpO2 |
| **3rd** | **MLX90614** | Contactless body temperature |
| **4th** | **ENS160 + AHT21** | Air quality, humidity, ambient temperature |
| **5th** | **TP4056 + LiPo battery** | Do last � involves battery safety |

> Set up one sensor at a time. Test it on the watch screen before adding the next one.

---

## The 4 ESP32 pins used by every sensor

Look for these labels printed in small white text on the back of your ESP32 board:

| Label on board | What it is | Wire color to use |
|---|---|---|
| **3V3** | 3.3V power � feeds all sensors | Red |
| **GND** | Ground � return wire | Black |
| **IO47** | GPIO47 = SDA (data line) | Yellow |
| **IO48** | GPIO48 = SCL (clock line) | Green |

All four sensors share these same four pins. Each sensor has a different I2C address so there is no conflict.

---

## I2C address reference (no conflicts)

| Module | I2C Address |
|---|---|
| CST816 touch (built-in on board) | 0x15 |
| QMI8658 IMU (built-in on board) | 0x6B |
| MPU6050 when AD0=GND | 0x68 |
| MAX30102 | 0x57 |
| MLX90614 | 0x5A |
| ENS160 when ADDR=GND | 0x53 |
| AHT21 | 0x38 |

---

## How the breadboard works

```
RED rail (+)   + + + + + + + + + + + + + + +   connect 3V3 here
BLUE rail (-)  - - - - - - - - - - - - - - -   connect GND here

row 1:   [a][b][c][d][e]     [f][g][h][i][j]
row 2:   [a][b][c][d][e]     [f][g][h][i][j]
...63 rows...

RED rail (+)   + + + + + + + + + + + + + + +
BLUE rail (-)  - - - - - - - - - - - - - - -   connect GND here
```

- Holes in the same numbered row (a-e or f-j) are all connected to each other
- The + rail runs full length � this is your 3V3 line
- The - rail runs full length � this is your GND line
- You pick two free rows to be your SDA row and SCL row

---

---
# STEP 1 � MPU6050 GY-521
---

Firmware status: DONE � already reads pitch, roll, and gyro every 100ms

## MPU6050 pins (labeled on the module, top to bottom)

```
VCC   ? power
GND   ? ground
SCL   ? clock
SDA   ? data
XDA   ? leave unconnected
XCL   ? leave unconnected
AD0   ? MUST wire to GND
INT   ? leave unconnected
```

## MPU6050 wiring table

| MPU6050 pin | Connect to |
|---|---|
| VCC | Breadboard + rail (red) |
| GND | Breadboard - rail (blue) |
| SCL | A free row, e.g. row 21 � also wire ESP32 IO48 to this row |
| SDA | A free row, e.g. row 20 � also wire ESP32 IO47 to this row |
| AD0 | Breadboard - rail (GND) � DO NOT SKIP |
| XDA, XCL, INT | Leave unconnected |

## MPU6050 step-by-step

1. Place MPU6050 on the breadboard
2. Red wire: ESP32 3V3 ? breadboard + rail
3. Black wire: ESP32 GND ? breadboard - rail
4. Yellow wire: ESP32 IO47 ? row 20 (this is now your SDA row)
5. Green wire: ESP32 IO48 ? row 21 (this is now your SCL row)
6. Wire: MPU6050 VCC ? + rail
7. Wire: MPU6050 GND ? - rail
8. Wire: MPU6050 SDA ? row 20
9. Wire: MPU6050 SCL ? row 21
10. Wire: MPU6050 AD0 ? - rail (GND)

## What to see after flashing

Boot screen: MPU6050 OK (green text)
Activity tab (A): shows "MPU6050 Tilt" with live pitch and roll values in degrees

---

---
# STEP 2 � MAX30102 (Heart Rate + SpO2)
---

Firmware status: NOT YET � wire it first, then ask for firmware implementation

## MAX30102 pins (labeled on the module)

```
VIN   (sometimes labeled VCC or 3.3V)
GND
SCL
SDA
INT   ? leave unconnected
IRD   ? leave unconnected (only on some boards)
```

## MAX30102 wiring table

| MAX30102 pin | Connect to |
|---|---|
| VIN / VCC | Breadboard + rail (red) |
| GND | Breadboard - rail (blue) |
| SCL | Row 21 (SCL row � already connected to ESP32 IO48) |
| SDA | Row 20 (SDA row � already connected to ESP32 IO47) |
| INT | Leave unconnected |

## MAX30102 step-by-step

1. Place MAX30102 on the breadboard (use different rows from MPU6050)
2. Wire: MAX30102 VIN ? + rail
3. Wire: MAX30102 GND ? - rail
4. Wire: MAX30102 SDA ? row 20 (SDA row)
5. Wire: MAX30102 SCL ? row 21 (SCL row)

No new wires to the ESP32 needed. The SDA/SCL rows are already connected.

Important: Press the MAX30102 sensor window gently against your fingertip to get readings. The sensor does not work in open air.

---

---
# STEP 3 � MLX90614 GY-906 (Contactless Temperature)
---

Firmware status: NOT YET � wire it first, then ask for firmware implementation

## MLX90614 pins

```
VIN   (3.3V)
GND
SCL
SDA
```

## MLX90614 wiring table

| MLX90614 pin | Connect to |
|---|---|
| VIN | Breadboard + rail |
| GND | Breadboard - rail |
| SCL | Row 21 (SCL row) |
| SDA | Row 20 (SDA row) |

## MLX90614 step-by-step

1. Place MLX90614 on the breadboard (different rows from other sensors)
2. Wire: VIN ? + rail
3. Wire: GND ? - rail
4. Wire: SDA ? row 20
5. Wire: SCL ? row 21

4 wires only. The module has built-in pull-up resistors. Nothing else needed.

---

---
# STEP 4 � ENS160 + AHT21 (Air Quality + Humidity)
---

Firmware status: NOT YET � wire it first, then ask for firmware implementation

## ENS160+AHT21 pins

```
VIN
GND
SCL
SDA
ADDR   ? wire to GND to set ENS160 address to 0x53
INT    ? leave unconnected
```

## ENS160+AHT21 wiring table

| Pin | Connect to |
|---|---|
| VIN | Breadboard + rail |
| GND | Breadboard - rail |
| SCL | Row 21 (SCL row) |
| SDA | Row 20 (SDA row) |
| ADDR | Breadboard - rail (GND) � required |
| INT | Leave unconnected |

## ENS160+AHT21 step-by-step

1. Place module on breadboard (different rows)
2. Wire: VIN ? + rail
3. Wire: GND ? - rail
4. Wire: SDA ? row 20
5. Wire: SCL ? row 21
6. Wire: ADDR ? - rail (GND)

---

---
# STEP 5 � TP4056 + LiPo Battery (Power) � Do this LAST
---

WARNING: Do not connect the LiPo battery backwards. Red wire is always positive. Black wire is always negative. A reversed LiPo can cause fire or permanent damage.

## What the TP4056 does

The TP4056 charges the LiPo battery through its USB-C port and protects it from over-discharge. When USB is plugged in, it charges. When USB is unplugged, the battery powers the ESP32 through the OUT pins.

## TP4056 pins

```
Left side:               Right side:
  B+  ? battery +           OUT+  ? power to ESP32
  B-  ? battery -           OUT-  ? ground to ESP32
```

## TP4056 wiring table

| Connection | From | To |
|---|---|---|
| Battery positive | LiPo red wire | TP4056 B+ |
| Battery negative | LiPo black wire | TP4056 B- |
| Power to board | TP4056 OUT+ | ESP32 5V or VIN pin |
| Ground to board | TP4056 OUT- | ESP32 GND pin |

## TP4056 step-by-step

1. Do not connect the battery yet
2. Wire TP4056 OUT- ? ESP32 GND
3. Wire TP4056 OUT+ ? ESP32 VIN (or 5V pin if available)
4. Connect LiPo black wire ? TP4056 B-
5. Connect LiPo red wire ? TP4056 B+
6. Plug TP4056 USB-C to charge � LED turns red while charging, green when full

---

## Full wiring summary (all sensors at once)

```
ESP32 board pins:
  3V3  ? breadboard + rail
  GND  ? breadboard - rail
  IO47 ? row 20  (SDA row)
  IO48 ? row 21  (SCL row)

MPU6050:     VCC?+rail  GND?-rail  SDA?row20  SCL?row21  AD0?-rail
MAX30102:    VIN?+rail  GND?-rail  SDA?row20  SCL?row21
MLX90614:    VIN?+rail  GND?-rail  SDA?row20  SCL?row21
ENS160+AHT21:VIN?+rail  GND?-rail  SDA?row20  SCL?row21  ADDR?-rail
```

---

## Firmware implementation status

| Sensor | Firmware |
|---|---|
| QMI8658 built-in IMU | Done |
| MPU6050 | Done |
| MAX30102 heart rate + SpO2 | Not yet � wire first |
| MLX90614 temperature | Not yet � wire first |
| ENS160 + AHT21 air quality | Not yet � wire first |
| TP4056 + battery | No firmware needed (power circuit) |

---

## Troubleshooting

### Sensor shows N/A or not found at boot
- MPU6050: check AD0 is wired to GND
- ENS160: check ADDR is wired to GND
- Any sensor: check VCC/VIN is in the + rail
- Any sensor: check GND is in the - rail
- Any sensor: check SDA and SCL are not swapped
- Push all wires firmly into the breadboard holes

### Battery not charging
- Check B+ and B- on TP4056 are not swapped
- The charging LED on TP4056 is red when charging

### MAX30102 reads zero
- The sensor must touch your skin � press it against a fingertip
- It does not work in open air
