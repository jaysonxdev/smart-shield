import 'package:flutter/material.dart';
import '../models.dart';
import 'threat_warning_screen.dart';

class QuarantineScreen extends StatefulWidget {
  final ScanController ctrl;
  const QuarantineScreen({super.key, required this.ctrl});

  @override
  State<QuarantineScreen> createState() => _QuarantineScreenState();
}

class _QuarantineScreenState extends State<QuarantineScreen> {
  Color _riskColor(Risk r) {
    switch (r) {
      case Risk.low:
        return const Color(0xFF00E6B8);
      case Risk.medium:
        return Colors.orange;
      case Risk.high:
        return Colors.redAccent;
    }
  }

  String _riskLabel(Risk r) =>
      r == Risk.high ? 'High' : r == Risk.medium ? 'Medium' : 'Low';

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final flagged = widget.ctrl.alerts
        .where((a) => a.risk == Risk.medium || a.risk == Risk.high)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quarantine'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: flagged.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: const Color(0xFF00E6B8).withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nothing quarantined',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
              itemCount: flagged.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = flagged[index];
                final color = _riskColor(item.risk);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(Icons.warning_rounded, color: color),
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
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _riskLabel(item.risk),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ThreatWarningScreen(
                            item: item,
                            onDeleted: () {
                              widget.ctrl.alerts
                                  .removeWhere((a) => a.id == item.id);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
