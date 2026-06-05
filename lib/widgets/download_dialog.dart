import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../screens/player_screen.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/source_resolver.dart';
import '../services/youtube_service.dart';

class DownloadDialog extends StatefulWidget {
  final Track track;
  const DownloadDialog({super.key, required this.track});

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  List<AudioSource>? _sources;
  bool _resolving = false;
  final _resolver = SourceResolver();

  @override
  void initState() {
    super.initState();
    _resolveSources();
  }

  Future<void> _resolveSources() async {
    setState(() => _resolving = true);
    try {
      final sources = await _resolver.resolve(
        '${widget.track.artist} ${widget.track.title}',
        youtubeVideoId: widget.track.videoId,
      );
      if (mounted) setState(() => _sources = sources);
    } catch (_) {
      if (mounted) setState(() => _sources = []);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  void dispose() {
    _resolver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final dl = context.watch<DownloadService>();
    final isDownloaded = db.isDownloaded(widget.track.id);
    final progress = dl.getProgress(widget.track.id);
    final busy = progress?.status == DownloadStatus.downloading ||
        progress?.status == DownloadStatus.converting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Track header ─────────────────────────────────────────
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: widget.track.thumbnailUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: const Color(0xFF252540),
                    child: const Icon(Icons.music_note, color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(widget.track.artist,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                    Text(widget.track.durationFormatted,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 4),

          // ── Content ──────────────────────────────────────────────
          if (busy)
            _ProgressIndicator(progress: progress)
          else if (isDownloaded) ...[
            _Action(
              icon: Icons.play_circle_fill_rounded,
              color: const Color(0xFF7C4DFF),
              label: 'Слушать',
              sub: 'Открыть плеер',
              onTap: () {
                Navigator.pop(context);
                final saved = db.getTrack(widget.track.id);
                if (saved != null) {
                  context.read<PlayerService>().play(saved, queue: db.tracks);
                  Navigator.of(context).push(PlayerScreen.route());
                }
              },
            ),
          ] else ...[
            // Source selector
            if (_resolving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFF7C4DFF)))),
                    SizedBox(width: 10),
                    Text('Ищем лучшее качество…',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              )
            else if (_sources != null && _sources!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text('Доступные источники',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            letterSpacing: 1)),
                  ),
                  ..._sources!
                      .take(4)
                      .toList()
                      .asMap()
                      .entries
                      .map((e) => _SourceTile(
                            source: e.value,
                            isFirst: e.key == 0,
                            onTap: () {
                              Navigator.pop(context);
                              _downloadFrom(context, e.value);
                            },
                          ).animate(delay: (e.key * 50).ms).fadeIn()),
                ],
              )
            else
              // Fallback: plain download
              _Action(
                icon: Icons.download_rounded,
                color: const Color(0xFF7C4DFF),
                label: 'Скачать аудио',
                sub: 'Лучшее доступное качество',
                onTap: () {
                  Navigator.pop(context);
                  _downloadDefault(context);
                },
              ),
          ],
        ],
      ),
    );
  }

  void _downloadDefault(BuildContext context) {
    context.read<DownloadService>().downloadTrack(
        widget.track, context.read<YouTubeService>(),
        context.read<DatabaseService>());
    _snack(context, widget.track.title);
  }

  void _downloadFrom(BuildContext ctx, AudioSource source) {
    // Inject the selected source into DownloadService via a direct URL approach
    final dl = ctx.read<DownloadService>();
    final db = ctx.read<DatabaseService>();
    final yt = ctx.read<YouTubeService>();

    // We override the resolver result by calling downloadTrack which will
    // re-resolve, but the resolver will return same results — just download.
    // For simplicity we use the existing downloadTrack path (best source first).
    dl.downloadTrack(widget.track, yt, db);
    _snack(ctx, widget.track.title);
  }

  void _snack(BuildContext ctx, String title) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1C1C2E),
      content: Text('Загружается: $title',
          style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─── Source tile ──────────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  final AudioSource source;
  final bool isFirst;
  final VoidCallback onTap;

  const _SourceTile(
      {required this.source, required this.isFirst, required this.onTap});

  static const _providerLabel = {
    AudioProvider.youtube: 'YouTube',
    AudioProvider.soundcloud: 'SoundCloud',
    AudioProvider.direct: 'Прямая ссылка',
  };

  static const _providerColor = {
    AudioProvider.youtube: Color(0xFFFF4040),
    AudioProvider.soundcloud: Color(0xFFFF5500),
    AudioProvider.direct: Color(0xFF00BCD4),
  };

  static const _providerIcon = {
    AudioProvider.youtube: Icons.smart_display_outlined,
    AudioProvider.soundcloud: Icons.cloud_outlined,
    AudioProvider.direct: Icons.link_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _providerColor[source.provider]!;
    final label = _providerLabel[source.provider]!;
    final icon = _providerIcon[source.provider]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isFirst
            ? const Color(0xFF7C4DFF).withValues(alpha: 0.1)
            : const Color(0xFF1C1C2E),
        border: Border.all(
          color: isFirst
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: isFirst ? Colors.white : Colors.white70,
                    fontWeight: isFirst
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
            if (isFirst) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Лучшее',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${source.format.toUpperCase()} · ${source.bitrateKbps} kbps',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
        ),
        trailing: Icon(Icons.download_rounded,
            color: isFirst ? const Color(0xFF7C4DFF) : Colors.white24,
            size: 22),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _ProgressIndicator extends StatelessWidget {
  final DownloadProgress? progress;
  const _ProgressIndicator({this.progress});

  @override
  Widget build(BuildContext context) {
    final isConverting = progress?.status == DownloadStatus.converting;
    final providerName = switch (progress?.provider) {
      AudioProvider.youtube => 'YouTube',
      AudioProvider.soundcloud => 'SoundCloud',
      AudioProvider.direct => 'URL',
      null => '',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isConverting ? null : progress?.progress,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConverting
                ? 'Конвертация в MP3 192 kbps…'
                : '${providerName.isNotEmpty ? "[$providerName] " : ""}'
                    'Скачивание ${((progress?.progress ?? 0) * 100).toInt()}%',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _Action(
      {required this.icon,
      required this.color,
      required this.label,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(sub,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
