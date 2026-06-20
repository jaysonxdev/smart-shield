// lib/screens/junk_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';

class JunkScreen extends StatefulWidget {
  final ScanController ctrl;
  const JunkScreen({super.key, required this.ctrl});

  @override
  State<JunkScreen> createState() => _JunkScreenState();
}

class _JunkScreenState extends State<JunkScreen> {
  bool _scanning = false;
  bool _scanned = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await widget.ctrl.scanJunk(() => setState(() {}));
    setState(() {
      _scanning = false;
      _scanned = true;
    });
  }

  void _openFileLocation(JunkFile junk) {
    final folderPath = junk.path.substring(0, junk.path.lastIndexOf('/'));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('File Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File name:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              junk.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Location:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(folderPath, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text(
              'Open your file manager and navigate to this location to delete the file.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAll() async {
    int deleted = 0;
    int permissionFailed = 0;
    int otherFailed = 0;

    for (final junk in List.from(widget.ctrl.junkFiles)) {
      // Defense-in-depth: only delete paths inside the known junk scan directories.
      final isAllowed = MockData.junkFoldersToScan.any(
        (dir) => junk.path.startsWith('$dir/'),
      );
      if (!isAllowed) {
        otherFailed++;
        continue;
      }

      final file = File(junk.path);

      if (!await file.exists()) {
        widget.ctrl.junkFiles.remove(junk);
        deleted++;
        continue;
      }

      try {
        await file.delete();
        widget.ctrl.junkFiles.remove(junk);
        deleted++;
      } on FileSystemException catch (e) {
        // OS error 13 = EACCES (permission denied).
        if (e.osError?.errorCode == 13) {
          permissionFailed++;
        } else {
          otherFailed++;
        }
      } catch (_) {
        otherFailed++;
      }
    }

    if (!mounted) return;
    setState(() {});

    final failed = permissionFailed + otherFailed;
    final String message;
    if (failed == 0) {
      message = 'Deleted $deleted files.';
    } else if (permissionFailed > 0) {
      message = 'Deleted $deleted files. $failed could not be deleted — '
          'open your Files app to remove them manually.';
    } else {
      message = 'Deleted $deleted files. $failed could not be deleted.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: failed > 0 ? const Duration(seconds: 5) : const Duration(seconds: 4),
      ),
    );
  }

  String get _totalSize {
    final bytes = widget.ctrl.totalJunkBytes;
    if (bytes > 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final junkFiles = widget.ctrl.junkFiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Junk Files'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (junkFiles.isNotEmpty)
            TextButton(
              onPressed: _deleteAll,
              child: const Text(
                'Delete All',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          if (_scanned)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: junkFiles.isEmpty
                    ? const Color(0xFF00E6B8).withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: junkFiles.isEmpty
                      ? const Color(0xFF00E6B8).withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    junkFiles.isEmpty ? Icons.check_circle : Icons.delete_sweep,
                    color: junkFiles.isEmpty
                        ? const Color(0xFF00E6B8)
                        : Colors.orange,
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        junkFiles.isEmpty
                            ? 'No junk files found!'
                            : '${junkFiles.length} junk files found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: junkFiles.isEmpty
                              ? const Color(0xFF00E6B8)
                              : Colors.orange,
                        ),
                      ),
                      if (junkFiles.isNotEmpty)
                        Text(
                          'Total size: $_totalSize',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Scan button
          if (!_scanned || _scanning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Junk Files'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),

          // File list
          Expanded(
            child: junkFiles.isEmpty && _scanned
                ? const Center(
                    child: Text(
                      'Your device is clean! 🎉',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: junkFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final junk = junkFiles[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.insert_drive_file,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text(
                            junk.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${junk.reason} • ${junk.sizeReadable}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.folder_open,
                              color: Colors.orangeAccent,
                            ),
                            onPressed: () => _openFileLocation(junk),
                            tooltip: 'Open file location',
                          ),
                          onTap: () => _openFileLocation(junk),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
