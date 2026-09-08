import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../services/app_update_service.dart';
import '../services/instagram_session.dart';
import '../services/settings_service.dart';
import '../services/web_cookie_bridge.dart';
import '../services/ytdlp_engine.dart';
import '../theme/app_theme.dart';
import 'instagram_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.engine});

  final SettingsService settings;
  final YtdlpEngine engine;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _askSaveLocation = false;
  bool _writeSubs = false;
  bool _sponsorBlock = false;
  bool _allowPlaylist = true;
  bool _busy = false;
  bool _igConnected = false;
  String? _status;
  AppUpdateInfo? _update;
  late final InstagramSession _igSession;

  @override
  void initState() {
    super.initState();
    _igSession = InstagramSession(widget.settings);
    _askSaveLocation = widget.settings.askSaveLocation;
    _writeSubs = widget.settings.writeSubs;
    _sponsorBlock = widget.settings.sponsorBlock;
    _allowPlaylist = widget.settings.allowPlaylist;
    _refreshIgStatus();
    _loadVersion();
    _checkForAppUpdate();
  }

  Future<void> _refreshIgStatus() async {
    final connected = await _igSession.hasSession();
    if (!mounted) return;
    setState(() => _igConnected = connected);
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

  Future<void> _checkForAppUpdate() async {
    // Always show in Settings even if home banner was dismissed.
    final update = await AppUpdateService().checkForUpdate(includeDismissed: true);
    if (!mounted) return;
    setState(() => _update = update);
  }

  Future<void> _openUpdate() async {
    final update = _update;
    if (update == null) return;
    final uri = Uri.parse(update.openUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    await widget.settings.setAskSaveLocation(_askSaveLocation);
    await widget.settings.setWriteSubs(_writeSubs);
    await widget.settings.setSponsorBlock(_sponsorBlock);
    await widget.settings.setAllowPlaylist(_allowPlaylist);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _connectInstagram() async {
    final ok = await promptInstagramLogin(context, widget.settings);
    if (!mounted) return;
    await _refreshIgStatus();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram connected')),
      );
    }
  }

  Future<void> _signOutInstagram() async {
    await _igSession.clear();
    await WebCookieBridge.clearCookies();
    if (!mounted) return;
    await _refreshIgStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instagram signed out')),
    );
  }

  Future<void> _pickCookies() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select cookies.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    try {
      await widget.settings.importCookiesFile(
        sourcePath: file.path,
        bytes: file.bytes,
      );
      if (!mounted) return;
      await _refreshIgStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('cookies.txt imported')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import cookies: $e')),
      );
    }
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow playlists'),
            subtitle: const Text('Analyze playlist/channel URLs and queue every item.'),
            value: _allowPlaylist,
            onChanged: (v) => setState(() => _allowPlaylist = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Embed subtitles'),
            subtitle: const Text('Write and embed English subs when available.'),
            value: _writeSubs,
            onChanged: (v) => setState(() => _writeSubs = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('SponsorBlock'),
            subtitle: const Text('Remove default sponsored segments (YouTube).'),
            value: _sponsorBlock,
            onChanged: (v) => setState(() => _sponsorBlock = v),
          ),
          const SizedBox(height: 24),
          Text('Instagram', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            Platform.isAndroid
                ? 'One-time sign-in unlocks posts, reels, and stories on this device. '
                    'Your session never leaves the phone.'
                : 'On desktop, import cookies under Advanced if Instagram needs a session. '
                    'In-app sign-in is available on Android.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            _igConnected ? 'Connected' : 'Not connected',
            style: monoStyle(context).copyWith(
              fontSize: 12,
              color: _igConnected ? AppColors.success : AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (Platform.isAndroid) ...[
                if (!_igConnected)
                  FilledButton.icon(
                    onPressed: _connectInstagram,
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Connect Instagram'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _connectInstagram,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Re-sign in'),
                  ),
                  TextButton(
                    onPressed: _signOutInstagram,
                    child: const Text('Sign out'),
                  ),
                ],
              ] else if (_igConnected)
                TextButton(
                  onPressed: _signOutInstagram,
                  child: const Text('Clear session'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced'),
            subtitle: const Text('Import a cookies.txt file manually'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickCookies,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import cookies.txt'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 24),
          Text('yt-dlp', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_status != null)
            Text(_status!, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
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
          ),
          const SizedBox(height: 8),
          Text(
            Platform.isAndroid
                ? 'Pulls the latest yt-dlp build into the app.'
                : 'Downloads the latest yt-dlp binary next to the app.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
          const SizedBox(height: 32),
          Text(
            'Download Everything v$kAppVersion\nAGPL-3.0 · drmikecrypto',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/sponsors/drmikecrypto'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Sponsor on GitHub'),
          ),
          if (_update != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openUpdate,
              icon: const Icon(Icons.new_releases_outlined, size: 18),
              label: Text(
                _update!.downloadUrl != null
                    ? 'Download update — v${_update!.latestVersion}'
                    : 'Update available — v${_update!.latestVersion}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
