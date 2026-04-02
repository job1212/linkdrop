class MediaFormat {
  final String formatId;
  final String ext;
  final String quality;
  final int? filesize;
  final bool hasVideo;
  final bool hasAudio;
  final String? directUrl; // for Unsplash/OG images

  const MediaFormat({
    required this.formatId,
    required this.ext,
    required this.quality,
    this.filesize,
    required this.hasVideo,
    required this.hasAudio,
    this.directUrl,
  });

  factory MediaFormat.fromJson(Map<String, dynamic> j) => MediaFormat(
        formatId: j['format_id'] ?? '',
        ext: j['ext'] ?? 'jpg',
        quality: j['quality'] ?? '',
        filesize: j['filesize'],
        hasVideo: j['hasVideo'] ?? false,
        hasAudio: j['hasAudio'] ?? false,
        directUrl: j['_directUrl'],
      );

  String get label {
    final size = filesize != null ? ' (${_formatBytes(filesize!)})' : '';
    if (!hasVideo && !hasAudio) return '${quality.isNotEmpty ? quality : ext.toUpperCase()} Image$size';
    if (!hasVideo && hasAudio) return '${ext.toUpperCase()} Audio$size';
    return '$quality ${ext.toUpperCase()}$size';
  }

  String get icon => hasVideo ? '⬇' : (hasAudio ? '🎵' : '🖼');

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class MediaInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final String? platform;
  final List<MediaFormat> formats;

  const MediaInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    this.platform,
    required this.formats,
  });

  factory MediaInfo.fromJson(Map<String, dynamic> j) => MediaInfo(
        title: j['title'] ?? 'Untitled',
        thumbnail: j['thumbnail'],
        duration: j['duration'],
        uploader: j['uploader'],
        platform: j['platform'],
        formats: (j['formats'] as List? ?? [])
            .map((f) => MediaFormat.fromJson(f))
            .toList(),
      );

  String get durationLabel {
    if (duration == null) return '';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    final s = duration! % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
