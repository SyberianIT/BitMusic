import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/deezer_service.dart';
import '../widgets/download_dialog.dart';
import '../widgets/track_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  void _search() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    context.read<DeezerService>().search(q);
    _focus.unfocus();
  }

  void _showOptions(Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (_) => DownloadDialog(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DeezerService>();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BitMusic',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Поиск по Deezer — 90 млн треков',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
              ],
            ).animate().fadeIn(duration: 400.ms),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Трек, исполнитель, альбом…',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1C1C2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: _search,
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Expanded(child: _body(svc)),
        ],
      ),
    );
  }

  Widget _body(DeezerService svc) {
    if (svc.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF7C4DFF))),
            const SizedBox(height: 16),
            Text('Поиск…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    if (svc.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(svc.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                ),
                onPressed: _search,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
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
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
              ).createShader(r),
              child: const Icon(Icons.music_note,
                  size: 80, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('Введите запрос',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text('Поиск по базе Deezer — 90 млн треков',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: svc.searchResults.length,
      itemBuilder: (ctx, i) => TrackCard(
        track: svc.searchResults[i],
        onTap: () => _showOptions(svc.searchResults[i]),
      )
          .animate(delay: (i * 40).ms)
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}
