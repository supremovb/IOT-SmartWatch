class ClinicDevice {
  final String id;
  String patientName;
  String status; // Online, Offline
  int battery;
  String lastSync;
  String firmware;
  List<String> logs;

  ClinicDevice({
    required this.id,
    required this.patientName,
    this.status = 'Online',
    this.battery = 100,
    this.lastSync = 'Just now',
    this.firmware = 'v2.1.0',
    List<String>? logs,
  }) : logs = logs ?? [];
}
