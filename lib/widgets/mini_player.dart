import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/player_service.dart';
import 'spectrum_visualizer.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(PlayerScreen.route()),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1E35),
              cs.surfaceContainer,
            ],
          ),
          border: Border(
              top: BorderSide(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                  width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spectrum bar
            SizedBox(
              height: 28,
              child: SpectrumVisualizer(
                isPlaying: player.isPlaying,
                barCount: 60,
                height: 28,
                colorBottom: const Color(0xFF7C4DFF),
                colorTop: const Color(0xFFE040FB),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Thumbnail with Hero
                  Hero(
                    tag: 'art_${track.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: track.thumbnailUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF252540),
                          child: const Icon(Icons.music_note,
                              color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prev
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white54, size: 26),
                    onPressed: player.hasPrev ? player.skipPrev : null,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),

                  // Play / Pause
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        player.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        key: ValueKey(player.isPlaying),
                        color: const Color(0xFF7C4DFF),
                        size: 38,
                      ),
                    ),
                    onPressed: () {
                      player.isPlaying ? player.pause() : player.resume();
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white54, size: 26),
                    onPressed: player.hasNext ? player.skipNext : null,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}
