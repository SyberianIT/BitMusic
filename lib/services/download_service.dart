import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'database_service.dart';
import 'source_resolver.dart';

export 'source_resolver.dart' show AudioProvider, AudioSource;

enum DownloadStatus { idle, downloading, converting, done, error }

class DownloadProgress {
  final String trackId;
  final DownloadStatus status;
  final double progress;
  final String? error;
  final AudioProvider? provider;

  const DownloadProgress({
    required this.trackId,
    required this.status,
    this.progress = 0.0,
    this.error,
    this.provider,
  });
}

class DownloadService extends ChangeNotifier {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 5),
  ));
  final _resolver = SourceResolver();
  final Map<String, DownloadProgress> _downloads = {};

  DownloadProgress? getProgress(String trackId) => _downloads[trackId];
  bool isDownloading(String trackId) =>
      _downloads[trackId]?.status == DownloadStatus.downloading;

  /// Downloads the best available audio for [track].
  /// Searches YouTube by "artist title" — works with Deezer and YouTube tracks.
  Future<void> downloadTrack(Track track, DatabaseService dbService) async {
    if (isDownloading(track.id)) return;
    _update(track.id, DownloadStatus.downloading, 0.0);

    try {
      final musicDir = await _getMusicDirectory();
      if (musicDir == null) {
        _error(track.id, 'Нет доступа к хранилищу');
        return;
      }

      final query = '${track.artist} ${track.title}';
      final sources = await _resolver.resolve(query);

      if (sources.isEmpty) {
        _error(track.id, 'Источник не найден. Проверьте интернет-соединение.');
        return;
      }

      final best = sources.first;
      final safeTitle =
          track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
      final ext = best.format == 'aac' ? 'm4a' : best.format;
      final fileId = track.id.replaceAll('dz_', '');
      final path = '$musicDir/${safeTitle}_$fileId.$ext';

      await _downloadUrl(track.id, best.streamUrl, path, best.headers,
          provider: best.provider);

      await dbService.saveTrack(track.copyWith(
        localPath: path,
        isDownloaded: true,
        downloadedAt: DateTime.now(),
      ));

      _update(track.id, DownloadStatus.done, 1.0, provider: best.provider);
      await Future.delayed(const Duration(seconds: 3));
      _downloads.remove(track.id);
      notifyListeners();
    } on SocketException {
      _error(track.id, 'Нет подключения к интернету');
    } catch (e) {
      _error(track.id, 'Ошибка: $e');
    }
  }

  /// Downloads directly from a pre-resolved [AudioSource].
  Future<void> downloadFromSource(
    Track track,
    AudioSource source,
    DatabaseService dbService,
  ) async {
    if (isDownloading(track.id)) return;
    _update(track.id, DownloadStatus.downloading, 0.0,
        provider: source.provider);

    try {
      final musicDir = await _getMusicDirectory();
      if (musicDir == null) {
        _error(track.id, 'Нет доступа к хранилищу');
        return;
      }

      final safeTitle =
          track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
      final ext = source.format == 'aac' ? 'm4a' : source.format;
      final fileId = track.id.replaceAll('dz_', '');
      final path = '$musicDir/${safeTitle}_$fileId.$ext';

      await _downloadUrl(track.id, source.streamUrl, path, source.headers,
          provider: source.provider);

      await dbService.saveTrack(track.copyWith(
        localPath: path,
        isDownloaded: true,
        downloadedAt: DateTime.now(),
      ));

      _update(track.id, DownloadStatus.done, 1.0, provider: source.provider);
      await Future.delayed(const Duration(seconds: 3));
      _downloads.remove(track.id);
      notifyListeners();
    } on SocketException {
      _error(track.id, 'Нет подключения к интернету');
    } catch (e) {
      _error(track.id, 'Ошибка: $e');
    }
  }

  Future<void> _downloadUrl(
    String trackId,
    String url,
    String savePath,
    Map<String, String> extraHeaders, {
    AudioProvider? provider,
  }) async {
    await _dio.download(
      url,
      savePath,
      options: Options(headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; BitMusic/1.0)',
        ...extraHeaders,
      }),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _update(trackId, DownloadStatus.downloading, received / total,
              provider: provider);
        }
      },
    );
  }

  Future<String?> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      final base =
          extDir?.path ?? (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$base/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }
    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$home/Music/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }
    if (Platform.isWindows) {
      final up = Platform.environment['USERPROFILE'] ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$up\\Music\\BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/BitMusic');
    await dir.create(recursive: true);
    return dir.path;
  }

  void _update(String id, DownloadStatus status, double progress,
      {String? error, AudioProvider? provider}) {
    _downloads[id] = DownloadProgress(
      trackId: id,
      status: status,
      progress: progress,
      error: error,
      provider: provider,
    );
    notifyListeners();
  }

  void _error(String id, String msg) =>
      _update(id, DownloadStatus.error, 0.0, error: msg);

  @override
  void dispose() {
    _dio.close();
    _resolver.dispose();
    super.dispose();
  }
}
