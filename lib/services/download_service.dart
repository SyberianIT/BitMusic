import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';
import 'database_service.dart';
import 'youtube_service.dart';

enum DownloadStatus { idle, downloading, converting, done, error }

class DownloadProgress {
  final String trackId;
  final DownloadStatus status;
  final double progress;
  final String? error;

  const DownloadProgress({
    required this.trackId,
    required this.status,
    this.progress = 0.0,
    this.error,
  });
}

class DownloadService extends ChangeNotifier {
  final Map<String, DownloadProgress> _downloads = {};

  DownloadProgress? getProgress(String trackId) => _downloads[trackId];

  bool isDownloading(String trackId) =>
      _downloads[trackId]?.status == DownloadStatus.downloading;

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
        _update(track.id, DownloadStatus.error, 0.0,
            error: 'Нет доступа к хранилищу');
        return;
      }

      final manifest = await ytService.getStreamManifest(track.videoId);
      if (manifest == null) {
        _update(track.id, DownloadStatus.error, 0.0,
            error: 'Не удалось получить аудиопоток. Видео заблокировано?');
        return;
      }

      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isEmpty) {
        _update(track.id, DownloadStatus.error, 0.0,
            error: 'Нет аудиодорожки');
        return;
      }

      // Prefer AAC (m4a) over OPUS for widest player compatibility
      AudioOnlyStreamInfo bestStream;
      try {
        bestStream = audioStreams.lastWhere(
          (s) => s.audioCodec.contains('mp4a'),
        );
      } catch (_) {
        bestStream = audioStreams.last;
      }

      final isAac = bestStream.audioCodec.contains('mp4a');
      final rawExt = isAac ? 'm4a' : 'webm';
      final safeTitle =
          track.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
      final rawPath = '$musicDir/${safeTitle}_${track.videoId}.$rawExt';

      // Stream bytes to disk without loading into RAM
      final stream = ytService.getAudioStream(bestStream);
      final file = File(rawPath);
      final sink = file.openWrite();
      final totalBytes = bestStream.size.totalBytes.toDouble();
      int downloaded = 0;

      try {
        await for (final chunk in stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          _update(track.id, DownloadStatus.downloading,
              totalBytes > 0 ? downloaded / totalBytes : 0);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // Attempt MP3 conversion via system ffmpeg (desktop only)
      String finalPath = rawPath;
      if (!Platform.isAndroid && !Platform.isIOS) {
        _update(track.id, DownloadStatus.converting, 0.95);
        final mp3Path =
            '$musicDir/${safeTitle}_${track.videoId}.mp3';
        final converted = await _convertToMp3(rawPath, mp3Path);
        if (converted) {
          await File(rawPath).delete();
          finalPath = mp3Path;
        }
      }

      final saved = track.copyWith(
        localPath: finalPath,
        isDownloaded: true,
        downloadedAt: DateTime.now(),
      );
      await dbService.saveTrack(saved);

      _update(track.id, DownloadStatus.done, 1.0);

      // Auto-clear progress indicator
      await Future.delayed(const Duration(seconds: 3));
      _downloads.remove(track.id);
      notifyListeners();
    } on SocketException {
      _update(track.id, DownloadStatus.error, 0.0,
          error: 'Нет подключения к интернету');
    } catch (e) {
      _update(track.id, DownloadStatus.error, 0.0,
          error: 'Ошибка скачивания: $e');
    }
  }

  // ---------------------------------------------------------------------------

  Future<String?> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      bool granted = await Permission.storage.isGranted;
      if (!granted) {
        granted = (await Permission.storage.request()).isGranted;
      }
      // Android 10+ may need this
      if (!granted) {
        granted =
            (await Permission.manageExternalStorage.request()).isGranted;
      }
      if (!granted) return null;

      final dir = Directory('/storage/emulated/0/Music/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }

    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }

    // Desktop: Linux / Windows / macOS
    if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$home/Music/BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$userProfile\\Music\\BitMusic');
      await dir.create(recursive: true);
      return dir.path;
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/BitMusic');
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Converts [inputPath] to MP3 192 kbps using system ffmpeg.
  /// Returns true on success.
  Future<bool> _convertToMp3(String inputPath, String outputPath) async {
    try {
      final result = await Process.run('ffmpeg', [
        '-i', inputPath,
        '-codec:a', 'libmp3lame',
        '-b:a', '192k',
        '-y',
        outputPath,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      // ffmpeg not installed — keep original format
      return false;
    }
  }

  void _update(String id, DownloadStatus status, double progress,
      {String? error}) {
    _downloads[id] = DownloadProgress(
      trackId: id,
      status: status,
      progress: progress,
      error: error,
    );
    notifyListeners();
  }
}
