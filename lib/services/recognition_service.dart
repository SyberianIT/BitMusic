import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum RecognitionState { idle, listening, recognizing, found, notFound, error }

class RecognitionResult {
  final String title;
  final String artist;
  final String? album;
  final String? releaseDate;
  final String? thumbnailUrl;

  const RecognitionResult({
    required this.title,
    required this.artist,
    this.album,
    this.releaseDate,
    this.thumbnailUrl,
  });

  /// Query to feed directly into YouTubeService.search()
  String get searchQuery => '$artist $title';
}

class RecognitionService extends ChangeNotifier {
  static const _apiUrl = 'https://api.audd.io/';
  static const _settingsBox = 'bm_settings';

  final _recorder = AudioRecorder();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  RecognitionState _state = RecognitionState.idle;
  RecognitionResult? _result;
  String? _error;
  String? _recordingPath;
  String _apiKey = '';

  RecognitionState get state => _state;
  RecognitionResult? get result => _result;
  String? get error => _error;
  String get apiKey => _apiKey;

  Future<void> loadSettings() async {
    final box = await Hive.openBox(_settingsBox);
    _apiKey = box.get('audd_api_key', defaultValue: '') as String;
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key.trim();
    final box = await Hive.openBox(_settingsBox);
    await box.put('audd_api_key', _apiKey);
    notifyListeners();
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    _state = RecognitionState.idle;
    _result = null;
    _error = null;
    notifyListeners();

    // Check microphone permission
    if (!await _recorder.hasPermission()) {
      _error = 'Нет доступа к микрофону. Разрешите его в настройках приложения.';
      _state = RecognitionState.error;
      notifyListeners();
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/bm_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _recordingPath!,
      );

      _state = RecognitionState.listening;
      notifyListeners();

      // Auto-submit after 10 s
      Future.delayed(const Duration(seconds: 10), () {
        if (_state == RecognitionState.listening) recognize();
      });
    } catch (e) {
      _error = 'Ошибка записи: $e';
      _state = RecognitionState.error;
      notifyListeners();
    }
  }

  // ── Recognition ────────────────────────────────────────────────────────────

  Future<void> recognize() async {
    if (_state != RecognitionState.listening) return;

    _state = RecognitionState.recognizing;
    notifyListeners();

    try {
      await _recorder.stop();

      if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
        throw Exception('Файл записи не найден');
      }

      final formData = FormData.fromMap({
        if (_apiKey.isNotEmpty) 'api_token': _apiKey,
        'file': await MultipartFile.fromFile(
          _recordingPath!,
          filename: 'audio.m4a',
          contentType: DioMediaType('audio', 'm4a'),
        ),
        'return': 'spotify',
      });

      final resp = await _dio.post(_apiUrl, data: formData);

      // Dio may parse JSON automatically or leave it as String
      final Map<String, dynamic> json = resp.data is String
          ? jsonDecode(resp.data as String)
          : Map<String, dynamic>.from(resp.data as Map);

      if (json['status'] == 'success') {
        final r = json['result'];
        if (r == null) {
          _error = 'Трек не распознан. Попробуйте ещё раз или поднесите устройство ближе к источнику звука.';
          _state = RecognitionState.notFound;
        } else {
          final track = r as Map<String, dynamic>;
          _result = RecognitionResult(
            title: (track['title'] as String?) ?? 'Неизвестно',
            artist: (track['artist'] as String?) ?? 'Неизвестно',
            album: track['album'] as String?,
            releaseDate: track['release_date'] as String?,
            thumbnailUrl: _extractThumbnail(track),
          );
          _state = RecognitionState.found;
        }
      } else {
        final errMsg = (json['error'] as Map<String, dynamic>?)?['error_message'];
        _error = errMsg as String? ?? 'Ошибка сервиса распознавания';
        _state = RecognitionState.error;
      }
    } on DioException catch (e) {
      _error = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'Превышено время ожидания. Проверьте интернет-соединение.',
        DioExceptionType.connectionError =>
          'Нет подключения к интернету.',
        _ => 'Ошибка сети: ${e.message}',
      };
      _state = RecognitionState.error;
    } catch (e) {
      _error = 'Ошибка: $e';
      _state = RecognitionState.error;
    } finally {
      _cleanTemp();
      notifyListeners();
    }
  }

  String? _extractThumbnail(Map<String, dynamic> track) {
    try {
      final spotify = track['spotify'] as Map<String, dynamic>?;
      final album = spotify?['album'] as Map<String, dynamic>?;
      final images = album?['images'] as List?;
      if (images != null && images.isNotEmpty) {
        return (images.first as Map<String, dynamic>)['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void _cleanTemp() {
    if (_recordingPath != null) {
      try {
        final f = File(_recordingPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      _recordingPath = null;
    }
  }

  // ── Control ────────────────────────────────────────────────────────────────

  Future<void> cancel() async {
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } catch (_) {}
    _cleanTemp();
  }

  void reset() {
    cancel();
    _state = RecognitionState.idle;
    _result = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _dio.close();
    super.dispose();
  }
}
