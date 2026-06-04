import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';

class TrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const TrackCard({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadService>();
    final db = context.watch<DatabaseService>();
    final progress = dl.getProgress(track.id);
    final isDownloaded = db.isDownloaded(track.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              _Thumbnail(url: track.thumbnailUrl),
              const SizedBox(width: 12),

              // Info
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
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (progress != null &&
                        progress.status == DownloadStatus.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(
                            value: progress.progress),
                      ),
                    if (progress?.status == DownloadStatus.converting)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            const SizedBox(width: 6),
                            Text('Конвертация в MP3…',
                                style:
                                    Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    if (progress?.status == DownloadStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          progress!.error ?? 'Ошибка',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.red),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Duration + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.durationFormatted,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  _StatusIcon(
                      isDownloaded: isDownloaded, progress: progress),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(context),
        errorWidget: (_, __, ___) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: 56,
        height: 56,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.music_note),
      );
}

class _StatusIcon extends StatelessWidget {
  final bool isDownloaded;
  final DownloadProgress? progress;

  const _StatusIcon({required this.isDownloaded, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (isDownloaded) {
      return const Icon(Icons.download_done_rounded,
          size: 18, color: Colors.green);
    }
    if (progress?.status == DownloadStatus.downloading ||
        progress?.status == DownloadStatus.converting) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress?.status == DownloadStatus.downloading
                ? progress?.progress
                : null),
      );
    }
    return Icon(Icons.download_outlined,
        size: 18, color: Theme.of(context).colorScheme.outline);
  }
}
