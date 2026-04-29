import 'dart:async';
import 'dart:convert';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/patient.dart';
import '../models/alert_model.dart';
import '../models/device_model.dart';

class AppProvider extends ChangeNotifier {
  final _rand = Random();
  Timer? _vitalsTimer;
  Timer? _cloudPollTimer;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _patientsChannel;
  RealtimeChannel? _devicesChannel;
  RealtimeChannel? _messagesChannel;
  final _supabase = Supabase.instance.client;
  bool _isLoaded = false;
  bool _isLoading = true;
  bool _cloudSyncInProgress = false;
  int _unreadMessages = 0;

  bool get isLoading => _isLoading;

  // ─── Notification / Settings prefs ───────────────────────────────────────
  bool emailNotifications = true;
  bool smsNotifications = false;
  String alertThreshold = 'medium';
  bool _darkMode = false;
  bool get darkMode => _darkMode;

  // ─── Email alert config ───────────────────────────────────────────────────
  String _alertEmail = '';
  String get alertEmail => _alertEmail;

  // ─── Global search ────────────────────────────────────────────────────────
  String globalSearch = '';

  // ─── Patients ─────────────────────────────────────────────────────────────
  List<Patient> _patients = [];

  // ─── Alerts ───────────────────────────────────────────────────────────────
  List<AlertModel> _alerts = [];

  // ─── Devices ──────────────────────────────────────────────────────────────
  List<DeviceModel> _devices = [];
  final Map<String, DateTime> _lastAutoAlertAt = {};
  final Set<String> _linkedPatientNotified = {};

  AppProvider() {
    _loadPrefs();
    loadData();
    _loadUnreadMessages();
  }

  void _loadPrefs() {
    emailNotifications = html.window.localStorage['emailNotifications'] != 'false';
    smsNotifications = html.window.localStorage['smsNotifications'] == 'true';
    alertThreshold = html.window.localStorage['alertThreshold'] ?? 'medium';
    _darkMode = html.window.localStorage['darkMode'] == 'true';
    _alertEmail = html.window.localStorage['alertEmail'] ?? '';
  }

  // ─── Load data from Supabase ──────────────────────────────────────────────
  Future<void> loadData() async {
    if (_isLoaded) return;
    try {
      await Future.wait([
        _loadPatients(),
        _loadAlerts(),
        _loadDevices(),
      ]);
      _isLoaded = true;
      _isLoading = false;
      _startRealTimeUpdates();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading data from Supabase: $e');
      _isLoading = false;
      _startRealTimeUpdates();
      notifyListeners();
    }
  }

