import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric (fingerprint / face) with fallback to the device PIN.
class AppLock {
  static final _auth = LocalAuthentication();

  static Future<bool> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (e) {
      debugPrint('auth failed: $e');
      return false;
    }
  }
}
