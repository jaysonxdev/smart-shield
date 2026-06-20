// lib/screens/threats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme_colors.dart';

class ThreatsScreen extends StatefulWidget {
  const ThreatsScreen({super.key});

  @override
  State<ThreatsScreen> createState() => _ThreatsScreenState();
}

class _ThreatsScreenState extends State<ThreatsScreen> {
  static const _channel = MethodChannel('com.smartshield/permissions');

  List<Map<String, dynamic>> _hiddenApps = [];
  List<Map<String, dynamic>> _adminApps = [];
  List<Map<String, dynamic>> _accessibilityApps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThreats();
  }

  Future<void> _loadThreats() async {
    try {
      final hidden = await _channel.invokeMethod('getHiddenApps');
      final admin = await _channel.invokeMethod('getDeviceAdminApps');
      final accessibility = await _channel.invokeMethod('getAccessibilityApps');

      setState(() {
        _hiddenApps = List<Map<String, dynamic>>.from(
          (hidden as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _adminApps = List<Map<String, dynamic>>.from(
          (admin as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _accessibilityApps = List<Map<String, dynamic>>.from(
          (accessibility as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.primaryText,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0
                  ? color.withValues(alpha:0.15)
                  : const Color(0xFF00E6B8).withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count > 0 ? '$count found' : 'Clean',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: count > 0 ? color : const Color(0xFF00E6B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _threatCard(
    String appName,
    String packageName,
    String detail,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha:0.12),
          child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
        ),
        title: Text(
          appName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              packageName,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(fontSize: 12, color: color.withValues(alpha:0.9)),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _cleanCard(String message) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00E6B8).withValues(alpha: 0.12),
          child: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF00E6B8),
            size: 20,
          ),
        ),
        title: Text(
          message,
          style: const TextStyle(color: Color(0xFF00E6B8), fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalThreats =
        _hiddenApps.length + _adminApps.length + _accessibilityApps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Monitor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: totalThreats > 0
                          ? Colors.redAccent.withValues(alpha:0.1)
                          : const Color(0xFF00E6B8).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: totalThreats > 0
                            ? Colors.redAccent.withValues(alpha:0.3)
                            : const Color(0xFF00E6B8).withValues(alpha:0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          totalThreats > 0
                              ? Icons.gpp_bad
                              : Icons.verified_user,
                          color: totalThreats > 0
                              ? Colors.redAccent
                              : const Color(0xFF00E6B8),
                          size: 36,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                totalThreats > 0
                                    ? '$totalThreats Potential Threats Found'
                                    : 'No Threats Detected',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: totalThreats > 0
                                      ? Colors.redAccent
                                      : const Color(0xFF00E6B8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalThreats > 0
                                    ? 'Review the apps below carefully'
                                    : 'Your device looks clean',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hidden apps section
                  _sectionHeader(
                    'Hidden Apps',
                    Icons.visibility_off,
                    Colors.redAccent,
                    _hiddenApps.length,
                  ),
                  if (_hiddenApps.isEmpty)
                    _cleanCard(
                      'No hidden apps with sensitive permissions found',
                    )
                  else
                    ..._hiddenApps.map(
                      (app) => _threatCard(
                        app['appName'] ?? 'Unknown',
                        app['packageName'] ?? '',
                        'Hidden app with: ${(app['sensitivePermissions'] as List).join(', ')}',
                        Colors.redAccent,
                      ),
                    ),

                  // Device admin section
                  _sectionHeader(
                    'Device Admin Apps',
                    Icons.admin_panel_settings,
                    Colors.orange,
                    _adminApps.length,
                  ),
                  if (_adminApps.isEmpty)
                    _cleanCard('No suspicious device admin apps found')
                  else
                    ..._adminApps.map(
                      (app) => _threatCard(
                        app['appName'] ?? 'Unknown',
                        app['packageName'] ?? '',
                        '⚠️ Has device administrator privileges — can resist uninstall',
                        Colors.orange,
                      ),
                    ),

                  // Accessibility section
                  _sectionHeader(
                    'Accessibility Services',
                    Icons.accessibility_new,
                    Colors.amber,
                    _accessibilityApps.length,
                  ),
                  if (_accessibilityApps.isEmpty)
                    _cleanCard('No suspicious accessibility services found')
                  else
                    ..._accessibilityApps.map(
                      (app) => _threatCard(
                        app['appName'] ?? 'Unknown',
                        app['packageName'] ?? '',
                        '⚠️ Can read everything on your screen — common spyware technique',
                        Colors.amber,
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
