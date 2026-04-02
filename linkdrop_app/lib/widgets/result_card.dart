import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_info.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class ResultCard extends StatelessWidget {
  final MediaInfo info;
  final String url;

  const ResultCard({super.key, required this.info, required this.url});

  @override
  Widget build(BuildContext context) {
    final videoFormats = info.formats.where((f) => f.hasVideo && f.hasAudio).toList();
    final audioFormats = info.formats.where((f) => !f.hasVideo && f.hasAudio).toList();
    final videoOnly   = info.formats.where((f) => f.hasVideo && !f.hasAudio).toList();
    final imageFormats = info.formats.where((f) => !f.hasVideo && !f.hasAudio).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E3E)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.thumbnail != null) _buildThumbnail(),
          _buildMeta(),
          const Divider(color: Color(0xFF2E2E3E), height: 1),
          if (videoFormats.isNotEmpty) _buildFormats('Video + Audio', videoFormats, true),
          if (audioFormats.isNotEmpty) _buildFormats('Audio only', audioFormats, false),
          if (videoOnly.isNotEmpty) _buildFormats('Video only', videoOnly, false),
          if (imageFormats.isNotEmpty) _buildFormats('Image', imageFormats, true),
          if (info.formats.isEmpty) _buildFallback(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: info.thumbnail!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))),
        errorWidget: (_, __, ___) => Container(color: Colors.black,
          child: const Icon(Icons.broken_image, color: Color(0xFF888899))),
      ),
    );
  }

  Widget _buildMeta() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            [
              if (info.platform != null) info.platform!,
              if (info.uploader != null) info.uploader!,
              if (info.durationLabel.isNotEmpty) info.durationLabel,
            ].join(' · '),
            style: const TextStyle(color: Color(0xFF888899), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFormats(String label, List<MediaFormat> formats, bool isPrimary) {
    if (formats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
            style: const TextStyle(color: Color(0xFF888899), fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: formats.take(6).map((f) => _FormatButton(
              format: f, url: url, title: info.title, isPrimary: isPrimary,
            )).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    final dlUrl = ApiService.getDownloadUrl(url, null, info.title);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: _DownloadButton(
        label: '⬇  Download Best Quality',
        downloadUrl: dlUrl,
        filename: '${info.title}.mp4',
        isPrimary: true,
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final MediaFormat format;
  final String url;
  final String title;
  final bool isPrimary;

  const _FormatButton({required this.format, required this.url, required this.title, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final dlUrl = ApiService.getDownloadUrl(
      url, format.formatId, title,
      directUrl: format.directUrl,
    );
    final filename = '${title.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}.${format.ext}';
    return _DownloadButton(
      label: '${format.icon}  ${format.label}',
      downloadUrl: dlUrl,
      filename: filename,
      isPrimary: isPrimary,
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final String label;
  final String downloadUrl;
  final String filename;
  final bool isPrimary;

  const _DownloadButton({required this.label, required this.downloadUrl, required this.filename, required this.isPrimary});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  double? _progress;
  bool _done = false;

  void _start() {
    setState(() { _progress = 0; _done = false; });
    DownloadService.download(
      url: widget.downloadUrl,
      filename: widget.filename.replaceAll(RegExp(r'[^\w\s.\-]'), ''),
      onProgress: (p) => setState(() => _progress = p),
      onDone: (path) => setState(() { _done = true; _progress = null; }),
      onError: (e) {
        setState(() => _progress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: const Color(0xFFF87171)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary ? const Color(0xFF6C63FF) : const Color(0xFF22222F);
    final fg = widget.isPrimary ? Colors.white : const Color(0xFFE8E8F0);
    final border = widget.isPrimary ? BorderSide.none : const BorderSide(color: Color(0xFF2E2E3E));

    return GestureDetector(
      onTap: _progress != null ? null : _start,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10),
          border: Border.fromBorderSide(border),
        ),
        child: _progress != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(value: _progress, color: fg, strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('${(_progress! * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: fg, fontSize: 12)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (_done) Icon(Icons.check_circle, color: fg, size: 14),
              if (!_done) const SizedBox.shrink(),
              const SizedBox(width: 4),
              Text(_done ? 'Downloaded' : widget.label,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }
}
