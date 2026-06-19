// lib/functions/virustotal.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../models.dart';

/// Hashes a file and checks it against VirusTotal.
/// Returns a ScanItem if suspicious, null if clean or unknown.
Future<ScanItem?> checkFileWithVirusTotal(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final name = file.path.split('/').last;

    final response = await http.get(
      Uri.parse('https://www.virustotal.com/api/v3/files/$hash'),
      headers: {'x-apikey': dotenv.env['VIRUSTOTAL_API_KEY'] ?? ''},
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final stats = data['data']['attributes']['last_analysis_stats'];

    final int malicious = stats['malicious'] ?? 0;
    final int suspicious = stats['suspicious'] ?? 0;
    final int total =
        (stats['harmless'] ?? 0) +
        (stats['undetected'] ?? 0) +
        malicious +
        suspicious;

    if (malicious == 0 && suspicious == 0) return null;

    final Risk risk = malicious >= 3
        ? Risk.high
        : (malicious >= 1 || suspicious >= 2)
        ? Risk.medium
        : Risk.low;

    return ScanItem(
      id: hash,
      title: name,
      subtitle: '$malicious/$total engines flagged this file',
      risk: risk,
      time: DateTime.now(),
      path: file.path,
    );
  } catch (_) {
    return null;
  }
}
