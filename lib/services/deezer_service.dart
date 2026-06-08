import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/track.dart';

class DeezerService extends ChangeNotifier {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
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

      final data = resp.data as Map<String, dynamic>;
      final items =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
              [];

      _searchResults = items.map((item) {
        final id = item['id'] as int? ?? 0;
        final title = item['title'] as String? ?? '';
        final artist =
            (item['artist'] as Map?)?['name'] as String? ?? '';
        final duration = item['duration'] as int? ?? 0;
        final album = item['album'] as Map?;
        final thumbnailUrl = (album?['cover_xl'] ??
                album?['cover_big'] ??
                album?['cover_medium'] ??
                '') as String;

        return Track(
          id: 'dz_$id',
          videoId: '',
          title: title,
          artist: artist,
          durationSeconds: duration,
          thumbnailUrl: thumbnailUrl,
        );
      }).toList();
    } on SocketException {
      _error = 'Нет подключения к интернету';
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
