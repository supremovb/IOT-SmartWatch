# MAX30102 Wiring Guide

## Sensor pins (labeled on the black module)

```
VIN   GND   SCL   SDA   INT
```

> INT pin — leave unconnected

---

## Wiring table

| MAX30102 pin | Connect to |
|---|---|
| VIN | Breadboard + rail (red) |
| GND | Breadboard - rail (black) |
| SCL | Row 15 → also wire ESP32 GPIO2 to Row 15 |
| SDA | Row 16 → also wire ESP32 GPIO1 to Row 16 |
| INT | Leave unconnected |

---

## ESP32 pins to use

| ESP32 pin | Row | Wire color |
|---|---|---|
| GPIO2 (pin 6, right side) | Row 15 | Green |
| GPIO1 (pin 5, right side) | Row 16 | Yellow |

> These are separate from the other sensors which use GPIO47/GPIO48.
> MAX30102 runs on its own isolated I2C bus (Bus 2).

---

## Why separate rows from other sensors

The MAX30102 can hold the I2C bus low and block all other sensors if it shares GPIO47/GPIO48. Using GPIO1/GPIO2 isolates it completely.

---

## Full wiring summary

```
ESP32 right side         Breadboard
────────────────         ──────────────────────────────
GPIO2 (pin 6) ────────► Row 15 ◄─── SCL (MAX30102)
GPIO1 (pin 5) ────────► Row 16 ◄─── SDA (MAX30102)

Breadboard rails
+ rail ◄─── VIN (MAX30102)
- rail ◄─── GND (MAX30102)
```

---

## Test after wiring

Upload `MAX30102_BusTest/MAX30102_BusTest.ino` — it scans both buses simultaneously.

Expected result:
```
=== BUS 2 (GPIO1/GPIO2) — MAX30102 ===
0x57  |  FOUND  | MAX30102 (Heart Rate/SpO2)
  Part ID: 0x15 — GENUINE chip confirmed
```

---

## Buying a replacement

- Look for: **MAX30102** (black sensor window)
- Avoid mislabeled **MAX30100** clones — older, weaker chip
- Confirm the module has: VIN, GND, SCL, SDA, INT pins labeled
