/// Unified multi-source audio resolver.
///
/// Priority order (best quality first):
///   1. YouTube  — up to 256 kbps AAC or 160 kbps Opus via youtube_explode_dart
///   2. SoundCloud — original upload (often 128–320 kbps MP3) via public API
///   3. Direct URL — any http/https link the user pastes
///
/// Each resolver returns [AudioSource] with a stream URL, bitrate estimate,
/// format, and provider name so DownloadService can pick the best.
library;


import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

enum AudioProvider { youtube, soundcloud, direct }

class AudioSource {
  final AudioProvider provider;
  final String streamUrl;
  final String format;       // 'aac', 'mp3', 'opus', 'wav', etc.
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
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// Resolves all available audio sources for [query] (title + artist)
  /// and returns them sorted by quality (highest bitrate first).
  Future<List<AudioSource>> resolve(String query,
      {String? youtubeVideoId}) async {
    final results = await Future.wait([
      _resolveYouTube(youtubeVideoId ?? query),
      _resolveSoundCloud(query),
    ], eagerError: false);

    final sources = results
        .expand((r) => r ?? <AudioSource>[])
        .toList()
      ..sort((a, b) => b.bitrateKbps.compareTo(a.bitrateKbps));

    return sources;
  }

  // ── YouTube ────────────────────────────────────────────────────────────────

  Future<List<AudioSource>?> _resolveYouTube(String videoIdOrQuery) async {
    try {
      String videoId;
      if (_looksLikeYouTubeId(videoIdOrQuery)) {
        videoId = videoIdOrQuery;
      } else {
        final results = await _yt.search.search(videoIdOrQuery);
        final first = results.whereType<SearchVideo>().firstOrNull;
        if (first == null) return null;
        videoId = first.id.value;
      }

      final manifest =
          await _yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly.sortByBitrate();

      final sources = <AudioSource>[];
      for (final s in streams) {
        final isAac = s.audioCodec.contains('mp4a');
        // Expose the temporary signed URL from youtube_explode
        final url = s.url.toString();
        sources.add(AudioSource(
          provider: AudioProvider.youtube,
          streamUrl: url,
          format: isAac ? 'aac' : 'opus',
          bitrateKbps: (s.bitrate.kiloBitsPerSecond).round(),
        ));
      }
      return sources;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeYouTubeId(String s) =>
      RegExp(r'^[A-Za-z0-9_\-]{11}$').hasMatch(s);

  // ── SoundCloud ─────────────────────────────────────────────────────────────
  //
  // Uses SoundCloud's public widget/resolve endpoint — no OAuth needed.
  // Resolves track search → stream URL.

  static const _scClientId = 'iZIs9mchVcX5lhVRyQNGUDPoMwLAQ20H'; // public key

  Future<List<AudioSource>?> _resolveSoundCloud(String query) async {
    try {
      // 1. Search
      final searchResp = await _dio.get(
        'https://api-v2.soundcloud.com/search/tracks',
        queryParameters: {
          'q': query,
          'client_id': _scClientId,
          'limit': 3,
          'offset': 0,
        },
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (compatible; BitMusic/1.0)',
        }),
      );

      final collection = (searchResp.data['collection'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (collection.isEmpty) return null;

      final track = collection.first;
      final List<dynamic>? media =
          ((track['media'] as Map<String, dynamic>?)?['transcodings'] as List?);
      if (media == null) return null;

      // Find the best progressive MP3 stream
      final transcoding = media
          .whereType<Map<String, dynamic>>()
          .where((t) =>
              (t['format'] as Map?)?['protocol'] == 'progressive' &&
              (t['format'] as Map?)?['mime_type']
                      ?.toString()
                      .contains('mpeg') ==
                  true)
          .firstOrNull;
      if (transcoding == null) return null;

      // 2. Resolve stream URL
      final streamUrl = transcoding['url'] as String;
      final streamResp = await _dio.get(
        streamUrl,
        queryParameters: {'client_id': _scClientId},
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; BitMusic/1.0)',
        }),
      );

      final url = streamResp.data['url'] as String?;
      if (url == null) return null;

      return [
        AudioSource(
          provider: AudioProvider.soundcloud,
          streamUrl: url,
          format: 'mp3',
          bitrateKbps: 128, // SoundCloud free = 128 kbps MP3
        ),
      ];
    } catch (_) {
      return null;
    }
  }

  // ── Direct URL ─────────────────────────────────────────────────────────────

  /// Adds a user-provided direct URL as an audio source (no validation).
  AudioSource directUrl(String url) {
    final ext = url.split('?').first.split('.').lastOrNull ?? 'mp3';
    return AudioSource(
      provider: AudioProvider.direct,
      streamUrl: url,
      format: ext.toLowerCase(),
      bitrateKbps: 320, // assume best
    );
  }

  void dispose() {
    _yt.close();
    _dio.close();
  }
}
