import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../screens/player_screen.dart';
import '../services/database_service.dart';
import '../services/player_service.dart';
import '../widgets/library_track_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final player = context.watch<PlayerService>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Моя музыка',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                if (db.tracks.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7C4DFF)),
                    icon: const Icon(Icons.play_circle_filled, size: 18),
                    label: const Text('Все'),
                    onPressed: () => _playAll(context, db.tracks),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 4),

          Expanded(
            child: db.tracks.isEmpty
                ? _empty(context)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: db.tracks.length,
                    itemBuilder: (ctx, i) {
                      final track = db.tracks[i];
                      return LibraryTrackCard(
                        track: track,
                        isActive:
                            player.currentTrack?.id == track.id,
                        isPlaying:
                            player.currentTrack?.id == track.id &&
                                player.isPlaying,
                        onTap: () {
                          player.play(track,
                              queue: db.tracks, index: i);
                          Navigator.of(context)
                              .push(PlayerScreen.route());
                        },
                        onDelete: () => _confirmDelete(ctx, track),
                      ).animate(delay: (i * 35).ms).fadeIn(
                          duration: 280.ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _playAll(BuildContext context, List<Track> tracks) {
    final player = context.read<PlayerService>();
    player.play(tracks.first, queue: tracks, index: 0);
    Navigator.of(context).push(PlayerScreen.route());
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
            ).createShader(r),
            child: const Icon(Icons.library_music, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('Нет скачанных треков',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
          const SizedBox(height: 6),
          Text('Найди трек и нажми «Скачать»',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 12)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        title: const Text('Удалить трек?',
            style: TextStyle(color: Colors.white)),
        content: Text('"${track.title}" будет удалён с устройства.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _delete(context, track);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Track track) async {
    final db = context.read<DatabaseService>();
    final player = context.read<PlayerService>();
    if (player.currentTrack?.id == track.id) await player.stop();
    if (track.localPath != null) {
      final f = File(track.localPath!);
      if (await f.exists()) await f.delete();
    }
    await db.deleteTrack(track.id);
  }
}
