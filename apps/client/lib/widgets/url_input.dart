import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'brand.dart';

class UrlInputBar extends StatelessWidget {
  const UrlInputBar({
    super.key,
    required this.controller,
    required this.onAnalyze,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onAnalyze;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              style: monoStyle(context, size: 14, color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'Paste Instagram, TikTok, YouTube, X, or any video link…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onAnalyze(),
              keyboardType: TextInputType.url,
            ),
          ),
          IconButton(
            tooltip: 'Paste from clipboard',
            onPressed: isLoading
                ? null
                : () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      controller.text = data.text!.trim();
                    }
                  },
            icon: const Icon(Icons.content_paste_rounded, size: 20),
          ),
          FilledButton(
            onPressed: isLoading ? null : onAnalyze,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Analyze', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class MediaResultCard extends StatelessWidget {
  const MediaResultCard({
    super.key,
    required this.result,
    required this.sourceUrl,
    required this.downloadingFormatId,
    required this.downloadProgress,
    required this.onDownload,
  });

  final AnalyzeResponse result;
  final String sourceUrl;
  final String? downloadingFormatId;
  final double? downloadProgress;
  final void Function(MediaFormat format) onDownload;

  @override
  Widget build(BuildContext context) {
    final meta = <Widget>[
      if (result.platform != null) _MetaChip(result.platform!),
      if (result.uploader != null) _MetaChip(result.uploader!),
      if (formatDuration(result.duration).isNotEmpty) _MetaChip(formatDuration(result.duration)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.thumbnail != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      result.thumbnail!,
                      width: 160,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (result.thumbnail != null) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title ?? 'Media found',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: meta),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Available formats',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...result.formats.map((fmt) {
              final isDownloading = downloadingFormatId == fmt.formatId;
              final kind = fmt.isVideo
                  ? 'video'
                  : fmt.isAudio
                      ? 'audio'
                      : 'other';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    TypeBadge(label: fmt.typeLabel, kind: kind),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmt.label, style: monoStyle(context, size: 12, color: AppColors.text)),
                          Text(
                            '${fmt.ext.toUpperCase()} · ${formatBytes(fmt.bestSize).isEmpty ? '—' : formatBytes(fmt.bestSize)}',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloading && downloadProgress != null && downloadProgress! >= 0)
                      SizedBox(
                        width: 72,
                        child: LinearProgressIndicator(
                          value: downloadProgress!.clamp(0, 1),
                          backgroundColor: AppColors.border,
                          color: AppColors.success,
                        ),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: isDownloading ? null : () => onDownload(fmt),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.bg,
                        ),
                        child: Text(isDownloading ? 'Saving…' : 'Download'),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }
}
