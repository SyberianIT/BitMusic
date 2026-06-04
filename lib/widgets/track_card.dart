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
      color: const Color(0xFF1C1C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFF252540),
                    child: const Icon(Icons.music_note,
                        color: Colors.white24, size: 24),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFF252540),
                    child: const Icon(Icons.music_note,
                        color: Colors.white24, size: 24),
                  ),
                ),
              ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                    if (progress?.status == DownloadStatus.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.progress,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF7C4DFF)),
                            minHeight: 3,
                          ),
                        ),
                      ),
                    if (progress?.status == DownloadStatus.converting)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Color(0xFFE040FB)))),
                          const SizedBox(width: 6),
                          Text('MP3…',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ]),
                      ),
                    if (progress?.status == DownloadStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          progress!.error ?? 'Ошибка',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.durationFormatted,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _StatusBadge(
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

class _StatusBadge extends StatelessWidget {
  final bool isDownloaded;
  final DownloadProgress? progress;
  const _StatusBadge({required this.isDownloaded, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.green),
      );
    }
    final st = progress?.status;
    if (st == DownloadStatus.downloading || st == DownloadStatus.converting) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: st == DownloadStatus.downloading ? progress?.progress : null,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
          backgroundColor: Colors.white12,
        ),
      );
    }
    return Icon(Icons.download_outlined,
        size: 18, color: Colors.white.withValues(alpha: 0.3));
  }
}
