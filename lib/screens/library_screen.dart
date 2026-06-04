import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Моя музыка',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (db.tracks.isNotEmpty)
                  Text(
                    '${db.tracks.length} тр.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ),
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
                        isActive: player.currentTrack?.id == track.id,
                        isPlaying:
                            player.currentTrack?.id == track.id &&
                                player.isPlaying,
                        onTap: () =>
                            context.read<PlayerService>().play(track),
                        onDelete: () =>
                            _confirmDelete(context, track),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music,
              size: 80,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Нет скачанных треков',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Найдите трек и нажмите «Скачать»',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text(
            '"${track.title}" будет удалён с устройства без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteTrack(context, track);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrack(BuildContext context, Track track) async {
    final db = context.read<DatabaseService>();
    final player = context.read<PlayerService>();

    if (player.currentTrack?.id == track.id) {
      await player.stop();
    }

    if (track.localPath != null) {
      final file = File(track.localPath!);
      if (await file.exists()) await file.delete();
    }

    await db.deleteTrack(track.id);
  }
}
