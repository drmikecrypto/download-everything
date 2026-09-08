import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/media.dart';
import 'download_history_service.dart';
import 'settings_service.dart';
import 'ytdlp_engine.dart';

enum QueueItemStatus { pending, running, done, failed, cancelled }

class QueueItem {
  QueueItem({
    required this.id,
    required this.url,
    required this.title,
    required this.formatId,
    required this.ext,
    this.saveDirectory,
  });

  final String id;
  final String url;
  final String title;
  final String formatId;
  final String ext;
  final String? saveDirectory;

  QueueItemStatus status = QueueItemStatus.pending;
  double? progress;
  String? error;
  String? savedPath;
}

/// Sequential download queue (one active download at a time).
class DownloadQueueService extends ChangeNotifier {
  DownloadQueueService({
    required this.engine,
    required this.settings,
    required this.history,
  });

  final YtdlpEngine engine;
  final SettingsService settings;
  final DownloadHistoryService history;

  final List<QueueItem> _items = [];
  bool _processing = false;
  int _seq = 0;

  List<QueueItem> get items => List.unmodifiable(_items);
  bool get isBusy => _processing;
  int get pendingCount => _items
      .where(
        (i) =>
            i.status == QueueItemStatus.pending ||
            i.status == QueueItemStatus.running,
      )
      .length;

  void enqueue({
    required String url,
    required String title,
    required String formatId,
    required String ext,
    String? saveDirectory,
  }) {
    _seq += 1;
    _items.add(
      QueueItem(
        id: 'q$_seq',
        url: url,
        title: title,
        formatId: formatId,
        ext: ext,
        saveDirectory: saveDirectory,
      ),
    );
    notifyListeners();
    unawaited(_pump());
  }

  void enqueuePlaylist({
    required List<PlaylistEntry> entries,
    required String formatId,
    required String ext,
    String? saveDirectory,
  }) {
    for (final entry in entries) {
      enqueue(
        url: entry.url,
        title: entry.title ?? entry.id ?? 'playlist-item',
        formatId: formatId,
        ext: ext,
        saveDirectory: saveDirectory,
      );
    }
  }

  void cancel(String id) {
    for (final item in _items) {
      if (item.id != id) continue;
      if (item.status == QueueItemStatus.pending) {
        item.status = QueueItemStatus.cancelled;
        notifyListeners();
      }
      break;
    }
  }

  void clearFinished() {
    _items.removeWhere(
      (i) =>
          i.status == QueueItemStatus.done ||
          i.status == QueueItemStatus.failed ||
          i.status == QueueItemStatus.cancelled,
    );
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_processing) return;
    _processing = true;
    notifyListeners();
    try {
      while (true) {
        QueueItem? next;
        for (final item in _items) {
          if (item.status == QueueItemStatus.pending) {
            next = item;
            break;
          }
        }
        if (next == null) break;

        next.status = QueueItemStatus.running;
        next.progress = 0;
        notifyListeners();

        try {
          await engine.analyze(next.url, cookiesPath: settings.cookiesPath);
          final result = await engine.download(
            url: next.url,
            formatId: next.formatId,
            title: next.title,
            ext: next.ext,
            saveDirectory: next.saveDirectory,
            cookiesPath: settings.cookiesPath,
            writeSubs: settings.writeSubs,
            sponsorBlock: settings.sponsorBlock,
            onProgress: (p) {
              next!.progress = p < 0 ? null : p;
              notifyListeners();
            },
          );
          next.status = QueueItemStatus.done;
          next.progress = 1;
          next.savedPath = result.path;
          await history.add(
            url: next.url,
            title: next.title,
            path: result.path,
          );
        } catch (e) {
          next.status = QueueItemStatus.failed;
          next.error = '$e';
        }
        notifyListeners();
      }
    } finally {
      _processing = false;
      notifyListeners();
    }
  }
}
