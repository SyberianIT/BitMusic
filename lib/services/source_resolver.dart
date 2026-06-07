library;

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum AudioProvider { youtube, direct }

class AudioSource {
  final AudioProvider provider;
  final String streamUrl;
  final String format;
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
  String toString() => '[${provider.name}] $format @ ${bitrateKbps}k';
}

class SourceResolver {
  final _yt = YoutubeExplode();

  /// Resolves audio sources for [query] ("Artist Title").
  /// Always searches YouTube by query — works for both Deezer and YouTube tracks.
  Future<List<AudioSource>> resolve(String query) async {
    try {
      final videoId = await _findYouTubeId(query);
      if (videoId == null) return [];

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly.sortByBitrate();

      return streams.map((s) {
        final isAac = s.audioCodec.contains('mp4a');
        return AudioSource(
          provider: AudioProvider.youtube,
          streamUrl: s.url.toString(),
          format: isAac ? 'aac' : 'opus',
          bitrateKbps: s.bitrate.kiloBitsPerSecond.round(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _findYouTubeId(String query) async {
    try {
      final results = await _yt.search.search(query);
      return results.whereType<SearchVideo>().firstOrNull?.id.value;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _yt.close();
}
