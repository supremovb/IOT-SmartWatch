class Patient {
  final String id;
  String name;
  int age;
  String condition;
  String riskLevel; // Critical, High, Medium, Low
  String deviceStatus; // Online, Offline
  String lastSync;
  String deviceId;
  int heartRate;
  int spo2;
  double temperature;
  int steps;
  String notes;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.condition,
    required this.riskLevel,
    this.deviceStatus = 'Online',
    this.lastSync = 'Just now',
    this.deviceId = '',
    this.heartRate = 75,
    this.spo2 = 97,
    this.temperature = 98.2,
    this.steps = 0,
    this.notes = '',
  });

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? condition,
    String? riskLevel,
    String? deviceStatus,
    String? lastSync,
    String? deviceId,
    int? heartRate,
    int? spo2,
    double? temperature,
    int? steps,
    String? notes,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      condition: condition ?? this.condition,
      riskLevel: riskLevel ?? this.riskLevel,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      lastSync: lastSync ?? this.lastSync,
      deviceId: deviceId ?? this.deviceId,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      temperature: temperature ?? this.temperature,
      steps: steps ?? this.steps,
      notes: notes ?? this.notes,
    );
  }
}
