// lib/screens/permission_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme_colors.dart';

class AppPermissionInfo {
  final String appName;
  final String packageName;
  final List<String> permissions;
  final bool usedCameraRecently;
  final bool usedMicRecently;
  final bool usedLocationRecently;
  final bool isSystemApp;

  AppPermissionInfo({
    required this.appName,
    required this.packageName,
    required this.permissions,
    required this.usedCameraRecently,
    required this.usedMicRecently,
    required this.usedLocationRecently,
    required this.isSystemApp,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class PermissionChatScreen extends StatefulWidget {
  const PermissionChatScreen({super.key});

  @override
  State<PermissionChatScreen> createState() => _PermissionChatScreenState();
}

class _PermissionChatScreenState extends State<PermissionChatScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.smartshield/permissions');

  List<AppPermissionInfo> _apps = [];
  bool _loading = true;
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _aiThinking = false;
  late TabController _tabController;

  List<AppPermissionInfo> get _myApps =>
      _apps.where((a) => !a.isSystemApp).toList();
  List<AppPermissionInfo> get _systemApps =>
      _apps.where((a) => a.isSystemApp).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApps();
    _messages.add(
      ChatMessage(
        text:
            'Hi! I can explain what permissions your apps are using and whether anything looks suspicious. Tap an app above or ask me anything!',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      final result = await _channel.invokeMethod('getAppPermissions');
      final List<dynamic> raw = result as List<dynamic>;
      setState(() {
        _apps = raw.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return AppPermissionInfo(
            appName: map['appName'] ?? '',
            packageName: map['packageName'] ?? '',
            permissions: List<String>.from(map['permissions'] ?? []),
            usedCameraRecently: map['usedCameraRecently'] ?? false,
            usedMicRecently: map['usedMicRecently'] ?? false,
            usedLocationRecently: map['usedLocationRecently'] ?? false,
            isSystemApp: map['isSystemApp'] ?? false,
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage(String text,
      {bool includeAppSummary = true}) async {
    if (text.trim().isEmpty) return;
    _chatController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _aiThinking = true;
    });

    _scrollToBottom();

    String userContent = text;
    if (includeAppSummary && _apps.isNotEmpty) {
      final lowerText = text.toLowerCase();
      final mentioned = _apps
          .where((a) => lowerText.contains(a.appName.toLowerCase()))
          .toList();

      if (mentioned.isNotEmpty) {
        // Full detail for any app the user specifically mentioned
        final details = mentioned.map((a) {
          final recentUse = [
            if (a.usedCameraRecently) 'camera',
            if (a.usedMicRecently) 'microphone',
            if (a.usedLocationRecently) 'location',
          ];
          return '${a.appName} (${a.isSystemApp ? "system" : "user-installed"}, '
              '${a.permissions.length} permissions: ${a.permissions.join(", ")}'
              '${recentUse.isNotEmpty ? "; recently used: ${recentUse.join(", ")}" : ""})';
        }).join('\n');

        // Summary-level info for everything else
        final otherSummary = _apps
            .where((a) => !mentioned.contains(a))
            .map((a) =>
                '${a.appName} (${a.permissions.length} perms, ${a.isSystemApp ? "system" : "user-installed"})')
            .join(', ');

        userContent = [
          if (otherSummary.isNotEmpty) 'Other installed apps: $otherSummary',
          'Full details for mentioned app(s):\n$details',
          'Question: $text',
        ].join('\n\n');
      } else {
        // No specific app mentioned — send summary only to keep tokens low
        final summary = _apps
            .map((a) =>
                '${a.appName} (${a.permissions.length} perms, ${a.isSystemApp ? "system" : "user-installed"})')
            .join(', ');
        userContent = 'Installed apps for context: $summary\n\nQuestion: $text';
      }
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${dotenv.env['GROQ_API_KEY'] ?? ''}',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a mobile security assistant inside SmartShield app. '
                      'You help users understand app permissions in plain simple English. '
                      'Be concise, friendly and clear.\n\n'
                      'IMPORTANT — only discuss app permissions, risk analysis, or specific apps when the user actually asks about them. '
                      'If the user sends a greeting, casual message, or small talk, respond briefly and naturally — do not proactively analyze, list, or summarize installed apps. '
                      'Wait for the user to ask a specific question before bringing up any app data.\n\n'
                      'App data includes an isSystemApp flag. '
                      'System apps (isSystemApp: true) are built-in Android/OEM components such as Google Play Services, System UI, Xiaomi Cloud, or carrier apps. '
                      'They legitimately need many permissions to function — a high permission count is completely normal for them and should NOT be flagged as suspicious. '
                      'Only flag a system app if its specific permission combination matches a known risk pattern, such as SMS + accessibility + call log together, which could indicate spyware even in a system component.\n\n'
                      'User-installed apps (isSystemApp: false) are apps the user downloaded themselves. '
                      'A high permission count for these is worth investigating since regular apps do not normally need hundreds of permissions.',
            },
            // Prior conversation history, oldest first, excluding the message just added
            for (final msg in _messages.sublist(0, _messages.length - 1))
              {
                'role': msg.isUser ? 'user' : 'assistant',
                'content': msg.text,
              },
            // Current user message (with app context prepended if applicable)
            {
              'role': 'user',
              'content': userContent,
            },
          ],
        }),
      );

      final data = jsonDecode(response.body);
      final reply =
          data['choices']?[0]?['message']?['content']?.toString() ??
          '[DEBUG] No choices in response. Raw body:\n${response.body}';

      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _aiThinking = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: '[DEBUG] Exception: $e',
            isUser: false,
          ),
        );
        _aiThinking = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _askAboutApp(AppPermissionInfo app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(app.appName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Package Name:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SelectableText(
              app.packageName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'To find this app:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              'Settings → Apps → search the app name',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '${app.permissions.length} permissions',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage(
                'Tell me about ${app.appName} (${app.packageName}). '
                'This is a ${app.isSystemApp ? "system/built-in" : "user-installed"} app. '
                'It has these permissions: ${app.permissions.join(', ')}. '
                '${app.usedCameraRecently ? 'It used the camera recently. ' : ''}'
                '${app.usedMicRecently ? 'It used the microphone recently. ' : ''}'
                '${app.usedLocationRecently ? 'It used location recently. ' : ''}'
                'Is this app safe? What is it used for?',
                includeAppSummary: false,
              );
            },
            child: const Text('Ask AI'),
          ),
        ],
      ),
    );
  }

  Color _riskColor(AppPermissionInfo app) {
    if (app.usedCameraRecently || app.usedMicRecently) return Colors.redAccent;
    if (app.usedLocationRecently) return Colors.orange;
    if (app.permissions.length > 5) return Colors.orange;
    return const Color(0xFF00E6B8);
  }

  Widget _appCard(AppPermissionInfo app) {
    final risk = _riskColor(app);
    return GestureDetector(
      onTap: () => _askAboutApp(app),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: risk.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.android, color: risk, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    app.appName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (app.usedCameraRecently)
              _recentBadge(Icons.camera_alt, 'Camera', Colors.redAccent),
            if (app.usedMicRecently)
              _recentBadge(Icons.mic, 'Mic', Colors.redAccent),
            if (app.usedLocationRecently)
              _recentBadge(Icons.location_on, 'Location', Colors.orange),
            const SizedBox(height: 6),
            Text(
              '${app.permissions.length} permissions',
              style: TextStyle(fontSize: 11, color: context.subtleText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentBadge(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildAppListView(List<AppPermissionInfo> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Text('No apps', style: TextStyle(color: context.subtleText)),
      );
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: apps.length,
      itemBuilder: (_, i) => _appCard(apps[i]),
    );
  }

  Widget _buildSystemServicesView(List<AppPermissionInfo> apps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'These are built-in Android components — usually nothing to worry about',
            style: TextStyle(fontSize: 11, color: context.subtleText),
          ),
        ),
        Expanded(
          child: apps.isEmpty
              ? Center(
                  child: Text(
                    'No system services',
                    style: TextStyle(color: context.subtleText),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemCount: apps.length,
                  itemBuilder: (_, i) => _appCard(apps[i]),
                ),
        ),
      ],
    );
  }

  Widget _chatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: msg.isUser ? context.surface : context.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cardBorder),
        ),
        child: msg.isUser
            ? Text(
                msg.text,
                style: TextStyle(color: context.primaryText, fontSize: 13),
              )
            : MarkdownBody(
                data: msg.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: context.secondaryText, fontSize: 13),
                  strong: TextStyle(
                    color: context.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  em: TextStyle(
                    color: context.secondaryText,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                  listBullet:
                      TextStyle(color: context.secondaryText, fontSize: 13),
                  h3: TextStyle(
                    color: context.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Monitor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_apps.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No app data available',
                style: TextStyle(color: context.subtleText),
              ),
            )
          else ...[
            TabBar(
              controller: _tabController,
              labelColor: context.primaryText,
              unselectedLabelColor: context.subtleText,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Apps'),
                Tab(text: 'System Services'),
              ],
            ),
            SizedBox(
              height: 185,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppListView(_myApps),
                  _buildSystemServicesView(_systemApps),
                ],
              ),
            ),
          ],

          Divider(height: 1, color: context.cardBorder),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_aiThinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _aiThinking) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: const SizedBox(
                        width: 40,
                        height: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Dot(delay: 0),
                            _Dot(delay: 150),
                            _Dot(delay: 300),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return _chatBubble(_messages[i]);
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: context.surface,
              border: Border(top: BorderSide(color: context.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: TextStyle(color: context.primaryText),
                    decoration: InputDecoration(
                      hintText: 'Ask about any app...',
                      hintStyle: TextStyle(color: context.subtleText),
                      filled: true,
                      fillColor: context.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_chatController.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.scanAccentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: context.isDark ? Colors.black : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(radius: 3, backgroundColor: Colors.grey),
    );
  }
}
