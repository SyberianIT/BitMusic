import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../screens/player_screen.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/youtube_service.dart';

class DownloadDialog extends StatelessWidget {
  final Track track;
  const DownloadDialog({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final dl = context.watch<DownloadService>();
    final isDownloaded = db.isDownloaded(track.id);
    final progress = dl.getProgress(track.id);
    final busy = progress?.status == DownloadStatus.downloading ||
        progress?.status == DownloadStatus.converting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFF252540),
                      child: const Icon(Icons.music_note,
                          color: Colors.white24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(track.artist,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                    Text(track.durationFormatted,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 4),

          if (busy)
            _ProgressIndicator(progress: progress)
          else if (isDownloaded) ...[
            _Action(
              icon: Icons.play_circle_fill_rounded,
              color: const Color(0xFF7C4DFF),
              label: 'Слушать',
              sub: 'Открыть плеер',
              onTap: () {
                Navigator.pop(context);
                final saved = db.getTrack(track.id);
                if (saved != null) {
                  context
                      .read<PlayerService>()
                      .play(saved, queue: db.tracks);
                  Navigator.of(context).push(PlayerScreen.route());
                }
              },
            ),
          ] else ...[
            _Action(
              icon: Icons.download_rounded,
              color: const Color(0xFF7C4DFF),
              label: 'Скачать аудио',
              sub: 'Лучшее качество · AAC/OPUS · MP3 на ПК',
              onTap: () {
                Navigator.pop(context);
                _download(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _download(BuildContext context) {
    context
        .read<DownloadService>()
        .downloadTrack(track, context.read<YouTubeService>(),
            context.read<DatabaseService>());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1C1C2E),
      content: Text('Загружается: ${track.title}',
          style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ));
  }
}

class _ProgressIndicator extends StatelessWidget {
  final DownloadProgress? progress;
  const _ProgressIndicator({this.progress});

  @override
  Widget build(BuildContext context) {
    final isConverting = progress?.status == DownloadStatus.converting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isConverting ? null : progress?.progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConverting
                ? 'Конвертация в MP3…'
                : 'Скачивание ${((progress?.progress ?? 0) * 100).toInt()}%',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _Action(
      {required this.icon,
      required this.color,
      required this.label,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(sub,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
