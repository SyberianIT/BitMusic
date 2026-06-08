library;

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

enum AudioProvider { youtube, direct }

class AudioSource {
  final AudioProvider provider;
  final String streamUrl;
  final String format; // 'aac', 'opus', 'wav', etc.
  final int bitrateKbps;
  final Map<String, String> headers;

  const AudioSource({
    required this.provider,
    required this.streamUrl,
    required this.format,
    required this.bitrateKbps,
    this.headers = const {},
  });

  @override
  String toString() =>
      '[${provider.name}] $format @ ${bitrateKbps}k — $streamUrl';
}

// ─── Resolver ─────────────────────────────────────────────────────────────────

class SourceResolver {
  final _yt = YoutubeExplode();

  /// Resolves all available audio sources for [query] (title + artist string
  /// or a YouTube video ID) and returns them sorted by quality (highest first).
  Future<List<AudioSource>> resolve(String query) async {
    final sources = await _resolveYouTube(query);
    if (sources == null || sources.isEmpty) return [];
    return sources..sort((a, b) => b.bitrateKbps.compareTo(a.bitrateKbps));
  }

  // ── YouTube ────────────────────────────────────────────────────────────────

  Future<List<AudioSource>?> _resolveYouTube(String query) async {
    try {
      String videoId;
      if (_looksLikeYouTubeId(query)) {
        videoId = query;
      } else {
        final results = await _yt.search.search(query);
        final first = results.whereType<SearchVideo>().firstOrNull;
        if (first == null) return null;
        videoId = first.id.value;
      }

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly.sortByBitrate();

      final sources = <AudioSource>[];
      for (final s in streams) {
        final isAac = s.audioCodec.contains('mp4a');
        sources.add(AudioSource(
          provider: AudioProvider.youtube,
          streamUrl: s.url.toString(),
          format: isAac ? 'aac' : 'opus',
          bitrateKbps: s.bitrate.kiloBitsPerSecond.round(),
        ));
      }
      return sources;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeYouTubeId(String s) =>
      RegExp(r'^[A-Za-z0-9_\-]{11}$').hasMatch(s);

  // ── Direct URL ─────────────────────────────────────────────────────────────

  AudioSource directUrl(String url) {
    final ext = url.split('?').first.split('.').lastOrNull ?? 'mp3';
    return AudioSource(
      provider: AudioProvider.direct,
      streamUrl: url,
      format: ext.toLowerCase(),
      bitrateKbps: 320,
    );
  }

  void dispose() => _yt.close();
}
