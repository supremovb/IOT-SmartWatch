class DeviceModel {
  final String id;
  String name;
  String patientName;
  String status; // 'Online' | 'Offline'
  int battery;
  String lastSync;
  String firmware;
  List<String> logs;

  DeviceModel({
    required this.id,
    this.name = 'ESP32 SmartWatch',
    required this.patientName,
    this.status = 'Online',
    this.battery = 100,
    this.lastSync = 'Just now',
    this.firmware = 'v2.1.0',
    List<String>? logs,
  }) : logs = logs ??
            [
              'Synced vitals — Just now',
              'Battery check — 5 min ago',
              'Connected — 1 hr ago',
            ];
}
