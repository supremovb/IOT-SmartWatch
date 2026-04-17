class Shift {
  final String id;
  final String name;
  final String startTime; // HH:mm format
  final String endTime; // HH:mm format
  final String description;

  const Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
    };
  }
}

class ShiftSchedule {
  // Predefined shifts for St. Dominic
  static const List<Shift> stDominicShifts = [
    Shift(
      id: 'morning',
      name: 'Morning Shift',
      startTime: '06:00',
      endTime: '14:00',
      description: '6:00 AM - 2:00 PM',
    ),
    Shift(
      id: 'afternoon',
      name: 'Afternoon Shift',
      startTime: '14:00',
      endTime: '22:00',
      description: '2:00 PM - 10:00 PM',
    ),
    Shift(
      id: 'night',
      name: 'Night Shift',
      startTime: '22:00',
      endTime: '06:00',
      description: '10:00 PM - 6:00 AM',
    ),
  ];

  static Shift? getShiftById(String id) {
    try {
      return stDominicShifts.firstWhere((shift) => shift.id == id);
    } catch (e) {
      return null;
    }
  }
}
