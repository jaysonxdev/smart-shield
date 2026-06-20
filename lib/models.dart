// lib/models.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'functions/virustotal.dart';

enum Risk { low, medium, high }

class ScanItem {
  final String id;
  final String title;
  final String subtitle;
  final Risk risk;
  final DateTime time;
  final String? path;

  ScanItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.time,
    this.path,
  });
}

class JunkFile {
  final String name;
  final String path;
  final int sizeBytes;
  final String reason;

  JunkFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.reason,
  });

  String get sizeReadable {
    if (sizeBytes > 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (sizeBytes > 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes > 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '$sizeBytes B';
  }
}

class MockData {
  static List<String> foldersToScan = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Telegram',
    '/storage/emulated/0/Telegram/Telegram Documents',
    '/storage/emulated/0/Telegram/Telegram Video',
    '/storage/emulated/0/Bluetooth',
  ];

  static const List<String> junkFoldersToScan = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/WhatsApp/Media',
    '/storage/emulated/0/Telegram',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/.thumbnails',
    '/storage/emulated/0/LOST.DIR',
    '/storage/emulated/0/Android/media',
  ];
}

class ScanRecord {
  final DateTime time;
  final int totalScanned;
  final int flagged;

  ScanRecord({
    required this.time,
    required this.totalScanned,
    required this.flagged,
  });

  Map<String, dynamic> toJson() => {
    'time': time.millisecondsSinceEpoch,
    'totalScanned': totalScanned,
    'flagged': flagged,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
    totalScanned: json['totalScanned'] as int,
    flagged: json['flagged'] as int,
  );
}

class ScanHistoryService {
  static const _key = 'scan_history';
  static const _maxRecords = 20;

  static Future<List<ScanRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => ScanRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addRecord(ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(record.toJson()));
    if (raw.length > _maxRecords) raw.removeLast();
    await prefs.setStringList(_key, raw);
  }
}

class ScanController {
  bool scanning = false;
  double progress = 0.0;
  String? currentFile;
  bool cancelRequested = false;
  int totalScanned = 0;
  int vtCountdown = 0;
  final List<ScanItem> alerts = [];
  List<JunkFile> junkFiles = [];
  int get totalJunkBytes => junkFiles.fold(0, (sum, f) => sum + f.sizeBytes);
  String get totalJunkReadable {
    final bytes = totalJunkBytes;
    if (bytes > 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Future<void> scanJunk(VoidCallback onUpdate) async {
    junkFiles.clear();
    for (final folderPath in MockData.junkFoldersToScan) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is! File) continue;
        try {
          final name = ent.path.split('/').last.toLowerCase();
          final size = await ent.length();
          final ext = name.contains('.') ? '.${name.split('.').last}' : '';
          if (['.tmp', '.temp', '.log', '.bak'].contains(ext)) {
            junkFiles.add(
              JunkFile(
                name: ent.path.split('/').last,
                path: ent.path,
                sizeBytes: size,
                reason: 'Temporary file',
              ),
            );
          } else if (ext == '.apk') {
            junkFiles.add(
              JunkFile(
                name: ent.path.split('/').last,
                path: ent.path,
                sizeBytes: size,
                reason: 'Leftover APK installer',
              ),
            );
          } else if (size > 100 * 1024 * 1024) {
            junkFiles.add(
              JunkFile(
                name: ent.path.split('/').last,
                path: ent.path,
                sizeBytes: size,
                reason:
                    'Large file (${(size / (1024 * 1024)).toStringAsFixed(0)} MB)',
              ),
            );
          }
        } catch (_) {}
      }
    }
    onUpdate();
  }

  void addAlertFromScan(
    String title,
    String subtitle,
    Risk risk, {
    String? path,
  }) {
    alerts.insert(
      0,
      ScanItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        subtitle: subtitle,
        risk: risk,
        time: DateTime.now(),
        path: path,
      ),
    );
  }

  Future<void> startScan(VoidCallback onUpdate) async {
    if (scanning) return;
    scanning = true;
    progress = 0;
    currentFile = null;
    cancelRequested = false;
    totalScanned = 0;
    vtCountdown = 0;
    onUpdate();

    int flaggedThisScan = 0;
    final List<File> files = [];

    for (final folderPath in MockData.foldersToScan) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (cancelRequested) break;
        if (ent is File) files.add(ent);
      }
    }

    final total = files.isEmpty ? 1 : files.length;

    for (int i = 0; i < files.length; i++) {
      if (cancelRequested) break;

      final f = files[i];
      currentFile = f.path.split('/').last;
      progress = (i + 1) / total;
      totalScanned++;
      onUpdate();

      final result = await checkFileWithVirusTotal(f);
      if (result != null) {
        addAlertFromScan(
          result.title,
          result.subtitle,
          result.risk,
          path: f.path,
        );
        flaggedThisScan++;
        onUpdate();
      }

      vtCountdown = 15;
      onUpdate();
      for (int t = 15; t > 0; t--) {
        await Future.delayed(const Duration(seconds: 1));
        if (cancelRequested) break;
        vtCountdown = t - 1;
        onUpdate();
      }
      if (!cancelRequested) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    scanning = false;
    progress = 1.0;
    currentFile = null;
    vtCountdown = 0;
    cancelRequested = false;
    await ScanHistoryService.addRecord(ScanRecord(
      time: DateTime.now(),
      totalScanned: totalScanned,
      flagged: flaggedThisScan,
    ));
    onUpdate();
  }

  void cancel(VoidCallback onUpdate) {
    cancelRequested = true;
    onUpdate();
  }

  void clearAlerts(VoidCallback onUpdate) {
    alerts.clear();
    onUpdate();
  }
}
