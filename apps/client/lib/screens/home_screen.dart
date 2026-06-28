import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/media.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/url_input.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _downloadService = DownloadService();

  AnalyzeResponse? _result;
  String? _statusMessage;
  bool _isError = false;
  bool _isAnalyzing = false;
  String? _downloadingFormatId;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _listenForSharedLinks();
  }

  void _listenForSharedLinks() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

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

    sharing.getInitialMedia().then(applyShared);
    sharing.getMediaStream().listen(applyShared);
  }

  ApiService get _api => ApiService(widget.settings.apiUrl);

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _isError = false;
      _statusMessage = 'Analyzing link…';
      _result = null;
    });

    try {
      final data = await _api.analyze(url);
      if (!mounted) return;

      if (data.formats.isEmpty) {
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
    } on ApiException catch (e) {
      _showAnalyzeError(e.message);
    } catch (e) {
      _showAnalyzeError('Could not reach the server. Check your connection or API settings.');
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

  Future<void> _downloadFormat(MediaFormat format) async {
    if (_result == null) return;

    String? saveDir;
    if (widget.settings.askSaveLocation) {
      saveDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download folder',
      );
      if (saveDir == null) return;
    }

    setState(() {
      _downloadingFormatId = format.formatId;
      _downloadProgress = 0;
    });

    try {
      final endpoint = _api.downloadEndpoint(_result!.url, format.formatId);
      final saved = await _downloadService.download(
        url: endpoint,
        title: _result!.title ?? 'download',
        ext: format.ext,
        saveDirectory: saveDir,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p < 0 ? null : p);
        },
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
      final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
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
            IconButton(
              tooltip: 'Settings',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(settings: widget.settings),
                  ),
                );
                setState(() {});
              },
              icon: const Icon(Icons.settings_outlined),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://github.com/drmikecrypto/download-everything')),
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
                  'Instagram · TikTok · YouTube · X · 1,800+ sites. Free. Ad-free. No signup.',
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
      ('Privacy first', 'No accounts. Links go to the open API only.'),
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
