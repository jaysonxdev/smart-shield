import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import '../models.dart';
import '../theme_colors.dart';

class ThreatWarningScreen extends StatefulWidget {
  final ScanItem item;
  final VoidCallback? onDeleted;

  const ThreatWarningScreen({
    super.key,
    required this.item,
    this.onDeleted,
  });

  @override
  State<ThreatWarningScreen> createState() => _ThreatWarningScreenState();
}

class _ThreatWarningScreenState extends State<ThreatWarningScreen> {
  static const _channel = MethodChannel('com.smartshield/permissions');
  late final bool _isApk;
  bool? _hasScamPerms;

  @override
  void initState() {
    super.initState();
    _isApk = (widget.item.path?.toLowerCase() ?? '').endsWith('.apk');
    if (_isApk) _checkApkPermissions();
  }

  Future<void> _checkApkPermissions() async {
    try {
      final result = await _channel.invokeMethod('getAppPermissions');
      final raw = result as List<dynamic>;

      final filename = widget.item.title
          .toLowerCase()
          .replaceAll('.apk', '')
          .trim();

      for (final e in raw) {
        final map = Map<String, dynamic>.from(e as Map);
        final appName = (map['appName'] ?? '').toString().toLowerCase();
        final pkgName = (map['packageName'] ?? '').toString().toLowerCase();

        final matched = appName == filename ||
            pkgName == filename ||
            pkgName.endsWith('.$filename') ||
            appName.contains(filename);

        if (matched) {
          final perms = List<String>.from(map['permissions'] ?? [])
              .map((p) => p.toLowerCase())
              .toList();
          final danger = perms.any((p) =>
              p.contains('sms') ||
              p.contains('accessibility') ||
              p.contains('call log'));
          if (mounted) setState(() => _hasScamPerms = danger);
          return;
        }
      }
      if (mounted) setState(() => _hasScamPerms = false);
    } catch (_) {
      if (mounted) setState(() => _hasScamPerms = false);
    }
  }

  Color get _riskColor =>
      widget.item.risk == Risk.high ? Colors.redAccent : Colors.orange;

  String get _riskLabel =>
      widget.item.risk == Risk.high ? 'HIGH RISK' : 'SUSPICIOUS';

  Future<void> _deleteFile() async {
    final path = widget.item.path;
    if (path == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this file?'),
        content: Text(
          '${widget.item.title} will be permanently deleted from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Defense-in-depth: refuse to act on paths outside the known scan directories.
    final isAllowed = MockData.foldersToScan.any((dir) => path.startsWith('$dir/'));
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This file is outside SmartShield\'s scan area and cannot be deleted here.',
          ),
        ),
      );
      return;
    }

    final file = File(path);

    // File may have been moved or already deleted externally.
    if (!await file.exists()) {
      widget.onDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File no longer exists — it may have already been removed.'),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      await file.delete();
      widget.onDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully.')),
        );
        Navigator.pop(context);
      }
    } on FileSystemException catch (e) {
      if (!mounted) return;
      // OS error 13 = EACCES (permission denied).
      final isPermissionDenied = e.osError?.errorCode == 13;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPermissionDenied
                ? 'SmartShield doesn\'t have permission to delete this file. '
                    'Open your Files app and delete it from there.'
                : 'Could not delete the file — it may have been moved or is currently in use.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong while deleting the file. Please try again.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _openAnyway() async {
    final path = widget.item.path;
    if (path == null) return;
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Warning icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _riskColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 58,
                  color: _riskColor,
                ),
              ),

              const SizedBox(height: 20),

              // Risk badge
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _riskColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _riskLabel,
                  style: TextStyle(
                    color: _riskColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Text(
                'This file looks dangerous.\nDo not open it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 22),

              // Filename chip
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 16,
                      color: context.subtleText,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.item.title,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.item.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.subtleText, fontSize: 13),
              ),

              // Scam-specific warning — only shown for APKs with matching dangerous permissions
              if (_isApk && _hasScamPerms == true) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.crisis_alert,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This app is trying to access your text messages '
                          'and accessibility settings — this is a common scam '
                          'tactic used to steal banking information.',
                          style: TextStyle(
                            color: context.primaryText,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Delete — large and prominent
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _deleteFile,
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text(
                    'Delete This File',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Open anyway — deliberately de-emphasised
              GestureDetector(
                onTap: _openAnyway,
                child: Text(
                  'I understand the risk, open anyway',
                  style: TextStyle(
                    color: context.subtleText,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: context.subtleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
