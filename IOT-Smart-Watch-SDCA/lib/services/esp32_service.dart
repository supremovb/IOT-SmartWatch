import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/watch_data.dart';

/// Manages BLE, WiFi WebSocket, and USB Serial communication with ESP32-S3
class Esp32Service extends ChangeNotifier {
  // ── BLE ──
  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _charDataUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _dataChar;
  bool _bleConnected = false;

  // ── WiFi WebSocket ──
  WebSocketChannel? _wsChannel;
  bool _wsConnected = false;
  String _wsUrl = '';

  // ── State ──
  bool _sending = false;
  Timer? _syncTimer;
  int _currentScreen = 0;
  bool _disposed = false;

  // Getters
  bool get bleConnected => _bleConnected;
  bool get wsConnected => _wsConnected;
  bool get isConnected => _bleConnected || _wsConnected;
  String get wsUrl => _wsUrl;

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BLE CONNECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Scan for ESP32-SmartWatch BLE device and connect
  Future<bool> connectBLE() async {
    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('[BLE] Bluetooth not supported on this device');
        return false;
      }

      // Start scanning
      debugPrint('[BLE] Scanning for ESP32-SmartWatch...');
      final completer = Completer<bool>();

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          if (r.device.platformName == 'ESP32-SmartWatch') {
            debugPrint('[BLE] Found ESP32-SmartWatch!');
            FlutterBluePlus.stopScan();
            _connectToDevice(r.device).then((ok) {
              if (!completer.isCompleted) completer.complete(ok);
            });
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Wait for connection or timeout
      final connected = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );

      subscription.cancel();
      return connected;
    } catch (e) {
      debugPrint('[BLE] Error: $e');
      return false;
    }
  }

  Future<bool> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _bleDevice = device;

      // Discover services
      final services = await device.discoverServices();
      for (var svc in services) {
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
          for (var char in svc.characteristics) {
            if (char.uuid.toString().toLowerCase() == _charDataUuid) {
              _dataChar = char;
              break;
            }
          }
        }
      }

      if (_dataChar == null) {
        debugPrint('[BLE] Data characteristic not found');
        await device.disconnect();
        return false;
      }

      _bleConnected = true;
      _notifySafely();

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _bleConnected = false;
          _dataChar = null;
          _bleDevice = null;
          _notifySafely();
          debugPrint('[BLE] Disconnected');
        }
      });

      debugPrint('[BLE] Connected and ready');
      return true;
    } catch (e) {
      debugPrint('[BLE] Connection error: $e');
      return false;
    }
  }

  Future<void> disconnectBLE() async {
    await _bleDevice?.disconnect();
    _bleConnected = false;
    _dataChar = null;
    _bleDevice = null;
    _notifySafely();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIFI WEBSOCKET CONNECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Connect to ESP32 WebSocket server
  /// [ip] - ESP32's IP address (e.g., "192.168.1.100")
  /// [port] - WebSocket port (default: 81)
  Future<bool> connectWebSocket(String ip, {int port = 81}) async {
    try {
      _wsUrl = 'ws://$ip:$port';
      debugPrint('[WS] Connecting to $_wsUrl...');

      _wsChannel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _wsChannel!.ready;

      _wsConnected = true;
      _notifySafely();

      // Listen for messages from ESP32
      _wsChannel!.stream.listen(
        (data) {
          debugPrint('[WS] Received: $data');
        },
        onDone: () {
          _wsConnected = false;
          _wsChannel = null;
          _notifySafely();
          debugPrint('[WS] Disconnected');
        },
        onError: (err) {
          _wsConnected = false;
          _wsChannel = null;
          _notifySafely();
          debugPrint('[WS] Error: $err');
        },
      );

      debugPrint('[WS] Connected!');
      return true;
    } catch (e) {
      debugPrint('[WS] Connection error: $e');
      _wsConnected = false;
      _wsChannel = null;
      _notifySafely();
      return false;
    }
  }

  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsConnected = false;
    _wsChannel = null;
    _notifySafely();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA SYNC — Sends watch data to ESP32
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start periodic sync of watch data to ESP32
  void startSync(WatchController controller, {Duration interval = const Duration(seconds: 1)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      sendWatchData(controller);
    });
  }

  /// Stop periodic sync
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Set current screen index (syncs to ESP32)
  void setScreen(int screen) {
    _currentScreen = screen;
  }

  /// Send all watch data to ESP32 as compact JSON
  Future<void> sendWatchData(WatchController ctrl) async {
    if (_sending || !isConnected) return;
    _sending = true;

    try {
      final now = DateTime.now();
      final accentHex = ctrl.accentColor.toARGB32().toRadixString(16).substring(2); // Remove alpha

      // Build compact JSON payload
      final data = {
        't': ctrl.formatTime(now),
        'd': ctrl.formatDate(now),
        'ap': ctrl.amPm,
        'hr': ctrl.currentHeartRate,
        'st': ctrl.currentSteps,
        'sg': ctrl.dailyStepGoal,
        'bt': ctrl.batteryLevel,
        'tp': ctrl.weatherTemp,
        'wt': ctrl.weatherCondition,
        'sc': _currentScreen,
        'ur': ctrl.unreadCount,
        'tm': ctrl.countdownRemaining.inMinutes,
        'ts': ctrl.countdownRemaining.inSeconds % 60,
        'tr': ctrl.countdownRunning,
        'ac': accentHex,
        'nf': ctrl.notifications
            .take(5)
            .map((n) => {'t': n.title, 'b': n.body})
            .toList(),
      };

      final json = jsonEncode(data);

      // Send via BLE
      if (_bleConnected && _dataChar != null) {
        await _dataChar!.write(
          utf8.encode(json),
          withoutResponse: false,
        );
      }

      // Send via WebSocket
      if (_wsConnected && _wsChannel != null) {
        _wsChannel!.sink.add(json);
      }
    } catch (e) {
      debugPrint('[SYNC] Error: $e');
    } finally {
      _sending = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _disposed = true;
    stopSync();
    _wsChannel?.sink.close();
    _bleDevice?.disconnect();
    _bleConnected = false;
    _wsConnected = false;
    _dataChar = null;
    _bleDevice = null;
    _wsChannel = null;
    super.dispose();
  }
}
