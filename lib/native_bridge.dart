import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _ch = MethodChannel('crypto_radar/native');

  static Future<void> _call(String m, [Map<String, dynamic>? args]) async {
    try {
      await _ch.invokeMethod<dynamic>(m, args);
    } catch (_) {}
  }

  static Future<void> requestPermission() => _call('requestPermission');
  static Future<void> notify(String title, String body) =>
      _call('notify', <String, dynamic>{'title': title, 'body': body});
  static Future<void> startService() => _call('startService');
  static Future<void> stopService() => _call('stopService');
}
