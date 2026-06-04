import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
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
    final isDownloading = progress?.status == DownloadStatus.downloading ||
        progress?.status == DownloadStatus.converting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(track.artist,
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(track.durationFormatted,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            )),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (isDownloading) ...[
            // Download progress
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                      value: progress?.status == DownloadStatus.converting
                          ? null
                          : progress?.progress),
                  const SizedBox(height: 8),
                  Text(
                    progress?.status == DownloadStatus.converting
                        ? 'Конвертация в MP3…'
                        : 'Скачивание: '
                            '${((progress?.progress ?? 0) * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ] else if (isDownloaded) ...[
            // Already downloaded — play option
            _Option(
              icon: Icons.play_circle_fill_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: 'Слушать',
              subtitle: 'Воспроизвести трек',
              onTap: () {
                Navigator.pop(context);
                final saved = db.getTrack(track.id);
                if (saved != null) {
                  context.read<PlayerService>().play(saved);
                }
              },
            ),
            _Option(
              icon: Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              title: 'Удалить загрузку',
              subtitle: 'Освободить место',
              onTap: () {
                Navigator.pop(context);
                // Delegate to library screen logic
              },
            ),
          ] else ...[
            // Not downloaded
            _Option(
              icon: Icons.download_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: 'Скачать аудио',
              subtitle: 'Лучшее качество (AAC/OPUS → MP3 на ПК)',
              onTap: () {
                Navigator.pop(context);
                _startDownload(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _startDownload(BuildContext context) {
    final dl = context.read<DownloadService>();
    final yt = context.read<YouTubeService>();
    final db = context.read<DatabaseService>();

    dl.downloadTrack(track, yt, db);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Загружается: ${track.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title),
      subtitle: Text(subtitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
