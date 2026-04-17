import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manages the state and data for the smart watch application
class WatchController extends ChangeNotifier {
  // Heart Rate Data
  int _currentHeartRate = 72;
  List<int> _heartRateHistory = [72, 75, 70, 73, 71];

  // Steps Data
  int _currentSteps = 5234;
  int _dailyStepGoal = 10000;

  // Timer Data
  Duration _timerDuration = Duration.zero;
  bool _isTimerRunning = false;

  // Notifications
  List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'Message',
      body: 'You have a new message',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      icon: '💬',
    ),
    NotificationItem(
      title: 'Reminder',
      body: 'Take a break and stretch',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      icon: '⏰',
    ),
  ];

  // Settings
  bool _brightScreenEnabled = true;
  String _displayMode = 'Digital';

  // Unread Count
  int _unreadCount = 2;

  // Display settings
  Color _accentColor = const Color(0xFF00D4FF);
  bool _is24Hour = false;

  // Weather Data
  double _weatherTemp = 24.5;
  String _weatherCondition = 'Cloudy';
  double _weatherHigh = 26.0;
  double _weatherLow = 18.0;

  // Battery
  int _batteryLevel = 87;

  // Stopwatch
  Duration _stopwatchDuration = Duration.zero;
  bool _stopwatchRunning = false;
  List<Duration> _laps = [];
  Timer? _stopwatchTimer;
  Timer? _clockTimer;

  // Countdown
  Duration _countdownDuration = const Duration(minutes: 5);
  Duration _countdownRemaining = const Duration(minutes: 5);
  bool _countdownRunning = false;
  bool _countdownFinished = false;
  Timer? _countdownTimer;

  // Theme
  String _theme = 'cyan';

  static const Map<String, Color> themeColors = {
    'cyan': Color(0xFF00D4FF),
    'green': Color(0xFF00FF88),
    'pink': Color(0xFFFF2D6E),
    'orange': Color(0xFFFF8C00),
    'purple': Color(0xFFBB86FC),
  };

  // Weekly Data
  List<int> _weeklySteps = [5234, 8234, 6234, 9234, 7234, 10234, 8234];

  // Goals
  int _stepGoal = 10000;
  int _calorieGoal = 2000;
  double _distanceGoal = 10.0;

  WatchController() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Heart Rate Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  int get currentHeartRate => _currentHeartRate;

  List<int> get heartRateHistory => _heartRateHistory;

  void updateHeartRate(int newRate) {
    _currentHeartRate = newRate;
    _heartRateHistory.add(newRate);
    if (_heartRateHistory.length > 30) {
      _heartRateHistory.removeAt(0);
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Steps Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  int get currentSteps => _currentSteps;

  int get dailyStepGoal => _dailyStepGoal;

  double get stepsProgress =>
      _currentSteps > _dailyStepGoal
          ? 1.0
          : _currentSteps / _dailyStepGoal;

  void incrementSteps([int amount = 1]) {
    _currentSteps += amount;
    notifyListeners();
  }

  void resetSteps() {
    _currentSteps = 0;
    notifyListeners();
  }

  void setDailyStepGoal(int goal) {
    _dailyStepGoal = goal;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Timer Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  Duration get timerDuration => _timerDuration;

  bool get isTimerRunning => _isTimerRunning;

  void setTimerDuration(Duration duration) {
    if (!_isTimerRunning) {
      _timerDuration = duration;
      notifyListeners();
    }
  }

  void startTimer() {
    if (_timerDuration > Duration.zero) {
      _isTimerRunning = true;
      notifyListeners();
    }
  }

  void pauseTimer() {
    _isTimerRunning = false;
    notifyListeners();
  }

  void resetTimer() {
    _timerDuration = Duration.zero;
    _isTimerRunning = false;
    notifyListeners();
  }

  void tickTimer() {
    if (_isTimerRunning && _timerDuration > Duration.zero) {
      _timerDuration = _timerDuration - const Duration(seconds: 1);
      if (_timerDuration <= Duration.zero) {
        _isTimerRunning = false;
        _timerDuration = Duration.zero;
      }
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Notifications Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  List<NotificationItem> get notifications => _notifications;

  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void removeNotification(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Settings Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  bool get brightScreenEnabled => _brightScreenEnabled;

  String get displayMode => _displayMode;

  void toggleBrightScreen() {
    _brightScreenEnabled = !_brightScreenEnabled;
    notifyListeners();
  }

  void setDisplayMode(String mode) {
    _displayMode = mode;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Unread Count Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  int get unreadCount => _unreadCount;

  void updateUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  void decrementUnreadCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Display Settings Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  Color get accentColor => _accentColor;

  bool get is24Hour => _is24Hour;

  DateTime get now => DateTime.now();

  String get amPm {
    final now = DateTime.now();
    return now.hour < 12 ? 'AM' : 'PM';
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  void toggleTimeFormat() {
    _is24Hour = !_is24Hour;
    notifyListeners();
  }

  String formatTime(DateTime dateTime) {
    final hour = _is24Hour
        ? dateTime.hour.toString().padLeft(2, '0')
        : (dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12)
            .toString()
            .padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String formatSeconds(DateTime dateTime) {
    return dateTime.second.toString().padLeft(2, '0');
  }

  String formatDate(DateTime dateTime) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final dayOfWeek = days[dateTime.weekday - 1];
    final month = months[dateTime.month];
    return '$dayOfWeek, $month ${dateTime.day}';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Health Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  HealthData get health => HealthData(
    heartRate: _currentHeartRate,
    steps: _currentSteps,
    battery: _batteryLevel,
  );

  double get weatherTemp => _weatherTemp;

  String get weatherCondition => _weatherCondition;

  double get weatherHigh => _weatherHigh;

  double get weatherLow => _weatherLow;

  int get batteryLevel => _batteryLevel;

  void setWeather(double temp, String condition, double high, double low) {
    _weatherTemp = temp;
    _weatherCondition = condition;
    _weatherHigh = high;
    _weatherLow = low;
    notifyListeners();
  }

  void setBatteryLevel(int level) {
    _batteryLevel = level.clamp(0, 100);
    notifyListeners();
  }

  void markAllRead() {
    for (var notif in _notifications) {
      notif.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Stopwatch Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  Duration get stopwatchDuration => _stopwatchDuration;
  bool get stopwatchRunning => _stopwatchRunning;
  List<Duration> get laps => _laps;

  void startStopwatch() {
    _stopwatchRunning = true;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => tickStopwatch(),
    );
    notifyListeners();
  }

  void pauseStopwatch() {
    _stopwatchRunning = false;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
    notifyListeners();
  }

  void resetStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
    _stopwatchDuration = Duration.zero;
    _stopwatchRunning = false;
    _laps = [];
    notifyListeners();
  }

  void tickStopwatch() {
    if (_stopwatchRunning) {
      _stopwatchDuration = _stopwatchDuration + const Duration(milliseconds: 100);
      notifyListeners();
    }
  }

  void addLap() {
    _laps.add(_stopwatchDuration);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Countdown Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  Duration get countdownDuration => _countdownDuration;
  Duration get countdownRemaining => _countdownRemaining;
  bool get countdownRunning => _countdownRunning;
  bool get countdownFinished => _countdownFinished;

  void setCountdown(Duration duration) {
    if (!_countdownRunning) {
      _countdownDuration = duration;
      _countdownRemaining = duration;
      _countdownFinished = false;
      notifyListeners();
    }
  }

  void startCountdown() {
    if (_countdownRemaining > Duration.zero) {
      _countdownRunning = true;
      _countdownFinished = false;
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => tickCountdown(),
      );
      notifyListeners();
    }
  }

  void pauseCountdown() {
    _countdownRunning = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    notifyListeners();
  }

  void resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownDuration = const Duration(minutes: 5);
    _countdownRemaining = _countdownDuration;
    _countdownRunning = false;
    _countdownFinished = false;
    notifyListeners();
  }

  void tickCountdown() {
    if (_countdownRunning && _countdownRemaining > Duration.zero) {
      _countdownRemaining = _countdownRemaining - const Duration(seconds: 1);
      if (_countdownRemaining <= Duration.zero) {
        _countdownRunning = false;
        _countdownRemaining = Duration.zero;
        _countdownFinished = true;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Weekly Steps & Goals
  // ─────────────────────────────────────────────────────────────────────────────

  List<int> get weeklySteps => _weeklySteps;
  List<String> get weekDays => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int get stepGoal => _stepGoal;
  int get calorieGoal => _calorieGoal;
  double get distanceGoal => _distanceGoal;

  void setStepGoal(int goal) {
    _stepGoal = goal;
    notifyListeners();
  }

  void setCalorieGoal(int goal) {
    _calorieGoal = goal;
    notifyListeners();
  }

  void setDistanceGoal(double goal) {
    _distanceGoal = goal;
    notifyListeners();
  }

  void updateWeeklySteps(int dayIndex, int steps) {
    if (dayIndex >= 0 && dayIndex < _weeklySteps.length) {
      _weeklySteps[dayIndex] = steps;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Theme Getters & Setters
  // ─────────────────────────────────────────────────────────────────────────────

  String get theme => _theme;

  void setTheme(String themeName) {
    _theme = themeName;
    final color = themeColors[themeName];
    if (color != null) {
      _accentColor = color;
    }
    notifyListeners();
  }

  void toggle24Hour() {
    _is24Hour = !_is24Hour;
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

/// Represents a single notification
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  final String icon;
  final String app;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    this.icon = '🔔',
    this.isRead = false,
    this.app = 'System',
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String get time {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get message => body;
}

/// Represents health metrics for the smart watch
class HealthData {
  final int heartRate;
  final int steps;
  final int battery;
  final int calories;
  final double distance;
  final int sleepHours;
  final int sleepMinutes;
  final double bloodOxygen;

  HealthData({
    required this.heartRate,
    required this.steps,
    required this.battery,
    this.calories = 350,
    this.distance = 4,
    this.sleepHours = 7,
    this.sleepMinutes = 30,
    this.bloodOxygen = 98.0,
  });
}