  /// Force-reload all data from Supabase
  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadPatients(),
        _loadAlerts(),
        _loadDevices(),
        _loadUnreadMessages(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
    // Set up messages channel if it wasn't initialized (e.g. user wasn't
    // authenticated when the provider was first constructed).
    if (_messagesChannel == null) {
      _initMessagesChannel();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPatients() async {
    final data = await _supabase.from('patients').select();
    _patients = data.map<Patient>((row) => Patient(
      id: row['id'] ?? '',
      name: row['name'] ?? '',
      age: row['age'] ?? 0,
      condition: row['condition'] ?? '',
      riskLevel: row['risk_level'] ?? 'Medium',
      deviceStatus: row['device_status'] ?? 'Offline',
      lastSync: row['last_sync'] ?? 'N/A',
      deviceId: row['device_id'] ?? '',
      heartRate: row['heart_rate'] ?? 75,
      spo2: row['spo2'] ?? 97,
      temperature: (row['temperature'] ?? 98.2).toDouble(),
      steps: row['steps'] ?? 0,
      notes: row['notes'] ?? '',
      humidity: (row['humidity'] ?? 0).toDouble(),
      eco2: row['eco2'] ?? 400,
      tvoc: row['tvoc'] ?? 0,
      ambientTemp: (row['ambient_temp'] ?? 0).toDouble(),
    )).toList();
  }

  Future<void> _loadAlerts() async {
    final data = await _supabase.from('alerts').select().order('created_at', ascending: false);
    _alerts = data.map<AlertModel>((row) => AlertModel(
      id: row['id'] ?? '',
      title: row['title'] ?? '',
      patient: row['patient'] ?? '',
      severity: row['severity'] ?? 'warning',
      status: row['status'] ?? 'new',
      timestamp: row['timestamp'] ?? '',
      value: row['value'] ?? '',
    )).toList();
  }

  Future<void> _loadDevices() async {
    final data = await _supabase.from('devices').select();
    _devices = data.map<DeviceModel>((row) => DeviceModel(
      id: row['id'] ?? '',
      name: row['name'] ?? 'ESP32 SmartWatch',
      patientName: row['patient_name'] ?? '',
      status: row['status'] ?? 'Offline',
      battery: row['battery'] ?? 100,
      lastSync: row['last_sync'] ?? 'N/A',
      firmware: row['firmware'] ?? 'v2.1.0',
    )).toList();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────
  List<Patient> get patients => List.unmodifiable(_patients);
  List<AlertModel> get alerts => List.unmodifiable(_alerts);
  List<DeviceModel> get devices => List.unmodifiable(_devices);

  int get activePatients => _patients.length;
  int get alertsToday => _alerts.where((a) => a.status != 'resolved').length;
  int get devicesOnline =>
      _devices.where((d) => d.status == 'Online').length;
  int get criticalPatients =>
      _patients.where((p) => p.riskLevel == 'Critical').length;
  int get unreadAlerts =>
      _alerts.where((a) => a.status == 'new').length;

  int get unreadMessages => _unreadMessages;

  Future<void> _loadUnreadMessages() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;
      final data = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', myId)
          .eq('is_read', false);
      _unreadMessages = (data as List).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread messages: $e');
    }
  }

  void refreshUnreadMessages() {
    _loadUnreadMessages();
  }

  double get avgHeartRate {
    if (_patients.isEmpty) return 0;
    final online = _patients.where((p) => p.deviceStatus == 'Online').toList();
    if (online.isEmpty) return 0;
    return online.fold(0, (s, p) => s + p.heartRate) / online.length;
  }

  double get avgSpo2 {
    final online = _patients.where((p) => p.deviceStatus == 'Online').toList();
    if (online.isEmpty) return 0;
    return online.fold(0, (s, p) => s + p.spo2) / online.length;
  }

  double get avgTemperature {
    final online = _patients.where((p) => p.deviceStatus == 'Online').toList();
    if (online.isEmpty) return 0;
    return online.fold(0.0, (s, p) => s + p.temperature) / online.length;
  }

  int get avgSteps {
    final online = _patients.where((p) => p.deviceStatus == 'Online').toList();
    if (online.isEmpty) return 0;
    return (online.fold(0, (s, p) => s + p.steps) / online.length).round();
  }

  // ─── Real-time simulation + Supabase realtime ────────────────────────────
  Future<void> _pollCloudState() async {
    if (_cloudSyncInProgress) return;
    _cloudSyncInProgress = true;
    try {
      try {
        await _loadPatients();
      } catch (e) {
        debugPrint('Patient poll sync error: $e');
      }
      try {
        await _loadAlerts();
      } catch (e) {
        debugPrint('Alert poll sync error: $e');
      }
      try {
        await _loadDevices();
      } catch (e) {
        debugPrint('Device poll sync error: $e');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Cloud poll sync error: $e');
    } finally {
      _cloudSyncInProgress = false;
    }
  }

  Future<void> silentRefreshAll() async {
    await _pollCloudState();
    unawaited(_loadUnreadMessages());
  }

  void _startRealTimeUpdates() {
    _vitalsTimer?.cancel();
    _cloudPollTimer?.cancel();

    // Simulated vitals drift for online patients
    _vitalsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      for (final p in _patients) {
        if (p.deviceStatus == 'Offline' || p.deviceId.isNotEmpty) continue;
        p.heartRate = (p.heartRate + _rand.nextInt(5) - 2).clamp(50, 160);
        p.spo2 = (p.spo2 + _rand.nextInt(3) - 1).clamp(88, 100);
        p.temperature =
            double.parse((p.temperature + (_rand.nextDouble() * 0.2 - 0.1))
                .clamp(97.0, 102.0)
                .toStringAsFixed(1));
        p.steps += _rand.nextInt(10);
        _evaluatePatientVitals(p);
      }
      notifyListeners();
    });

    // Fallback polling keeps dashboard, patients, and alerts updated even if
    // Supabase realtime is delayed in the browser.
    _cloudPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollCloudState();
    });

    // ── Patients realtime (INSERT / UPDATE / DELETE) ──
    _patientsChannel = _supabase
        .channel('patients_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'patients',
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              final patient = _patientFromRow(row);
              _patients.add(patient);
              _evaluatePatientVitals(patient);
              notifyListeners();
            } else if (event == PostgresChangeEvent.update) {
              final row = payload.newRecord;
              final idx = _patients.indexWhere((p) => p.id == row['id']);
              if (idx != -1) {
                _patients[idx] = _patientFromRow(row);
                _evaluatePatientVitals(_patients[idx]);
                notifyListeners();
              }
            } else if (event == PostgresChangeEvent.delete) {
              final old = payload.oldRecord;
              _patients.removeWhere((p) => p.id == old['id']);
              notifyListeners();
            }
          },
        )
        .subscribe();

    // ── Alerts realtime (INSERT / UPDATE / DELETE) ──
    _alertsChannel = _supabase
        .channel('alerts_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              final alert = _alertFromRow(row);
              _alerts.insert(0, alert);
              notifyListeners();
              // Send email for critical / SOS alerts
              if (emailNotifications && (alert.severity == 'critical' || alert.severity == 'sos')) {
                _sendCriticalAlertEmail(alert);
              }
            } else if (event == PostgresChangeEvent.update) {
              final row = payload.newRecord;
              final idx = _alerts.indexWhere((a) => a.id == row['id']);
              if (idx != -1) {
                _alerts[idx] = _alertFromRow(row);
                notifyListeners();
              }
            } else if (event == PostgresChangeEvent.delete) {
              final old = payload.oldRecord;
              _alerts.removeWhere((a) => a.id == old['id']);
              notifyListeners();
            }
          },
        )
        .subscribe();

    // ── Devices realtime (INSERT / UPDATE / DELETE) ──
    _devicesChannel = _supabase
        .channel('devices_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              _devices.add(_deviceFromRow(row));
              notifyListeners();
            } else if (event == PostgresChangeEvent.update) {
              final row = payload.newRecord;
              final idx = _devices.indexWhere((d) => d.id == row['id']);
              if (idx != -1) {
                _devices[idx] = _deviceFromRow(row);
                notifyListeners();
              }
            } else if (event == PostgresChangeEvent.delete) {
              final old = payload.oldRecord;
              _devices.removeWhere((d) => d.id == old['id']);
              notifyListeners();
            }
          },
        )
        .subscribe();

    // ── Messages realtime for badge ──
    _initMessagesChannel();
  }

  void _initMessagesChannel() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    _messagesChannel = _supabase
        .channel('messages_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg['receiver_id'] == myId && newMsg['is_read'] == false) {
              _unreadMessages++;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  // ─── Row → Model helpers ─────────────────────────────────────────────────
  Patient _patientFromRow(Map<String, dynamic> row) => Patient(
    id: row['id'] ?? '',
    name: row['name'] ?? '',
    age: row['age'] ?? 0,
    condition: row['condition'] ?? '',
    riskLevel: row['risk_level'] ?? 'Medium',
    deviceStatus: row['device_status'] ?? 'Offline',
    lastSync: row['last_sync'] ?? 'N/A',
    deviceId: row['device_id'] ?? '',
    heartRate: row['heart_rate'] ?? 75,
    spo2: row['spo2'] ?? 97,
    temperature: (row['temperature'] ?? 98.2).toDouble(),
    steps: row['steps'] ?? 0,
    notes: row['notes'] ?? '',
    humidity: (row['humidity'] ?? 0).toDouble(),
    eco2: row['eco2'] ?? 400,
    tvoc: row['tvoc'] ?? 0,
    ambientTemp: (row['ambient_temp'] ?? 0).toDouble(),
  );

  AlertModel _alertFromRow(Map<String, dynamic> row) => AlertModel(
    id: row['id'] ?? '',
    title: row['title'] ?? '',
    patient: row['patient'] ?? '',
    severity: row['severity'] ?? 'warning',
    status: row['status'] ?? 'new',
    timestamp: row['timestamp'] ?? 'Just now',
    value: row['value'] ?? '',
  );

  DeviceModel _deviceFromRow(Map<String, dynamic> row) => DeviceModel(
    id: row['id'] ?? '',
    name: row['name'] ?? 'ESP32 SmartWatch',
    patientName: row['patient_name'] ?? '',
    status: row['status'] ?? 'Offline',
    battery: row['battery'] ?? 100,
    lastSync: row['last_sync'] ?? 'N/A',
    firmware: row['firmware'] ?? 'v2.1.0',
  );

  void _evaluatePatientVitals(Patient patient) {
    if (patient.deviceStatus != 'Online') return;

    final linked = patient.deviceId.trim().isNotEmpty;
    if (linked && !_linkedPatientNotified.contains(patient.id)) {
      _linkedPatientNotified.add(patient.id);
      _createAutoAlert(
        patient,
        keySuffix: 'connected',
        title: 'Patient connected to smartwatch',
        severity: 'warning',
        value: '${patient.name} is now linked to ${patient.deviceId}.',
      );
    } else if (!linked) {
      _linkedPatientNotified.remove(patient.id);
    }

    if (patient.heartRate >= 120 || patient.heartRate <= 50) {
      _createAutoAlert(
        patient,
        keySuffix: 'heart-critical',
        title: 'Critical heart rate detected',
        severity: 'critical',
        value: 'Heart rate is ${patient.heartRate} bpm.',
      );
    } else if (patient.heartRate >= 110 || patient.heartRate <= 55) {
      _createAutoAlert(
        patient,
        keySuffix: 'heart-warning',
        title: 'Heart rate warning',
        severity: 'warning',
        value: 'Heart rate is ${patient.heartRate} bpm.',
      );
    }

    if (patient.spo2 < 90) {
      _createAutoAlert(
        patient,
        keySuffix: 'spo2-critical',
        title: 'Critical SpO2 detected',
        severity: 'critical',
        value: 'SpO2 dropped to ${patient.spo2}%.',
      );
    } else if (patient.spo2 < 94) {
      _createAutoAlert(
        patient,
        keySuffix: 'spo2-warning',
        title: 'Low SpO2 warning',
        severity: 'warning',
        value: 'SpO2 is ${patient.spo2}%.',
      );
    }

    if (patient.temperature >= 101.0 || patient.temperature <= 95.5) {
      _createAutoAlert(
        patient,
        keySuffix: 'temp-critical',
        title: 'Critical temperature detected',
        severity: 'critical',
        value: 'Temperature is ${patient.temperature.toStringAsFixed(1)}°F.',
      );
    } else if (patient.temperature >= 99.5) {
      _createAutoAlert(
        patient,
        keySuffix: 'temp-warning',
        title: 'Temperature warning',
        severity: 'warning',
        value: 'Temperature is ${patient.temperature.toStringAsFixed(1)}°F.',
      );
    }

    if (patient.eco2 > 2000) {
      _createAutoAlert(
        patient,
        keySuffix: 'co2-critical',
        title: 'Dangerous CO2 level detected',
        severity: 'critical',
        value: 'eCO2 is ${patient.eco2} ppm — immediate ventilation needed.',
      );
    } else if (patient.eco2 > 1000) {
      _createAutoAlert(
        patient,
        keySuffix: 'co2-warning',
        title: 'Elevated CO2 warning',
        severity: 'warning',
        value: 'eCO2 is ${patient.eco2} ppm — consider ventilation.',
      );
    }
  }

  Future<void> _createAutoAlert(
    Patient patient, {
    required String keySuffix,
    required String title,
    required String severity,
    required String value,
  }) async {
    final now = DateTime.now();
    final key = '${patient.id}::$keySuffix';
    final lastSent = _lastAutoAlertAt[key];
    if (lastSent != null && now.difference(lastSent) < const Duration(minutes: 2)) {
      return;
    }
    _lastAutoAlertAt[key] = now;

    try {
      await _supabase.from('alerts').insert({
        'id': 'AUTO-${patient.id}-${now.millisecondsSinceEpoch}',
        'title': title,
        'patient': patient.name,
        'severity': severity,
        'status': 'new',
        'timestamp': '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'value': value,
      });
    } catch (e) {
      debugPrint('Error creating automatic alert: $e');
    }
  }

  @override
  void dispose() {
    _vitalsTimer?.cancel();
    _cloudPollTimer?.cancel();
    _alertsChannel?.unsubscribe();
    _patientsChannel?.unsubscribe();
    _devicesChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _syncDeviceAssignment(Patient patient) async {
    if (patient.deviceId.trim().isEmpty) return;
    try {
      await _supabase.from('devices').update({
        'patient_name': patient.name,
      }).eq('id', patient.deviceId.trim());
    } catch (e) {
      debugPrint('Error syncing device assignment: $e');
    }
  }

  // ─── Patient CRUD ─────────────────────────────────────────────────────────
  Future<void> addPatient(Patient patient) async {
    _patients.add(patient);
    notifyListeners();
    try {
      await _supabase.from('patients').upsert({
        'id': patient.id,
        'name': patient.name,
        'age': patient.age,
        'condition': patient.condition,
        'risk_level': patient.riskLevel,
        'device_status': patient.deviceStatus,
        'last_sync': patient.lastSync,
        'device_id': patient.deviceId,
        'heart_rate': patient.heartRate,
        'spo2': patient.spo2,
        'temperature': patient.temperature,
        'steps': patient.steps,
        'notes': patient.notes,
      });
      await _syncDeviceAssignment(patient);
    } catch (e) {
      debugPrint('Error saving patient to Supabase: $e');
    }
  }

  Future<void> updatePatient(String id, Patient updated) async {
    final idx = _patients.indexWhere((p) => p.id == id);
    final previousDeviceId = idx != -1 ? _patients[idx].deviceId.trim() : '';
    if (idx != -1) {
      _patients[idx] = updated;
      notifyListeners();
    }
    try {
      await _supabase.from('patients').update({
        'name': updated.name,
        'age': updated.age,
        'condition': updated.condition,
        'risk_level': updated.riskLevel,
        'device_status': updated.deviceStatus,
        'last_sync': updated.lastSync,
        'device_id': updated.deviceId,
        'heart_rate': updated.heartRate,
        'spo2': updated.spo2,
        'temperature': updated.temperature,
        'steps': updated.steps,
        'notes': updated.notes,
      }).eq('id', id);

      if (previousDeviceId.isNotEmpty && previousDeviceId != updated.deviceId.trim()) {
        await _supabase.from('devices').update({'patient_name': ''}).eq('id', previousDeviceId);
      }
      await _syncDeviceAssignment(updated);
    } catch (e) {
      debugPrint('Error updating patient in Supabase: $e');
    }
  }

  Future<void> removePatient(String id) async {
    final removed = _patients.where((p) => p.id == id).toList();
    final removedDeviceId = removed.isNotEmpty ? removed.first.deviceId.trim() : '';
    _patients.removeWhere((p) => p.id == id);
    notifyListeners();
    try {
      await _supabase.from('patients').delete().eq('id', id);
      if (removedDeviceId.isNotEmpty) {
        await _supabase.from('devices').update({'patient_name': ''}).eq('id', removedDeviceId);
      }
    } catch (e) {
      debugPrint('Error removing patient from Supabase: $e');
    }
  }

  String _nextPatientId() {
    final nums = _patients
        .map((p) => int.tryParse(p.id.replaceAll('P', '')) ?? 0)
        .toList();
    final max = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
    return 'P${(max + 1).toString().padLeft(3, '0')}';
  }

  Patient buildNewPatient({
    required String name,
    required int age,
    required String condition,
    required String riskLevel,
    String deviceId = '',
    String notes = '',
  }) {
    return Patient(
      id: _nextPatientId(),
      name: name,
      age: age,
      condition: condition,
      riskLevel: riskLevel,
      deviceStatus: deviceId.isNotEmpty ? 'Offline' : 'Online',
      lastSync: deviceId.isNotEmpty ? 'Waiting for device...' : 'Just now',
      deviceId: deviceId,
      heartRate: 75 + _rand.nextInt(20),
      spo2: 95 + _rand.nextInt(5),
      temperature: 98.2,
      steps: 0,
      notes: notes,
    );
  }

  // ─── Alert actions ────────────────────────────────────────────────────────
  Future<void> acknowledgeAlert(String id) async {
    final alert = _alerts.firstWhere((a) => a.id == id, orElse: () => throw StateError('Not found'));
    alert.status = 'in-progress';
    notifyListeners();
    try {
      await _supabase.from('alerts').update({'status': 'in-progress'}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating alert: $e');
    }
  }

  Future<void> escalateAlert(String id) async {
    final alert = _alerts.firstWhere((a) => a.id == id, orElse: () => throw StateError('Not found'));
    alert.status = 'escalated';
    notifyListeners();
    try {
      await _supabase.from('alerts').update({'status': 'escalated'}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating alert: $e');
    }
  }

  Future<void> resolveAlert(String id) async {
    final alert = _alerts.firstWhere((a) => a.id == id, orElse: () => throw StateError('Not found'));
    alert.status = 'resolved';
    notifyListeners();
    try {
      await _supabase.from('alerts').update({'status': 'resolved'}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating alert: $e');
    }
  }

  void markAllAlertsRead() {
    for (final a in _alerts) {
      if (a.status == 'new') a.status = 'in-progress';
    }
    notifyListeners();
    _supabase
        .from('alerts')
        .update({'status': 'in-progress'})
        .eq('status', 'new')
        .then((_) {})
        .catchError((e) { debugPrint('Error marking alerts read: $e'); return null; });
  }

  // ─── Device actions ───────────────────────────────────────────────────────
  Future<void> updateFirmware(String deviceId) async {
    final d = _devices.firstWhere((d) => d.id == deviceId, orElse: () => throw StateError('Not found'));
    d.firmware = 'v2.1.1';
    d.logs.insert(0, 'Firmware updated to v2.1.1 — Just now');
    notifyListeners();
    try {
      await _supabase.from('devices').update({'firmware': 'v2.1.1'}).eq('id', deviceId);
    } catch (e) {
      debugPrint('Error updating device firmware: $e');
    }
  }

  Future<void> unpairDevice(String deviceId) async {
    _devices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
    try {
      await _supabase.from('devices').delete().eq('id', deviceId);
    } catch (e) {
      debugPrint('Error removing device: $e');
    }
  }

  // ─── Email sending via Supabase Edge Function (Gmail SMTP) ────────────────
  Future<bool> _sendCriticalAlertEmail(AlertModel alert) async {
    if (_alertEmail.isEmpty) {
      debugPrint('Alert email not configured — skipping email notification');
      return false;
    }
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')} on ${now.month}/${now.day}/${now.year}';
      final url = '${SupabaseConfig.url}/functions/v1/send-alert-email';
      final payload = jsonEncode({
        'to_email': _alertEmail,
        'patient_name': alert.patient,
        'alert_title': alert.title,
        'alert_value': alert.value,
        'alert_severity': alert.severity.toUpperCase(),
        'alert_time': timeStr,
      });
      final req = html.HttpRequest();
      req.open('POST', url);
      req.setRequestHeader('Content-Type', 'application/json');
      req.setRequestHeader('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
      req.send(payload);
      await req.onLoadEnd.first;
      debugPrint('Edge function response: ${req.status} ${req.responseText}');
      if (req.status != null && req.status! >= 200 && req.status! < 300) {
        debugPrint('Critical alert email sent to $_alertEmail via Gmail SMTP');
        return true;
      } else {
        debugPrint('Edge function error ${req.status}: ${req.responseText}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending alert email: $e');
      return false;
    }
  }

  /// Called from Settings → Send Test Email button
  Future<bool> sendTestAlertEmail() {
    return _sendCriticalAlertEmail(AlertModel(
      id: 'TEST',
      title: 'Test Critical Alert',
      patient: 'Test Patient',
      severity: 'critical',
      status: 'new',
      timestamp: 'Just now',
      value: 'Heart Rate: 145 bpm',
    ));
  }

  // ─── Settings actions ─────────────────────────────────────────────────────
  void setEmailNotifications(bool value) {
    emailNotifications = value;
    html.window.localStorage['emailNotifications'] = value.toString();
    notifyListeners();
  }

  void setSmsNotifications(bool value) {
    smsNotifications = value;
    html.window.localStorage['smsNotifications'] = value.toString();
    notifyListeners();
  }

  void setAlertThreshold(String value) {
    alertThreshold = value;
    html.window.localStorage['alertThreshold'] = value;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    html.window.localStorage['darkMode'] = value.toString();
    notifyListeners();
  }

  void setAlertEmail(String email) {
    _alertEmail = email;
    html.window.localStorage['alertEmail'] = email;
    notifyListeners();
  }

  void factoryReset() {
    emailNotifications = true;
    smsNotifications = false;
    alertThreshold = 'medium';
    _darkMode = false;
    _alertEmail = '';
    for (final k in ['emailNotifications','smsNotifications','alertThreshold',
        'darkMode','alertEmail']) {
      html.window.localStorage.remove(k);
    }
    notifyListeners();
  }

  // ─── Global search ────────────────────────────────────────────────────────
  void setGlobalSearch(String query) {
    globalSearch = query;
    notifyListeners();
  }
}
