import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/download_history_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.history});

  final DownloadHistoryService history;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.history.load();
  }

  Future<void> _clear() async {
    await widget.history.clear();
    if (!mounted) return;
    setState(() => _entries = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download history'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(onPressed: _clear, child: const Text('Clear')),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text(
                'No downloads yet.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final e = _entries[index];
                return Card(
                  child: ListTile(
                    title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${e.path}\n${e.savedAt.toLocal()}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Open source URL',
                      icon: const Icon(Icons.link),
                      onPressed: () => launchUrl(
                        Uri.parse(e.url),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
