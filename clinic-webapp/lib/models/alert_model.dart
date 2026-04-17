class AlertModel {
  final String id;
  final String title;
  final String patient;
  final String severity; // 'critical' | 'warning'
  String status; // 'new' | 'in-progress' | 'resolved' | 'escalated'
  final String timestamp;
  final String value;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.title,
    required this.patient,
    required this.severity,
    this.status = 'new',
    required this.timestamp,
    required this.value,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
