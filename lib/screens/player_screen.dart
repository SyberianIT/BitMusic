import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../widgets/spectrum_visualizer.dart';
import 'equalizer_screen.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        pageBuilder: (_, a, __) => const PlayerScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeInOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 320),
      );

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred album art background ─────────────────────────
          CachedNetworkImage(
            imageUrl: track.thumbnailUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF0D0D1A)),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // App bar
                _TopBar(onEqTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const EqualizerScreen()))),

                const Spacer(flex: 2),

                // Album art
                _AlbumArt(url: track.thumbnailUrl, heroTag: 'art_${track.id}')
                    .animate()
                    .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                // Title & artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                const SizedBox(height: 28),

                // Spectrum
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SpectrumVisualizer(
                    isPlaying: player.isPlaying,
                    mirrored: true,
                    height: 60,
                    barCount: 40,
                  ),
                ),

                const SizedBox(height: 20),

                // Seek bar
                _SeekBar(player: player),

                const SizedBox(height: 8),

                // Controls
                _Controls(player: player),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onEqTap;
  const _TopBar({required this.onEqTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'ВОСПРОИЗВЕДЕНИЕ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.equalizer_rounded,
                color: Colors.white, size: 26),
            onPressed: onEqTap,
            tooltip: 'Эквалайзер',
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String url;
  final String heroTag;
  const _AlbumArt({required this.url, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFF1C1C2E),
              child: const Icon(Icons.music_note, color: Colors.white38, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final PlayerService player;
  const _SeekBar({required this.player});

  String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
            ),
            child: Slider(
              value: player.progress,
              onChanged: (v) => player.seek(
                Duration(
                  milliseconds:
                      (player.duration.inMilliseconds * v).round(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(player.position),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                Text(_fmt(player.duration),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final PlayerService player;
  const _Controls({required this.player});

  @override
  Widget build(BuildContext context) {
    final loopIcon = switch (player.loopMode) {
      LoopMode.off => Icons.repeat_rounded,
      LoopMode.all => Icons.repeat_rounded,
      LoopMode.one => Icons.repeat_one_rounded,
    };
    final loopColor = player.loopMode == LoopMode.off
        ? Colors.white38
        : Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(Icons.shuffle_rounded,
              color: player.shuffle ? Colors.white : Colors.white38, size: 24),
          onPressed: player.toggleShuffle,
        ),
        // Prev
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              color: Colors.white, size: 40),
          onPressed: player.hasPrev ? player.skipPrev : null,
        ),
        // Play / Pause
        GestureDetector(
          onTap: () {
            player.isPlaying ? player.pause() : player.resume();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: const Color(0xFF0D0D1A),
              size: 38,
            ),
          ),
        ),
        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded,
              color: Colors.white, size: 40),
          onPressed: player.hasNext ? player.skipNext : null,
        ),
        // Loop
        IconButton(
          icon: Icon(loopIcon, color: loopColor, size: 24),
          onPressed: player.cycleLoop,
        ),
      ],
    );
  }
}
