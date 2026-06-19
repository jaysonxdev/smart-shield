// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smartshield/scan_actions.dart';
import 'package:smartshield/models.dart';
import 'package:smartshield/screens/files_screen.dart';
import 'package:smartshield/screens/permission_chat_screen.dart';
import 'package:smartshield/screens/quarantine_screen.dart';
import 'package:smartshield/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smartshield/screens/threats_screen.dart';
import 'package:smartshield/screens/junk_screen.dart';
import 'package:smartshield/screens/about_screen.dart';
import 'package:smartshield/services/auto_scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('theme_is_dark') ?? true;
  SmartShieldApp.themeNotifier.value =
      isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const SmartShieldApp());
}

class SmartShieldApp extends StatelessWidget {
  const SmartShieldApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.dark);

  static ThemeData get _darkTheme => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5AA9FF),
          secondary: Color(0xFF00E6B8),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white70),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0F1116),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF22242A), width: 1),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            elevation: 8,
            shadowColor: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white70,
          displayColor: Colors.white70,
        ),
      );

  static ThemeData get _lightTheme => ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2F4F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A7FD4),
          secondary: Color(0xFF00A88A),
          surface: Color(0xFFFFFFFF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF444852)),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D23),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE0E3E8), width: 1),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A7FD4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            elevation: 8,
            shadowColor: const Color(0xFF1A7FD4).withValues(alpha: 0.3),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF444852),
          displayColor: const Color(0xFF1A1D23),
        ),
        dividerColor: const Color(0xFFE0E3E8),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, themeMode, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmartShield',
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: themeMode,
        home: SplashScreen(onComplete: () => const HomeScreen()),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScanController _ctrl = ScanController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _orbitController;

  bool _showBubble = false;
  double _bubbleOpacity = 0.0;
  Timer? _bubbleAutoHideTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    unawaited(AutoScanService.instance.init(_ctrl, () => setState(() {})));
    unawaited(_checkAndScheduleBubble());
  }

  @override
  void dispose() {
    AutoScanService.instance.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    _bubbleAutoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndScheduleBubble() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('ai_bubble_last_shown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneDayMs = 24 * 60 * 60 * 1000;
    if (now - lastShown < oneDayMs) return;

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    await prefs.setInt('ai_bubble_last_shown', now);
    setState(() => _showBubble = true);

    // One-frame gap so the widget enters the tree before opacity animates.
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    setState(() => _bubbleOpacity = 1.0);

    _bubbleAutoHideTimer = Timer(
      const Duration(seconds: 4),
      _dismissBubble,
    );
  }

  void _dismissBubble() {
    _bubbleAutoHideTimer?.cancel();
    if (!mounted || !_showBubble) return;
    setState(() => _bubbleOpacity = 0.0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showBubble = false);
    });
  }

  Widget _aiBubble() {
    return GestureDetector(
      onTap: _dismissBubble,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: context.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to assist you 👋',
              style: TextStyle(
                color: context.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close, size: 14, color: context.subtleText),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _riskColor(Risk r) {
    switch (r) {
      case Risk.low:
        return Colors.green;
      case Risk.medium:
        return Colors.orange;
      case Risk.high:
        return Colors.redAccent;
    }
  }

  PreferredSizeWidget _topAppBar() {
    return AppBar(
      titleSpacing: 12,
      title: Row(
        children: [
          Image.asset('assets/ui/logo.png', width: 28, height: 28),
          const SizedBox(width: 10),
          Text(
            'SmartShield',
            style: TextStyle(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Threat Monitor',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ThreatsScreen()),
            );
          },
          icon: const Icon(Icons.gpp_bad_outlined),
        ),
        IconButton(
          tooltip: 'Permission Monitor',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PermissionChatScreen()),
            );
          },
          icon: const Icon(Icons.security_outlined),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _bigScanCard(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Column(
          children: [
            const SizedBox(height: 4),
            const Text(
              'Device Scan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (_ctrl.scanning && _ctrl.vtCountdown > 0) ...[
              Text(
                'Checking "${_ctrl.currentFile ?? ''}" with VirusTotal',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_top_outlined,
                    size: 13,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free-tier rate limit — next file in ${_ctrl.vtCountdown}s',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _ctrl.vtCountdown / 15.0,
                  backgroundColor: context.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF5AA9FF),
                  ),
                  minHeight: 5,
                ),
              ),
            ] else ...[
              Text(
                _ctrl.scanning
                    ? 'Scanning — ${_ctrl.currentFile ?? "preparing..."}'
                    : 'No active scan',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 18),

            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha:0.02),
                          Colors.black.withValues(alpha:0.25),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha:0.03),
                          blurRadius: 28,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: context.scanCircleBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.shield_outlined,
                        size: 65,
                        color: context.scanAccentColor,
                      ),
                    ),
                  ),
                  if (_ctrl.scanning)
                    AnimatedBuilder(
                      animation: _orbitController,
                      builder: (context, _) {
                        final angle = _orbitController.value * 2 * math.pi;
                        const radius = 92.0;
                        final dx = radius * math.cos(angle);
                        final dy = radius * math.sin(angle);
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: context.scanAccentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.scanAccentColor
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _ctrl.scanning
                  ? null
                  : () async {
                      await handleScanButtonPress(
                        ctrl: _ctrl,
                        orbitController: _orbitController,
                        pulseController: _pulseController,
                        refresh: () => setState(() {}),
                        context: context,
                      );
                    },
              icon: const Icon(Icons.shield_outlined),
              label: Text(_ctrl.scanning ? 'Scanning...' : 'Scan Now'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanSummaryCard() {
    final suspiciousItems = _ctrl.alerts
        .where((a) => a.risk == Risk.medium || a.risk == Risk.high)
        .toList();
    final flagged = suspiciousItems.length;
    final hasData = _ctrl.totalScanned > 0;
    final accentColor =
        flagged > 0 ? Colors.orangeAccent : Colors.greenAccent.shade200;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilesScreen(
            title: 'Suspicious Files',
            items: suspiciousItems,
            color: Colors.orangeAccent,
            icon: Icons.error_outline,
          ),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  flagged > 0
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Scan',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasData
                          ? '${_ctrl.totalScanned} files checked, $flagged flagged'
                          : 'No scan run yet',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.subtleText.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigJunkCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JunkScreen(ctrl: _ctrl)),
      ),
      child: Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Junk Files',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _ctrl.junkFiles.isEmpty
                          ? 'Tap to scan'
                          : '${_ctrl.junkFiles.length} files found',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.delete_sweep_outlined,
                size: 34,
                color: context.subtleText.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quarantineCard() {
    final flagged = _ctrl.alerts
        .where((a) => a.risk == Risk.medium || a.risk == Risk.high)
        .toList();
    final hasThreats = flagged.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuarantineScreen(ctrl: _ctrl),
        ),
      ),
      child: Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quarantine',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasThreats
                          ? '${flagged.length} file${flagged.length == 1 ? '' : 's'} flagged'
                          : 'No threats found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: hasThreats ? Colors.redAccent : context.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.gpp_bad_outlined,
                size: 34,
                color: hasThreats
                    ? Colors.redAccent.withValues(alpha: 0.7)
                    : context.subtleText.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertsList() {
    if (_ctrl.alerts.isEmpty) {
      return const Center(child: Text('No alerts — your device looks safe'));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ctrl.alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _ctrl.alerts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _riskColor(item.risk).withValues(alpha:0.12),
              child: Icon(Icons.image, color: _riskColor(item.risk)),
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${item.subtitle} • ${_formatTime(item.time)}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: _riskColor(item.risk).withValues(alpha:0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.risk == Risk.low
                    ? 'Low'
                    : (item.risk == Risk.medium ? 'Medium' : 'High'),
                style: TextStyle(
                  color: _riskColor(item.risk),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(item.title),
                  content: Text(
                    'Detected as ${item.risk.name.toUpperCase()} risk.\n${item.subtitle}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _topAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          children: [
            _bigScanCard(context),
            const SizedBox(height: 16),
            _scanSummaryCard(),
            const SizedBox(height: 16),
            _bigJunkCard(),
            const SizedBox(height: 16),
            _quarantineCard(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton(onPressed: () {}, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 8),
            _alertsList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showBubble) ...[
            AnimatedOpacity(
              opacity: _bubbleOpacity,
              duration: const Duration(milliseconds: 400),
              child: _aiBubble(),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            onPressed: () {
              _dismissBubble();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PermissionChatScreen()),
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 12,
            child: const Icon(Icons.security_outlined),
          ),
        ],
      ),
    );
  }
}

// ------------------- Reusable InfoCard -------------------
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Opacity(
              opacity: 0.6,
              child: Icon(Icons.shield_outlined, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- Settings -------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _autoScan;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _autoScan = AutoScanService.instance.enabled;
    _isDark = SmartShieldApp.themeNotifier.value == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Functional toggles grouped together
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-scan downloads'),
                  subtitle: const Text(
                    'Watches Downloads and shared folders for new files and scans them automatically',
                  ),
                  value: _autoScan,
                  onChanged: (value) async {
                    await AutoScanService.instance.setEnabled(value);
                    setState(() => _autoScan = value);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  subtitle: const Text('Switch between dark and light appearance'),
                  value: _isDark,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('theme_is_dark', value);
                    SmartShieldApp.themeNotifier.value =
                        value ? ThemeMode.dark : ThemeMode.light;
                    setState(() => _isDark = value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // About — visually distinct closing section
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text(
                'App info and what SmartShield protects you from',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
