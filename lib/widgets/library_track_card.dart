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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isActive
            ? const Color(0xFF7C4DFF).withValues(alpha: 0.15)
            : const Color(0xFF1C1C2E),
        border: Border.all(
          color: isActive
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 54,
                        height: 54,
                        color: const Color(0xFF252540),
                        child: const Icon(Icons.music_note,
                            color: Colors.white24),
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.play_arrow_rounded,
                        color: const Color(0xFF7C4DFF),
                        size: 26,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF9D7EFF)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                track.durationFormatted,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
              ),
              const SizedBox(width: 4),

              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.redAccent),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(left: 8),
                tooltip: 'Удалить',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
