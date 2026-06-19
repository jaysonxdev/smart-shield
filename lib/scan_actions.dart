// lib/scan_actions.dart
import 'package:flutter/material.dart';
import 'models.dart';
import 'functions/permissions.dart';

/// Called from UI when Scan Now is pressed.
/// - starts orbit/pulse animations,
/// - runs ctrl.startScan(...) (which updates progress/currentFile),
/// - stops animations and shows a snackbar.
///
/// Keep this file focused on orchestration so main.dart stays clean.
Future<void> handleScanButtonPress({
  required ScanController ctrl,
  required AnimationController orbitController,
  required AnimationController pulseController,
  required VoidCallback refresh,
  required BuildContext context,
}) async {
  // 🔐 STEP 1: REQUEST STORAGE PERMISSION
  final hasPermission = await requestStoragePermission();

  if (!hasPermission) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'SmartShield needs storage access to scan downloaded files and protect you.',
        ),
      ),
    );
    return; // ⛔ Stop scan if permission not granted
  }

  try {
    // ▶ Start visuals
    orbitController.repeat();
    pulseController.repeat(reverse: true);
    refresh();

    // ▶ Run scan
    await ctrl.startScan(refresh);
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
  } finally {
    // ⏹ Stop animations
    orbitController.stop();
    orbitController.reset();
    pulseController.stop();
    pulseController.reset();
    refresh();

    // ✅ Final feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan complete — device checked for threats'),
      ),
    );
  }
}
