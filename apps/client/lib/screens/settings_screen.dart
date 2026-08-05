import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/ytdlp_engine.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.engine});

  final SettingsService settings;
  final YtdlpEngine engine;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _askSaveLocation = false;
  String? _cookiesPath;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _askSaveLocation = widget.settings.askSaveLocation;
    _cookiesPath = widget.settings.cookiesPath;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await widget.engine.version();
      if (!mounted) return;
      setState(() => _status = 'yt-dlp $v');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'yt-dlp: $e');
    }
  }

  Future<void> _save() async {
    await widget.settings.setAskSaveLocation(_askSaveLocation);
    await widget.settings.setCookiesPath(_cookiesPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _pickCookies() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select cookies.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _cookiesPath = path);
  }

  Future<void> _updateYtdlp() async {
    setState(() {
      _busy = true;
      _status = 'Updating yt-dlp…';
    });
    try {
      await widget.engine.updateYtdlp();
      final v = await widget.engine.version();
      setState(() => _status = 'Updated — yt-dlp $v');
    } on YtdlpException catch (e) {
      setState(() => _status = e.message);
    } catch (e) {
      setState(() => _status = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Downloads', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Always ask where to save'),
            subtitle: const Text('Show a folder picker before each download on desktop.'),
            value: _askSaveLocation,
            onChanged: (v) => setState(() => _askSaveLocation = v),
          ),
          const SizedBox(height: 24),
          Text('Cookies (Instagram stories)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Export a Netscape cookies.txt from your browser and import it here. '
            'Cookies stay on this device and enable stories / login-walled media.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            _cookiesPath ?? 'No cookies file selected',
            style: monoStyle(context).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickCookies,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Import cookies.txt'),
              ),
              if (_cookiesPath != null)
                TextButton(
                  onPressed: () => setState(() => _cookiesPath = null),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('yt-dlp', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_status != null)
            Text(_status!, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          if (Platform.isAndroid)
            OutlinedButton.icon(
              onPressed: _busy ? null : _updateYtdlp,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_rounded, size: 18),
              label: const Text('Update yt-dlp'),
            )
          else
            Text(
              'Desktop builds ship yt-dlp alongside the app. Re-run tool/fetch_binaries.dart or install a new Release to update.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
          const SizedBox(height: 32),
          Text(
            'Download Everything v1.1.0\nAGPL-3.0 · drmikecrypto',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
