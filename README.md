# Dominican Smartwatch Monitoring

A full-stack patient monitoring system that combines an ESP32-based smartwatch, a Flutter smartwatch interface, and a Flutter web admin dashboard for clinic staff.

## Project Summary

This repository brings together the main parts of the Dominican smartwatch monitoring workflow:

- a physical ESP32 smartwatch with touch-based health screens
- a smartwatch UI preview made with Flutter
- an admin dashboard for monitoring patients, devices, and alerts
- SOS alert delivery from the watch to the clinic panel
- cloud-backed synchronization for device and patient data

The goal is to provide a lightweight healthcare monitoring prototype that can be used for demonstration, research, and further development.

## Key Features

### Smartwatch firmware
- Multi-screen watch interface for time, heart data, movement, patient details, and SOS
- Touch interaction and swipe-style navigation support
- Unique device identity for patient linking
- QMI8658 motion tracking support for movement and step-based activity data
- Background cloud sync for watch status and alerts

### Admin dashboard
- Patient monitoring view for clinic staff
- Device-to-patient linking workflow
- Alert tracking and dashboard summaries
- Real-time style refresh for new SOS and health alerts
- Flutter web interface for local or hosted deployment

### Smartwatch preview app
- UI mirror of the physical watch layout
- Flutter-based watch screen testing without reflashing hardware
- Useful for design iteration and demo presentations

## Technology Stack

- ESP32 Arduino firmware
- Flutter for cross-platform UI
- Supabase for cloud database and alert storage
- Provider-based state management in the admin panel

## Repository Layout

- `ESP32_SmartWatch/` - main firmware for the physical smartwatch
- `IOT-Smart-Watch-SDCA/` - Flutter smartwatch interface preview
- `clinic-webapp/` - Flutter admin dashboard for clinic monitoring
- `I2C_Scanner/` - diagnostic sketch for detecting I2C devices
- `Sensor_Test/` - test sketch for validating sensors
- `LCD_Test/` - display validation sketch
- `INTEGRATION_GUIDE.md` - overall integration notes and implementation flow
- `HARDWARE_WIRING_GUIDE.md` - hardware wiring and connection guide

## Target Hardware

Primary board:
- Waveshare ESP32-S3 Touch LCD 1.9

Sensors used or supported in this setup:
- QMI8658 IMU for motion and step detection
- MAX30102 for heart rate and SpO2
- MLX90614 for temperature

## How the System Works

1. The smartwatch displays health and device information on the ESP32 LCD.
2. The user can trigger an SOS action from the watch interface.
3. The device sends alert or monitoring data to the cloud backend.
4. The admin dashboard refreshes and displays the latest patient-related events.
5. Staff can view device links, patient details, and alert activity from the web panel.

## Quick Start

### 1. Run the smartwatch preview app

```bash
cd IOT-Smart-Watch-SDCA
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

### 2. Run the clinic admin dashboard

```bash
cd clinic-webapp
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8090
```

### 3. Flash the ESP32 firmware

Open the firmware below in the Arduino IDE and configure the required network and backend settings before uploading:

- `ESP32_SmartWatch/ESP32_SmartWatch.ino`

## Supabase Setup

The project includes SQL and helper files for alert and data integration:

- `clinic-webapp/enable_sos_alerts.sql`
- `clinic-webapp/supabase_migration.sql`
- `clinic-webapp/supabase_seed.sql`
- `clinic-webapp/create_messages_table.sql`

Before deploying publicly, review:
- row-level security policies
- project URLs and keys
- alert insertion permissions
- device and patient relationship data

## Recommended Development Workflow

### Firmware side
- verify screen and touch behavior
- confirm device ID generation
- connect the board to Wi-Fi
- test SOS alert posting from the physical watch

### Dashboard side
- run the web app locally
- open the alerts and dashboard views
- verify that new alerts appear after the watch sends data
- confirm the patient-device mapping is correct

## Documentation Included

Additional project guides are available in the repository:

- `INTEGRATION_GUIDE.md`
- `HARDWARE_WIRING_GUIDE.md`
- `clinic-webapp/QUICK_START.md`
- `clinic-webapp/AUTH_SETUP.md`
- `clinic-webapp/IMPLEMENTATION_SUMMARY.md`

## Notes for Publishing

- Generated build outputs are excluded from version control
- Local SDK paths and machine-specific settings are excluded
- Vendor demo files are not required for the main repository workflow

## Possible Future Improvements

- stronger authentication for staff accounts
- hosted deployment for the admin panel
- full historical charts for patient vitals
- production-ready device enrollment flow
- improved analytics and reporting

## Intended Use

This repository is intended for academic, prototype, and demonstration use for smartwatch-assisted clinic monitoring and emergency notification workflows.
