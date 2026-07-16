import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Permintaan izin mikrofon eksplisit (Android/iOS) sebelum STT.
class MicPermissionService {
  MicPermissionService._();

  static Future<MicPermissionResult> ensureGranted() async {
    if (kIsWeb) {
      return const MicPermissionResult(granted: true);
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return const MicPermissionResult(granted: true);
    }

    var status = await Permission.microphone.status;
    if (status.isGranted) {
      return const MicPermissionResult(granted: true);
    }

    if (status.isPermanentlyDenied) {
      return const MicPermissionResult(
        granted: false,
        permanentlyDenied: true,
        message:
            'Izin mikrofon diblokir. Buka Settings → Apps → ilb → Permissions → Microphone → Allow',
      );
    }

    status = await Permission.microphone.request();
    if (status.isGranted) {
      return const MicPermissionResult(granted: true);
    }

    if (status.isPermanentlyDenied) {
      return const MicPermissionResult(
        granted: false,
        permanentlyDenied: true,
        message:
            'Izin mikrofon diblokir. Buka Settings → Apps → ilb → Permissions → Microphone → Allow',
      );
    }

    return const MicPermissionResult(
      granted: false,
      message:
          'Izin mikrofon diperlukan. Tap Dengarkan lagi dan pilih Allow',
    );
  }
}

class MicPermissionResult {
  final bool granted;
  final bool permanentlyDenied;
  final String? message;

  const MicPermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
    this.message,
  });
}
