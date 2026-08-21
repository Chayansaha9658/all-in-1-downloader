class FormatOption {
  final String formatId;
  final String ext;
  final String? resolution;
  final double? fps;
  final int? filesize;
  final String? vcodec;
  final String? acodec;
  final String? note;

  FormatOption({
    required this.formatId,
    required this.ext,
    this.resolution,
    this.fps,
    this.filesize,
    this.vcodec,
    this.acodec,
    this.note,
  });

  factory FormatOption.fromJson(Map<String, dynamic> json) {
    return FormatOption(
      formatId: json['format_id'] as String,
      ext: json['ext'] as String? ?? '',
      resolution: json['resolution'] as String?,
      fps: (json['fps'] as num?)?.toDouble(),
      filesize: json['filesize'] as int?,
      vcodec: json['vcodec'] as String?,
      acodec: json['acodec'] as String?,
      note: json['note'] as String?,
    );
  }

  bool get hasVideo => vcodec != null && vcodec != 'none';
  bool get hasAudio => acodec != null && acodec != 'none';

  int? get height {
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(resolution ?? '');
    if (match != null) return int.tryParse(match.group(2)!);
    final noteMatch = RegExp(r'(\d{3,4})p').firstMatch(note ?? '');
    if (noteMatch != null) return int.tryParse(noteMatch.group(1)!);
    return null;
  }
}

class VideoInfo {
  final String title;
  final String? thumbnail;
  final double? duration;
  final String? uploader;
  final String extractor;
  final List<FormatOption> formats;

  VideoInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    required this.extractor,
    required this.formats,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      title: json['title'] as String? ?? 'Untitled',
      thumbnail: json['thumbnail'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      uploader: json['uploader'] as String?,
      extractor: json['extractor'] as String? ?? 'generic',
      formats: (json['formats'] as List<dynamic>? ?? [])
          .map((f) => FormatOption.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ResolutionChoice {
  final int height;
  final String formatSelector;
  final int? estimatedBytes;

  ResolutionChoice({
    required this.height,
    required this.formatSelector,
    this.estimatedBytes,
  });

  String get label => height >= 2160 ? '2160p (4K)' : '${height}p';
}

const standardHeights = {144, 240, 360, 480, 720, 1080, 1440, 2160};

int _nearestStandardHeight(int height) {
  return standardHeights.reduce(
    (a, b) => (height - a).abs() <= (height - b).abs() ? a : b,
  );
}

List<ResolutionChoice> buildResolutionLadder(VideoInfo info) {
  final videoFormats = info.formats
      .where((f) => f.hasVideo && f.height != null)
      .toList();
  if (videoFormats.isEmpty) return [];

  FormatOption? bestAudio;
  for (final f in info.formats) {
    if (!f.hasAudio || f.hasVideo) continue;
    if (bestAudio == null || (f.filesize ?? 0) > (bestAudio.filesize ?? 0)) {
      bestAudio = f;
    }
  }

  final byHeight = <int, FormatOption>{};
  for (final f in videoFormats) {
    final h = _nearestStandardHeight(f.height!);
    final current = byHeight[h];
    if (current == null || (f.filesize ?? 0) > (current.filesize ?? 0)) {
      byHeight[h] = f;
    }
  }

  final heights = byHeight.keys.toList()..sort((a, b) => b.compareTo(a));

  final audio = bestAudio;

  return heights.map((h) {
    final fmt = byHeight[h]!;
    final size =
        (fmt.filesize ?? 0) + ((fmt.hasAudio ? 0 : (audio?.filesize ?? 0)));
    return ResolutionChoice(
      height: h,
      // Send the target height, not a literal itag -- the backend resolves the best
      // available format at/below this height per player client, since exact itags
      // aren't consistent across different YouTube player clients.
      formatSelector: h.toString(),
      estimatedBytes: size > 0 ? size : null,
    );
  }).toList();
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unitIndex]}';
}
