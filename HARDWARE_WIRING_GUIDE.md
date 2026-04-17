# Smart Watch Hardware Wiring Guide

## 1. What the small tools look like

### Female-to-female jumper wires
- These are thin colored wires.
- Each end has a small hole/socket.
- They are used to connect one pin header to another pin header.
- Best for: sensor board to breadboard or sensor to ESP32 pins if both sides have male pins.

### Male-to-male jumper wires
- These are thin colored wires.
- Each end has a metal pin.
- Best for: breadboard row to breadboard row.

### Male-to-female jumper wires
- One side is a metal pin.
- The other side is a socket hole.
- Best for: ESP32 pin header to breadboard or sensor module.

### Header pins
- These are black plastic strips with many small metal pins in a row.
- They are usually soldered onto a sensor board.
- Once soldered, jumper wires can plug onto them easily.

### Breadboard
- A white plastic board with many tiny holes.
- It lets you connect components without soldering.
- The holes in the same row are electrically connected.

### TP4056 charging module
- Small blue board with USB-C or Micro-USB.
- Used for charging and protecting a lithium battery.
- Usually marked with B+, B-, OUT+, OUT-.

---

## 2. Your current watch board pins

For your watch board, the shared I2C lines are:

- SDA = GPIO47
- SCL = GPIO48
- Power = 3V3
- Ground = GND

These three sensor modules can usually share the same I2C bus.

---

## 3. Sensor wiring without soldering

## Option A: breadboard test setup
Use this when you are still experimenting.

What you need:
- Breadboard
- Jumper wires
- Sensor boards that already have header pins attached

### Shared bus setup
1. Connect ESP32 3V3 to breadboard positive rail.
2. Connect ESP32 GND to breadboard ground rail.
3. Connect ESP32 GPIO47 to the breadboard row used for SDA.
4. Connect ESP32 GPIO48 to the breadboard row used for SCL.
5. Plug each sensor into the breadboard and connect all SDA pins together and all SCL pins together.

### MAX30102
- VIN -> 3V3
- GND -> GND
- SDA -> GPIO47
- SCL -> GPIO48
- INT -> leave unconnected for now

### MLX90614
- VIN -> 3V3
- GND -> GND
- SDA -> GPIO47
- SCL -> GPIO48

### ENS160 + AHT21
- VIN -> 3V3
- GND -> GND
- SDA -> GPIO47
- SCL -> GPIO48

### Important note
No-solder works best only if:
- the sensor module already has pins attached
- the wires fit tightly
- the watch is not being moved around too much

If the board has no header pins at all, no-solder setup is very difficult.

---

## 4. Sensor wiring with soldering

Use this for the final wearable version.

### What to solder
- Solder straight header pins onto each sensor board, or
- Solder flexible wires directly to each sensor pad

### Recommended permanent wiring
- One common 3V3 line to all sensor VIN pins
- One common GND line to all sensor GND pins
- One common SDA line to GPIO47
- One common SCL line to GPIO48

### Best practice
- Use short wires
- Keep SDA and SCL neat and not too long
- Put heat shrink or tape over exposed joints
- Secure modules so they do not wiggle

---

## 5. Simple connection summary

| Module | VCC | GND | SDA | SCL |
|---|---|---|---|---|
| MAX30102 | 3V3 | GND | GPIO47 | GPIO48 |
| MLX90614 | 3V3 | GND | GPIO47 | GPIO48 |
| ENS160+AHT21 | 3V3 | GND | GPIO47 | GPIO48 |

---

## 6. Which sensor to wire first

### First priority: MAX30102
This gives the most useful health data first:
- heart rate
- SpO2

### Second priority: MLX90614
This gives:
- non-contact temperature

### Third priority: ENS160 + AHT21
This gives:
- air quality
- eCO2
- TVOC
- humidity
- ambient temperature

---

## 7. Battery and charger plan

### TP4056 module
Connect:
- battery positive -> B+
- battery negative -> B-
- output positive -> watch power input positive
- output negative -> watch ground

### Warning
Do not connect the lithium battery backwards.
Double-check polarity before powering on.

---

## 8. How patient-to-device linking works

### Automatic detection
If the watch is turned on and connected to Wi-Fi, it sends its device ID to the admin panel.
That means the device can appear in the Devices page automatically.

### Patient linking
When adding or editing a patient, assign the watch device ID to that patient.
Example:
- WATCH-001

Once linked, the patient record can receive live watch updates.

---

## 9. Troubleshooting

### Sensor not detected
- check GND first
- check 3V3 first
- check SDA and SCL are not swapped
- make sure the wire is firmly inserted

### Watch powers on but sensor data is wrong
- loose jumper wires
- module not getting enough power
- wrong I2C address
- noisy breadboard connection

### Best advice
For testing: breadboard is okay.
For actual wearable use: soldering is much better and more stable.
