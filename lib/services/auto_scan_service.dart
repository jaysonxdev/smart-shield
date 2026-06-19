import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../functions/virustotal.dart';

class AutoScanService {
  static final AutoScanService _instance = AutoScanService._();
  static AutoScanService get instance => _instance;
  AutoScanService._();

  static const _prefKey = 'auto_scan_enabled';
  static const _rateLimitDelay = Duration(milliseconds: 15500);
  static const _pollInterval = Duration(seconds: 30);

  ScanController? _ctrl;
  VoidCallback? _onUpdate;
  bool _enabled = false;
  bool get enabled => _enabled;

  Timer? _pollTimer;
  final Set<String> _knownPaths = {};
  bool _processing = false;

  Future<void> init(ScanController ctrl, VoidCallback onUpdate) async {
    _ctrl = ctrl;
    _onUpdate = onUpdate;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    if (_enabled) _startWatching();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      _startWatching();
    } else {
      _stopWatching();
    }
  }

  void _startWatching() {
    _pollTimer?.cancel();
    // Seed existing files first so we only react to genuinely new arrivals.
    _seedKnownFiles().then((_) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollForNewFiles());
    });
  }

  void _stopWatching() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _seedKnownFiles() async {
    for (final folderPath in MockData.foldersToScan) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File) _knownPaths.add(ent.path);
      }
    }
  }

  Future<void> _pollForNewFiles() async {
    if (_processing || _ctrl == null) return;
    _processing = true;

    try {
      final newFiles = <File>[];
      for (final folderPath in MockData.foldersToScan) {
        final dir = Directory(folderPath);
        if (!await dir.exists()) continue;
        await for (final ent in dir.list(recursive: true, followLinks: false)) {
          if (ent is File && !_knownPaths.contains(ent.path)) {
            _knownPaths.add(ent.path);
            newFiles.add(ent);
          }
        }
      }

      for (final file in newFiles) {
        final result = await checkFileWithVirusTotal(file);
        if (result != null && _ctrl != null) {
          _ctrl!.alerts.insert(0, result);
          _onUpdate?.call();
        }
        // Respect VirusTotal free-tier rate limit between each file check.
        await Future.delayed(_rateLimitDelay);
      }
    } finally {
      _processing = false;
    }
  }

  void dispose() {
    _stopWatching();
    _ctrl = null;
    _onUpdate = null;
  }
}
