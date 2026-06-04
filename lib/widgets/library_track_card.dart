import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';

class LibraryTrackCard extends StatelessWidget {
  final Track track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const LibraryTrackCard({
    super.key,
    required this.track,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isActive ? cs.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail with play overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying ? Icons.graphic_eq : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isActive ? cs.primary : null,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Duration
              Text(track.durationFormatted,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: cs.error,
                tooltip: 'Удалить',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
