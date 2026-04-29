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
  double humidity;     // %RH from AHT21
  int eco2;            // eCO2 ppm from ENS160
  int tvoc;            // TVOC ppb from ENS160
  double ambientTemp;  // °C from AHT21

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
    this.humidity = 0,
    this.eco2 = 400,
    this.tvoc = 0,
    this.ambientTemp = 0,
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
    double? humidity,
    int? eco2,
    int? tvoc,
    double? ambientTemp,
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
      humidity: humidity ?? this.humidity,
      eco2: eco2 ?? this.eco2,
      tvoc: tvoc ?? this.tvoc,
      ambientTemp: ambientTemp ?? this.ambientTemp,
    );
  }
}
