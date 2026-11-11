import 'dart:async';
import 'package:flutter/services.dart';

class ProximityService {
  static const MethodChannel _channel =
      MethodChannel('com.mozelabs.mozechat/proximity');

  static bool _isEnabled = false;
  static bool _isNear = false;

  static final StreamController<bool> _proximityStreamController =
      StreamController<bool>.broadcast();

  static Stream<bool> get proximityStream =>
      _proximityStreamController.stream;
  static bool get isNear => _isNear;
  static bool get isEnabled => _isEnabled;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProximityChanged') {
        final bool near = call.arguments == true;
        if (_isNear != near) {
          _isNear = near;
          _proximityStreamController.add(near);
        }
      }
    });
  }

  static Future<void> enable() async {
    if (_isEnabled) return;
    try {
      _isEnabled = true;
      await _channel.invokeMethod('enableProximity');
    } catch (_) {}
  }

  static Future<void> disable() async {
    if (!_isEnabled && !_isNear) return;
    try {
      _isEnabled = false;
      _isNear = false;
      _proximityStreamController.add(false);
      await _channel.invokeMethod('disableProximity');
    } catch (_) {}
  }

  /// Keeps the display awake (used during video calls where the screen must
  /// stay on and the proximity sensor must NOT turn it off).
  static Future<void> setKeepScreenOn(bool keepOn) async {
    try {
      await _channel.invokeMethod('keepScreenOn', keepOn);
    } catch (_) {}
  }
}

