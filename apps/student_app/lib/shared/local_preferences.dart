import 'dart:convert';
import 'package:flutter/services.dart';

/// Lưu trữ bền vững Client-side theo chuẩn `shared_preferences` (hỗ trợ cả MethodChannel native
/// và bộ nhớ đệm an toàn khi chạy kiểm thử hoặc môi trường không có plugin native).
class SharedPreferences {
  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  static final Map<String, Object> _memoryStore = <String, Object>{};
  static SharedPreferences? _instance;

  SharedPreferences._();

  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = SharedPreferences._();
    await prefs._reloadFromPlatform();
    _instance = prefs;
    return prefs;
  }

  static void setMockInitialValues(Map<String, Object> values) {
    _memoryStore
      ..clear()
      ..addAll(values);
    _instance = SharedPreferences._();
  }

  Future<void> _reloadFromPlatform() async {
    try {
      final Map<Object?, Object?>? all =
          await _channel.invokeMethod<Map<Object?, Object?>>('getAll');
      if (all != null) {
        for (final entry in all.entries) {
          final k = entry.key?.toString();
          final v = entry.value;
          if (k != null && v != null) {
            final cleanKey = k.startsWith('flutter.') ? k.substring(8) : k;
            _memoryStore[cleanKey] = v;
          }
        }
      }
    } catch (_) {
      // Môi trường test / Web / Desktop fallback dùng _memoryStore
    }
  }

  String? getString(String key) {
    final val = _memoryStore[key];
    return val is String ? val : null;
  }

  bool? getBool(String key) {
    final val = _memoryStore[key];
    return val is bool ? val : null;
  }

  Future<bool> setString(String key, String value) async {
    _memoryStore[key] = value;
    try {
      await _channel.invokeMethod<bool>('setString', <String, dynamic>{
        'key': 'flutter.$key',
        'value': value,
      });
    } catch (_) {}
    return true;
  }

  Future<bool> setBool(String key, bool value) async {
    _memoryStore[key] = value;
    try {
      await _channel.invokeMethod<bool>('setBool', <String, dynamic>{
        'key': 'flutter.$key',
        'value': value,
      });
    } catch (_) {}
    return true;
  }

  Future<bool> setJsonMap(String key, Map<String, dynamic> map) {
    return setString(key, jsonEncode(map));
  }

  Map<String, dynamic>? getJsonMap(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list) {
    return setString(key, jsonEncode(list));
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<bool> remove(String key) async {
    _memoryStore.remove(key);
    try {
      await _channel.invokeMethod<bool>('remove', <String, dynamic>{
        'key': 'flutter.$key',
      });
    } catch (_) {}
    return true;
  }

  Future<bool> clear() async {
    _memoryStore.clear();
    try {
      await _channel.invokeMethod<bool>('clear');
    } catch (_) {}
    return true;
  }
}

/// Tiện ích kết nối trình quay số khẩn cấp native trên thiết bị di động (S21 - R3)
class MindCheckDeviceLauncher {
  static const MethodChannel _deviceChannel =
      MethodChannel('mindcheck.campus/device');

  static Future<bool> dialEmergencyNumber(String phone) async {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^\d\+]'), '');
    if (cleaned.isEmpty) return false;
    try {
      final launched = await _deviceChannel.invokeMethod<bool>(
        'dialPhone',
        <String, dynamic>{'phone': cleaned},
      );
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }
}


