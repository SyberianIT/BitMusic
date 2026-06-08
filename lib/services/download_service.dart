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

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Downloads from YouTube (best available quality).
  Future<void> downloadTrack(
    Track track,
    DatabaseService dbService,
  ) async {
    if (isDownloading(track.id)) return;
    _update(track.id, DownloadStatus.downloading, 0.0);

    try {
      final musicDir = await _getMusicDirectory();
      if (musicDir == null) {
        _error(track.id, 'Нет доступа к хранилищу');
        return;
      }

      final query = track.videoId.length == 11 && track.videoId.isNotEmpty
          ? track.videoId
          : '${track.artist} ${track.title}';

      final sources = await _resolver.resolve(query);

      if (sources.isEmpty) {
        _error(track.id, 'Не удалось получить аудиопоток');
        return;
      }

      await _downloadSource(track, sources.first, dbService, musicDir);
    } on SocketException {
      _error(track.id, 'Нет подключения к интернету');
    } catch (e) {
      _error(track.id, 'Ошибка: $e');
    }
  }

  /// Downloads a specific [source] (chosen by the user in the dialog).
  Future<void> downloadFromSource(
    Track track,
    AudioSource source,
    DatabaseService dbService,
  ) async {
    if (isDownloading(track.id)) return;
    _update(track.id, DownloadStatus.downloading, 0.0);

    try {
      final musicDir = await _getMusicDirectory();
      if (musicDir == null) {
        _error(track.id, 'Нет доступа к хранилищу');
        return;
      }
      await _downloadSource(track, source, dbService, musicDir);
    } on SocketException {
      _error(track.id, 'Нет подключения к интернету');
    } catch (e) {
      _error(track.id, 'Ошибка: $e');
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _downloadSource(
    Track track,
    AudioSource source,
    DatabaseService dbService,
    String musicDir,
  ) async {
    final safeTitle =
        track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final rawExt = _extFor(source.format);
    final trackKey = track.videoId.isNotEmpty ? track.videoId : track.id;
    final rawPath = '$musicDir/${safeTitle}_$trackKey.$rawExt';

    await _downloadUrl(track.id, source.streamUrl, rawPath, source.headers,
        provider: source.provider);

    String finalPath = rawPath;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _update(track.id, DownloadStatus.converting, 0.95,
          provider: source.provider);
      final mp3Path = '$musicDir/${safeTitle}_$trackKey.mp3';
      if (await _convertToMp3(rawPath, mp3Path)) {
        await File(rawPath).delete();
        finalPath = mp3Path;
      }
    }

    await dbService.saveTrack(track.copyWith(
      localPath: finalPath,
      isDownloaded: true,
      downloadedAt: DateTime.now(),
    ));

    _update(track.id, DownloadStatus.done, 1.0, provider: source.provider);
    await Future.delayed(const Duration(seconds: 3));
    _downloads.remove(track.id);
    notifyListeners();
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _extFor(String format) => switch (format) {
        'aac' => 'm4a',
        'opus' => 'opus',
        'wav' => 'wav',
        'flac' => 'flac',
        _ => 'mp3',
      };

  Future<String?> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final music = Directory('${dir.path}/Music');
          await music.create(recursive: true);
          return music.path;
        }
      } catch (_) {}
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/Music');
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

  Future<bool> _convertToMp3(String input, String output) async {
    try {
      final r = await Process.run('ffmpeg', [
        '-i', input,
        '-codec:a', 'libmp3lame',
        '-b:a', '192k',
        '-y', output,
      ]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
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
