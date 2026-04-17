import 'shift.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String role; // doctor, nurse, admin
  final String department; // e.g., "Cardiology", "Emergency", "General"
  final String specialization; // e.g., "Pediatrics", "Surgery"
  final String employeeId; // Staff ID
  final Shift shift;
  final String? photoUrl;
  final DateTime loginTime;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    required this.specialization,
    required this.employeeId,
    required this.shift,
    this.photoUrl,
    required this.loginTime,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'doctor',
      department: json['department'] ?? '',
      specialization: json['specialization'] ?? '',
      employeeId: json['employeeId'] ?? '',
      shift: json['shift'] != null
          ? Shift.fromJson(json['shift'])
          : ShiftSchedule.stDominicShifts[0],
      photoUrl: json['photoUrl'],
      loginTime: json['loginTime'] != null
          ? DateTime.parse(json['loginTime'])
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'specialization': specialization,
      'employeeId': employeeId,
      'shift': shift.toJson(),
      'photoUrl': photoUrl,
      'loginTime': loginTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
