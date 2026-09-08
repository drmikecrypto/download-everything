import 'package:flutter/material.dart';

import '../services/download_queue_service.dart';
import '../theme/app_theme.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.queue});

  final DownloadQueueService queue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final items = queue.items;
        return Scaffold(
          appBar: AppBar(
            title: Text('Queue (${queue.pendingCount} active)'),
            actions: [
              TextButton(
                onPressed: items.isEmpty ? null : queue.clearFinished,
                child: const Text('Clear done'),
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
                  child: Text(
                    'Queue is empty.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.status.name,
                              style: TextStyle(
                                color: item.status == QueueItemStatus.failed
                                    ? AppColors.error
                                    : AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            if (item.status == QueueItemStatus.running && item.progress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(
                                  value: item.progress!.clamp(0, 1),
                                  color: AppColors.success,
                                  backgroundColor: AppColors.border,
                                ),
                              ),
                            if (item.error != null)
                              Text(
                                item.error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.error, fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: item.status == QueueItemStatus.pending
                            ? IconButton(
                                tooltip: 'Cancel',
                                onPressed: () => queue.cancel(item.id),
                                icon: const Icon(Icons.close),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
