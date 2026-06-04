import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/youtube_service.dart';
import '../widgets/download_dialog.dart';
import '../widgets/track_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _search() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    context.read<YouTubeService>().search(q);
    _focusNode.unfocus();
  }

  void _showOptions(Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DownloadDialog(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ytService = context.watch<YouTubeService>();

    return SafeArea(
      child: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Трек, исполнитель, строки из текста…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      filled: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _search,
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),

          // ── Results ─────────────────────────────────────────────
          Expanded(child: _buildBody(ytService)),
        ],
      ),
    );
  }

  Widget _buildBody(YouTubeService svc) {
    if (svc.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (svc.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                svc.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _search,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (svc.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note,
                size: 80,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Введите запрос для поиска музыки',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: svc.searchResults.length,
      itemBuilder: (ctx, i) {
        final track = svc.searchResults[i];
        return TrackCard(
          track: track,
          onTap: () => _showOptions(track),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
