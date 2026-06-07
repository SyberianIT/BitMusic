import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';
import 'database_service.dart';
import 'source_resolver.dart';
import 'youtube_service.dart';

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

  /// Downloads from the best available source (YouTube → SoundCloud → …).
  Future<void> downloadTrack(
    Track track,
    YouTubeService ytService,
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

      // 1. Resolve sources sorted by quality (highest bitrate first)
      final sources = await _resolver.resolve(
        '${track.artist} ${track.title}',
        youtubeVideoId: track.videoId,
      );

      if (sources.isEmpty) {
        // Fallback: use youtube_explode directly (original behaviour)
        await _fallbackYouTube(track, ytService, dbService, musicDir);
        return;
      }

      final best = sources.first;
      final safeTitle =
          track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');

      // 2. Download selected source
      final rawExt = _extFor(best.format);
      final rawPath = '$musicDir/${safeTitle}_${track.videoId}.$rawExt';
      await _downloadUrl(track.id, best.streamUrl, rawPath, best.headers);

      // 3. Optional MP3 conversion on desktop
      String finalPath = rawPath;
      if (!Platform.isAndroid && !Platform.isIOS) {
        _update(track.id, DownloadStatus.converting, 0.95,
            provider: best.provider);
        final mp3Path = '$musicDir/${safeTitle}_${track.videoId}.mp3';
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

  /// Downloads directly from a pre-resolved [AudioSource] (skips re-resolution).
  Future<void> downloadFromSource(
    Track track,
    AudioSource source,
    DatabaseService dbService,
  ) async {
    if (isDownloading(track.id)) return;
    _update(track.id, DownloadStatus.downloading, 0.0, provider: source.provider);

    try {
      final musicDir = await _getMusicDirectory();
      if (musicDir == null) {
        _error(track.id, 'Нет доступа к хранилищу');
        return;
      }

      final safeTitle =
          track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
      final rawExt = _extFor(source.format);
      final rawPath = '$musicDir/${safeTitle}_${track.videoId}.$rawExt';
      await _downloadUrl(track.id, source.streamUrl, rawPath, source.headers);

      String finalPath = rawPath;
      if (!Platform.isAndroid && !Platform.isIOS) {
        _update(track.id, DownloadStatus.converting, 0.95,
            provider: source.provider);
        final mp3Path = '$musicDir/${safeTitle}_${track.videoId}.mp3';
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
    } on SocketException {
      _error(track.id, 'Нет подключения к интернету');
    } catch (e) {
      _error(track.id, 'Ошибка: $e');
    }
  }

  // ── Download via Dio (supports progress) ──────────────────────────────────

  Future<void> _downloadUrl(
    String trackId,
    String url,
    String savePath,
    Map<String, String> extraHeaders,
  ) async {
    await _dio.download(
      url,
      savePath,
      options: Options(headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; BitMusic/1.0)',
        ...extraHeaders,
      }),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _update(trackId, DownloadStatus.downloading, received / total);
        }
      },
    );
  }

  // ── Fallback: original youtube_explode stream (when resolver fails) ────────

  Future<void> _fallbackYouTube(
    Track track,
    YouTubeService ytService,
    DatabaseService dbService,
    String musicDir,
  ) async {
    final manifest = await ytService.getStreamManifest(track.videoId);
    if (manifest == null) {
      _error(track.id, 'Не удалось получить аудиопоток');
      return;
    }
    final streams = manifest.audioOnly.sortByBitrate();
    AudioOnlyStreamInfo best;
    try {
      best = streams.lastWhere((s) => s.audioCodec.contains('mp4a'));
    } catch (_) {
      best = streams.last;
    }

    final ext = best.audioCodec.contains('mp4a') ? 'm4a' : 'webm';
    final safeTitle =
        track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final path = '$musicDir/${safeTitle}_${track.videoId}.$ext';

    final sink = File(path).openWrite();
    final total = best.size.totalBytes.toDouble();
    int done = 0;
    try {
      await for (final chunk in ytService.getAudioStream(best)) {
        sink.add(chunk);
        done += chunk.length;
        _update(track.id, DownloadStatus.downloading,
            total > 0 ? done / total : 0,
            provider: AudioProvider.youtube);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    await dbService.saveTrack(track.copyWith(
      localPath: path,
      isDownloaded: true,
      downloadedAt: DateTime.now(),
    ));
    _update(track.id, DownloadStatus.done, 1.0,
        provider: AudioProvider.youtube);
    await Future.delayed(const Duration(seconds: 3));
    _downloads.remove(track.id);
    notifyListeners();
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
      // App-scoped external storage requires no permissions on any API level.
      // Falls back to internal documents dir if external storage is unavailable.
      final extDir = await getExternalStorageDirectory();
      final base = extDir?.path ?? (await getApplicationDocumentsDirectory()).path;
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
