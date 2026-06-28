import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiController;
  bool _askSaveLocation = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: widget.settings.apiUrl);
    _askSaveLocation = widget.settings.askSaveLocation;
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setApiUrl(_apiController.text);
    await widget.settings.setAskSaveLocation(_askSaveLocation);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final api = ApiService(_apiController.text.trim());
      final health = await api.health();
      setState(() {
        _testResult = 'Connected — ${health['service']} (${health['runtime'] ?? 'online'})';
      });
    } catch (e) {
      setState(() => _testResult = 'Failed — $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('API server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _apiController,
            style: monoStyle(context),
            decoration: const InputDecoration(
              labelText: 'API base URL',
              helperText:
                  'Default uses the public Cloudflare Worker. Point to http://localhost:8000 for full yt-dlp (Docker API).',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text('Test connection'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _apiController.text = defaultApiUrl,
                child: const Text('Reset default'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Always ask where to save'),
            subtitle: const Text('Show a folder picker before each download on desktop.'),
            value: _askSaveLocation,
            onChanged: (v) => setState(() => _askSaveLocation = v),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
          const SizedBox(height: 32),
          Text(
            'Download Everything v1.0.0\nAGPL-3.0 · drmikecrypto',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
