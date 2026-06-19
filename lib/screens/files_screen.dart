// lib/screens/files_screen.dart
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../../models.dart';
import 'threat_warning_screen.dart';

class FilesScreen extends StatelessWidget {
  final String title;
  final List<ScanItem> items;
  final Color color;
  final IconData icon;

  const FilesScreen({
    super.key,
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

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

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 64, color: color.withValues(alpha:0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No $title found',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Run a scan to check your device',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _riskColor(item.risk).withValues(alpha:0.12),
                      child: Icon(icon, color: _riskColor(item.risk)),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.subtitle} • ${_formatTime(item.time)}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _riskColor(item.risk).withValues(alpha:0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.risk == Risk.low
                            ? 'Low'
                            : item.risk == Risk.medium
                            ? 'Medium'
                            : 'High',
                        style: TextStyle(
                          color: _riskColor(item.risk),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () async {
                      if (item.risk == Risk.medium ||
                          item.risk == Risk.high) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ThreatWarningScreen(item: item),
                          ),
                        );
                        return;
                      }
                      // Safe files — open directly
                      final messenger = ScaffoldMessenger.of(context);
                      if (item.path != null) {
                        final result = await OpenFile.open(item.path!);
                        if (result.type != ResultType.done) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open file: ${item.path}',
                              ),
                            ),
                          );
                        }
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('File path not available'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
