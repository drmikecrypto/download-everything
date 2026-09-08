import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/media.dart';
import '../services/app_update_service.dart';
import '../services/download_history_service.dart';
import '../services/download_queue_service.dart';
import '../services/instagram_session.dart';
import '../services/settings_service.dart';
import '../services/ytdlp_engine.dart';
import '../services/ytdlp_options.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/url_input.dart';
import 'history_screen.dart';
import 'instagram_login_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.engine,
    required this.history,
    required this.queue,
  });

  final SettingsService settings;
  final YtdlpEngine engine;
  final DownloadHistoryService history;
  final DownloadQueueService queue;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _urlController = TextEditingController();
  late final InstagramSession _igSession;
  final _updateService = AppUpdateService();

  AnalyzeResponse? _result;
  String? _statusMessage;
  bool _isError = false;
  bool _isAnalyzing = false;
  String? _downloadingFormatId;
  double? _downloadProgress;
  AppUpdateInfo? _appUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _igSession = InstagramSession(widget.settings);
    _listenForSharedLinks();
    _checkForAppUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForAppUpdate();
    }
  }

  Future<void> _checkForAppUpdate({bool includeDismissed = false}) async {
    final update = await _updateService.checkForUpdate(
      includeDismissed: includeDismissed,
    );
    if (!mounted) return;
    setState(() => _appUpdate = update);
  }

  Future<void> _openAppUpdate() async {
    final update = _appUpdate;
    if (update == null) return;
    final uri = Uri.parse(update.openUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _dismissUpdate() async {
    final update = _appUpdate;
    if (update == null) return;
    await _updateService.dismiss(update.latestVersion);
    if (!mounted) return;
    setState(() => _appUpdate = null);
  }

  void _listenForSharedLinks() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      void applyText(String? text) {
        if (text == null || !text.trim().startsWith('http')) return;
        _urlController.text = text.trim();
        _analyze();
      }

      final sharing = ReceiveSharingIntent.instance;

      void applyShared(List<SharedMediaFile> files) {
        if (files.isEmpty) return;
        final item = files.first;
        final text = (item.type == SharedMediaType.text || item.type == SharedMediaType.url)
            ? item.path
            : item.path;
        applyText(text);
      }

      sharing.getInitialMedia().then(applyShared).catchError((_) {});
      sharing.getMediaStream().listen(applyShared, onError: (_) {});
    } catch (_) {
      // Sharing plugin failures must never prevent the app from staying open.
    }
  }

  Future<bool> _ensureInstagramSession({required bool force}) async {
    if (!force && await _igSession.hasSession()) return true;
    if (!mounted) return false;
    setState(() => _statusMessage = 'Instagram sign-in required…');
    return promptInstagramLogin(context, widget.settings);
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _isError = false;
      _statusMessage = 'Preparing yt-dlp (first run can take a moment)…';
      _result = null;
    });

    try {
      if (shouldUseInstagramSession(url) &&
          Platform.isAndroid &&
          !await _igSession.hasSession()) {
        final ok = await _ensureInstagramSession(force: true);
        if (!ok) {
          _showAnalyzeError(
            'Instagram sign-in was cancelled.\n\n$kInstagramCookiesTip',
          );
          return;
        }
        if (!mounted) return;
      }

      await widget.engine.ensureReady();
      if (!mounted) return;
      setState(() => _statusMessage = 'Analyzing link with yt-dlp…');

      var data = await widget.engine.analyze(
        url,
        cookiesPath: widget.settings.cookiesPath,
        allowPlaylist: widget.settings.allowPlaylist,
      );
      if (!mounted) return;

      if (data.formats.isEmpty &&
          shouldUseInstagramSession(url) &&
          Platform.isAndroid &&
          needsInstagramAuth(data.error)) {
        final ok = await _ensureInstagramSession(force: true);
        if (!ok) {
          _showAnalyzeError(data.error ?? 'No downloadable formats found.');
          return;
        }
        if (!mounted) return;
        setState(() => _statusMessage = 'Retrying after Instagram sign-in…');
        data = await widget.engine.analyze(
          url,
          cookiesPath: widget.settings.cookiesPath,
          allowPlaylist: widget.settings.allowPlaylist,
        );
        if (!mounted) return;
      }

      if (data.formats.isEmpty && data.playlistEntries.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _isError = true;
          _statusMessage = data.error ?? 'No downloadable formats found.';
        });
        return;
      }

      setState(() {
        _isAnalyzing = false;
        _statusMessage = null;
        _result = data;
      });
    } on YtdlpException catch (e) {
      if (shouldUseInstagramSession(url) &&
          Platform.isAndroid &&
          needsInstagramAuth(e.message)) {
        final ok = await _ensureInstagramSession(force: true);
        if (ok && mounted) {
          setState(() => _statusMessage = 'Retrying after Instagram sign-in…');
          try {
            final data = await widget.engine.analyze(
              url,
              cookiesPath: widget.settings.cookiesPath,
              allowPlaylist: widget.settings.allowPlaylist,
            );
            if (!mounted) return;
            if (data.formats.isNotEmpty || data.playlistEntries.isNotEmpty) {
              setState(() {
                _isAnalyzing = false;
                _statusMessage = null;
                _result = data;
              });
              return;
            }
            _showAnalyzeError(data.error ?? e.message);
            return;
          } catch (retryError) {
            _showAnalyzeError('$retryError');
            return;
          }
        }
      }
      _showAnalyzeError(e.message);
    } catch (e) {
      _showAnalyzeError('$e');
    }
  }

  void _showAnalyzeError(String message) {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _isError = true;
      _statusMessage = message;
      _result = null;
    });
  }

  Future<String?> _pickSaveDir() async {
    if (widget.settings.askSaveLocation &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download folder',
      );
    }
    return null;
  }

  Future<void> _downloadFormat(MediaFormat format) async {
    if (_result == null) return;

    final saveDir = await _pickSaveDir();
    if (widget.settings.askSaveLocation &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
        saveDir == null) {
      return;
    }

    // Playlist: enqueue all entries with this quality selector.
    if (_result!.isPlaylist) {
      widget.queue.enqueuePlaylist(
        entries: _result!.playlistEntries,
        formatId: format.formatId,
        ext: format.ext,
        saveDirectory: saveDir,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Queued ${_result!.playlistEntries.length} playlist items',
          ),
          action: SnackBarAction(
            label: 'Queue',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => QueueScreen(queue: widget.queue)),
              );
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _downloadingFormatId = format.formatId;
      _downloadProgress = 0;
    });

    try {
      final saved = await widget.engine.download(
        url: _result!.url,
        formatId: format.formatId,
        title: _result!.title ?? 'download',
        ext: format.ext,
        saveDirectory: saveDir,
        cookiesPath: widget.settings.cookiesPath,
        writeSubs: widget.settings.writeSubs,
        sponsorBlock: widget.settings.sponsorBlock,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p < 0 ? null : p);
        },
      );

      await widget.history.add(
        url: _result!.url,
        title: _result!.title ?? 'download',
        path: saved.path,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${saved.filename}'),
          action: SnackBarAction(
            label: 'Open folder',
            onPressed: () => _openContainingFolder(saved.path),
          ),
        ),
      );
    } on YtdlpException catch (e) {
      if (shouldUseInstagramSession(_result!.url) &&
          Platform.isAndroid &&
          needsInstagramAuth(e.message)) {
        final ok = await _ensureInstagramSession(force: true);
        if (ok && mounted) {
          try {
            final saved = await widget.engine.download(
              url: _result!.url,
              formatId: format.formatId,
              title: _result!.title ?? 'download',
              ext: format.ext,
              saveDirectory: saveDir,
              cookiesPath: widget.settings.cookiesPath,
              writeSubs: widget.settings.writeSubs,
              sponsorBlock: widget.settings.sponsorBlock,
              onProgress: (p) {
                if (mounted) setState(() => _downloadProgress = p < 0 ? null : p);
              },
            );
            await widget.history.add(
              url: _result!.url,
              title: _result!.title ?? 'download',
              path: saved.path,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to ${saved.filename}')),
            );
            return;
          } catch (retryError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $retryError'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFormatId = null;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _queueSingle(MediaFormat format) async {
    if (_result == null) return;
    final saveDir = await _pickSaveDir();
    if (widget.settings.askSaveLocation &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
        saveDir == null) {
      return;
    }
    widget.queue.enqueue(
      url: _result!.url,
      title: _result!.title ?? 'download',
      formatId: format.formatId,
      ext: format.ext,
      saveDirectory: saveDir,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to queue')),
    );
  }

  Future<void> _openContainingFolder(String filePath) async {
    final file = File(filePath);
    final dir = file.parent.path;
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    } else if (Platform.isAndroid) {
      final uri = Uri.parse(
        'content://com.android.externalstorage.documents/document/primary:Download',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              const AppLogo(size: 28),
              const SizedBox(width: 10),
              Text(
                'Download Everything',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: wide ? 18 : 16),
              ),
            ],
          ),
          actions: [
            if (_appUpdate != null)
              IconButton(
                tooltip: 'Update to v${_appUpdate!.latestVersion}',
                onPressed: _openAppUpdate,
                icon: Badge(
                  smallSize: 8,
                  backgroundColor: AppColors.success,
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.success,
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: widget.queue,
              builder: (context, _) {
                final n = widget.queue.pendingCount;
                return IconButton(
                  tooltip: 'Download queue',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QueueScreen(queue: widget.queue),
                      ),
                    );
                  },
                  icon: Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n'),
                    child: const Icon(Icons.queue_outlined),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'History',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(history: widget.history),
                  ),
                );
              },
              icon: const Icon(Icons.history),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      settings: widget.settings,
                      engine: widget.engine,
                    ),
                  ),
                );
                if (!mounted) return;
                setState(() {});
                _checkForAppUpdate(includeDismissed: true);
              },
              icon: const Icon(Icons.settings_outlined),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/drmikecrypto/download-everything'),
              ),
              icon: const Icon(Icons.code, size: 18),
              label: const Text('GitHub'),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_appUpdate != null) ...[
                  Material(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.new_releases_outlined, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'v${_appUpdate!.latestVersion} is available',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _openAppUpdate,
                            child: const Text('Update'),
                          ),
                          IconButton(
                            tooltip: 'Dismiss',
                            onPressed: _dismissUpdate,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Download anything from the internet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: wide ? 34 : 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Instagram · TikTok · YouTube · X · 1,800+ sites. Runs entirely on your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: wide ? 16 : 14, height: 1.4),
                ),
                const SizedBox(height: 28),
                UrlInputBar(
                  controller: _urlController,
                  onAnalyze: _analyze,
                  isLoading: _isAnalyzing,
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isError ? AppColors.error.withValues(alpha: 0.1) : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isError ? AppColors.error.withValues(alpha: 0.35) : AppColors.border,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(color: _isError ? AppColors.error : AppColors.muted),
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  MediaResultCard(
                    result: _result!,
                    sourceUrl: _urlController.text.trim(),
                    downloadingFormatId: _downloadingFormatId,
                    downloadProgress: _downloadProgress,
                    onDownload: _downloadFormat,
                    onQueue: _result!.isPlaylist ? null : _queueSingle,
                  ),
                ],
                const SizedBox(height: 32),
                _FeatureSection(wide: wide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Zero ads', 'No popups, upsells, or malware redirects.'),
      ('Pick your quality', 'See every resolution and format before saving.'),
      ('Privacy first', 'No accounts. Extraction runs locally via yt-dlp.'),
      ('Runs on your device', 'Native app for Windows, macOS, Linux, and Android.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 20),
        const Text('Why Download Everything?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: wide ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 3.2 : 2.8,
          children: items
              .map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(item.$2, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
