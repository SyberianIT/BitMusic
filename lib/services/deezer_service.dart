import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/track.dart';

class DeezerService extends ChangeNotifier {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'Mozilla/5.0 (compatible; BitMusic/1.0)'},
  ));

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
      final resp = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {'q': query, 'limit': 20, 'output': 'json'},
      );

      final list = (resp.data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      _searchResults = list
          .map((t) {
            final artist =
                (t['artist'] as Map?)?['name'] as String? ?? 'Unknown';
            final album = t['album'] as Map?;
            final cover = album?['cover_xl'] as String? ??
                album?['cover_big'] as String? ??
                album?['cover_medium'] as String? ??
                '';
            final title = t['title'] as String? ?? '';
            if (title.isEmpty) return null;
            return Track(
              id: 'dz_${t['id']}',
              videoId: '${t['id']}', // Deezer numeric ID — not a YouTube ID
              title: title,
              artist: artist,
              durationSeconds: (t['duration'] as num?)?.toInt() ?? 0,
              thumbnailUrl: cover,
            );
          })
          .whereType<Track>()
          .toList();
    } on DioException catch (e) {
      _error = e.type == DioExceptionType.connectionError
          ? 'Нет подключения к интернету'
          : 'Ошибка поиска: ${e.message}';
    } catch (e) {
      _error = 'Ошибка поиска: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
