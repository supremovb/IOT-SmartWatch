class ClinicAlert {
  final String id;
  final String title;
  final String patientName;
  final String severity; // critical, warning
  String status; // new, in-progress, resolved, escalated
  final DateTime timestamp;
  final String value;

  ClinicAlert({
    required this.id,
    required this.title,
    required this.patientName,
    required this.severity,
    this.status = 'new',
    required this.timestamp,
    required this.value,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
