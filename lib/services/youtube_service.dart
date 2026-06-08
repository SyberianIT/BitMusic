import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';

class YouTubeService extends ChangeNotifier {
  final _yt = YoutubeExplode();

  List<Track> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  List<Track> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _isLoading = true;
    _error = null;
    _searchResults = [];
    notifyListeners();

    try {
      final searchList = await _yt.search.search(query);
      final videos = searchList.whereType<SearchVideo>().take(10).toList();

      _searchResults = videos
          .map((v) => Track(
                id: v.id.value,
                videoId: v.id.value,
                title: v.title,
                artist: v.author,
                durationSeconds: _durationSeconds(v.duration),
                thumbnailUrl:
                    'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
              ))
          .toList();
    } on SocketException {
      _error = 'Нет подключения к интернету';
    } on VideoUnplayableException {
      _error = 'Видео недоступно';
    } catch (e) {
      _error = 'Ошибка поиска: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the stream manifest for the given video or null on error.
  Future<StreamManifest?> getStreamManifest(String videoId) async {
    try {
      return await _yt.videos.streamsClient.getManifest(videoId);
    } on VideoUnplayableException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns a stream of bytes for the given [streamInfo].
  Stream<List<int>> getAudioStream(AudioOnlyStreamInfo streamInfo) {
    return _yt.videos.streamsClient.get(streamInfo);
  }

  // Handles both Duration and String (e.g. "3:45") returned by youtube_explode
  static int _durationSeconds(dynamic d) {
    if (d == null) return 0;
    if (d is Duration) return d.inSeconds;
    final s = d.toString();
    final parts = s.split(':').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    if (parts.length == 2) return parts[0] * 60 + parts[1];
    return 0;
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
