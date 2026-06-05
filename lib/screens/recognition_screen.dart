import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/recognition_service.dart';
import '../services/youtube_service.dart';
import '../widgets/spectrum_visualizer.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        pageBuilder: (_, a, __) => const RecognitionScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen>
    with TickerProviderStateMixin {
  // 3 pulsing rings
  late final List<AnimationController> _rings;
  // Inner circle breathe
  late final AnimationController _breathe;
  // "Found" celebrate scale
  late final AnimationController _celebrate;

  Timer? _countdown;
  int _seconds = 10;

  @override
  void initState() {
    super.initState();

    _rings = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      ),
    );

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Start rings with stagger
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 730), () {
        if (mounted) _rings[i].repeat();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    setState(() => _seconds = 10);
    final svc = context.read<RecognitionService>();
    await svc.startListening();

    if (!mounted) return;
    if (svc.state == RecognitionState.listening) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _seconds--;
          if (_seconds <= 0) t.cancel();
        });
      });
    }
  }

  Future<void> _stopEarly() async {
    _countdown?.cancel();
    context.read<RecognitionService>().recognize();
  }

  void _retry() {
    _countdown?.cancel();
    context.read<RecognitionService>().reset();
    setState(() => _seconds = 10);
    _startListening();
  }

  void _close() {
    context.read<RecognitionService>().reset();
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<RecognitionService>();
    final st = svc.state;

    if (st == RecognitionState.found) {
      _celebrate.forward(from: 0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060613),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background glow
          const _BackgroundGlow(),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────
                _TopBar(
                  onClose: _close,
                  onSettings: () => _showApiKeyDialog(context, svc),
                ),

                const Spacer(flex: 2),

                // ── Main animation ────────────────────────────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: st == RecognitionState.listening ? _stopEarly : null,
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing rings (visible only while listening)
                        if (st == RecognitionState.listening)
                          ..._rings.map((c) => _PulseRing(controller: c)),

                        // Center circle (animated breathe)
                        AnimatedBuilder(
                          animation: _breathe,
                          builder: (_, __) {
                            final scale =
                                st == RecognitionState.listening
                                    ? 1.0 +
                                        0.035 *
                                            sin(_breathe.value * pi)
                                    : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: AnimatedBuilder(
                                animation: _celebrate,
                                builder: (_, __) => Transform.scale(
                                  scale: st == RecognitionState.found
                                      ? 1.0 +
                                          0.18 *
                                              sin(_celebrate.value *
                                                  pi)
                                      : 1.0,
                                  child: _CenterCircle(
                                    state: st,
                                    seconds: _seconds,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Waveform (while listening) ─────────────────────
                AnimatedOpacity(
                  opacity: st == RecognitionState.listening ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SpectrumVisualizer(
                      isPlaying: st == RecognitionState.listening,
                      barCount: 32,
                      height: 36,
                      colorBottom: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                      colorTop: const Color(0xFFE040FB).withValues(alpha: 0.6),
                      mirrored: true,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Status text ────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _StatusText(
                    key: ValueKey(st),
                    state: st,
                    error: svc.error,
                  ),
                ),

                const SizedBox(height: 12),

                // Tap hint
                if (st == RecognitionState.listening)
                  Text(
                    'Нажмите на круг, чтобы распознать сейчас',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 12),
                  ).animate().fadeIn(delay: 1200.ms),

                // Retry button (on error / not found)
                if (st == RecognitionState.notFound ||
                    st == RecognitionState.error)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _retry,
                          icon: const Icon(Icons.mic),
                          label: const Text('Попробовать снова'),
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 0.3, end: 0).fadeIn(),

                const Spacer(flex: 3),
              ],
            ),
          ),

          // ── Result panel (slides up when found) ─────────────────
          if (st == RecognitionState.found && svc.result != null)
            _ResultPanel(
              result: svc.result!,
              onDownload: () {
                final q = svc.result!.searchQuery;
                svc.reset();
                Navigator.pop(context);
                context.read<YouTubeService>().search(q);
              },
              onClose: _close,
            ),
        ],
      ),
    );
  }

  // ── API key dialog ────────────────────────────────────────────────────────

  void _showApiKeyDialog(BuildContext context, RecognitionService svc) {
    final ctrl = TextEditingController(text: svc.apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        title: const Text('AudD API ключ',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Без ключа: ~3 распознавания/день\n'
              'Бесплатный ключ (500/мес): audd.io',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Вставьте ключ сюда',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF252540),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF)),
            onPressed: () {
              svc.saveApiKey(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _rings) c.dispose();
    _breathe.dispose();
    _celebrate.dispose();
    _countdown?.cancel();
    super.dispose();
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowPainter(),
      size: Size.infinite,
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Random stars (deterministic)
    final rand = Random(17);
    for (var i = 0; i < 90; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.2 + 0.3;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: rand.nextDouble() * 0.15 + 0.03),
      );
    }
    // Central glow
    final center = Offset(size.width / 2, size.height * 0.38);
    canvas.drawCircle(
      center,
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7C4DFF).withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.55))
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter _) => false;
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSettings;
  const _TopBar({required this.onClose, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white54, size: 30),
            onPressed: onClose,
          ),
          const Expanded(
            child: Text(
              'РАСПОЗНАВАНИЕ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.settings_outlined, color: Colors.white38, size: 22),
            onPressed: onSettings,
            tooltip: 'API ключ',
          ),
        ],
      ),
    );
  }
}

// ─── Pulse ring ──────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  const _PulseRing({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        final size = 120.0 + 160 * Curves.easeOut.transform(t);
        final opacity = (1.0 - t) * 0.55;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF7C4DFF),
                  width: 1.8 * (1.0 - t * 0.6)),
            ),
          ),
        );
      },
    );
  }
}

// ─── Center circle ────────────────────────────────────────────────────────────

class _CenterCircle extends StatelessWidget {
  final RecognitionState state;
  final int seconds;
  const _CenterCircle({required this.state, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      RecognitionState.found => const Color(0xFF00C853),
      RecognitionState.notFound => Colors.orange,
      RecognitionState.error => Colors.redAccent,
      _ => const Color(0xFF7C4DFF),
    };

    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.7),
          ],
          radius: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 6,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _icon(state, seconds),
      ),
    );
  }

  Widget _icon(RecognitionState st, int sec) {
    return switch (st) {
      RecognitionState.listening => Column(
          key: const ValueKey('mic'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_rounded, color: Colors.white, size: 46),
            const SizedBox(height: 2),
            Text('$sec',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      RecognitionState.recognizing => const Padding(
          key: ValueKey('spinner'),
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 3),
        ),
      RecognitionState.found => const Icon(
          key: ValueKey('check'),
          Icons.check_rounded, color: Colors.white, size: 60),
      RecognitionState.notFound => const Icon(
          key: ValueKey('sad'),
          Icons.music_off_rounded, color: Colors.white, size: 52),
      RecognitionState.error => const Icon(
          key: ValueKey('error'),
          Icons.wifi_off_rounded, color: Colors.white, size: 52),
      RecognitionState.idle => const Icon(
          key: ValueKey('idle'),
          Icons.mic_rounded, color: Colors.white, size: 50),
    };
  }
}

// ─── Status text ──────────────────────────────────────────────────────────────

class _StatusText extends StatelessWidget {
  final RecognitionState state;
  final String? error;
  const _StatusText({super.key, required this.state, this.error});

  @override
  Widget build(BuildContext context) {
    final (text, sub, color) = switch (state) {
      RecognitionState.listening => (
          'Слушаю…',
          'Держите устройство рядом с источником звука',
          Colors.white,
        ),
      RecognitionState.recognizing => (
          'Распознаю…',
          'Поиск в базе треков',
          Colors.white70,
        ),
      RecognitionState.found => (
          'Трек найден!',
          '',
          const Color(0xFF69F0AE),
        ),
      RecognitionState.notFound => (
          'Трек не найден',
          error ?? 'Попробуйте ещё раз',
          Colors.orange,
        ),
      RecognitionState.error => (
          'Ошибка',
          error ?? 'Что-то пошло не так',
          Colors.redAccent,
        ),
      RecognitionState.idle => (
          'Готово к распознаванию',
          '',
          Colors.white54,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ─── Result panel ─────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final RecognitionResult result;
  final VoidCallback onDownload;
  final VoidCallback onClose;

  const _ResultPanel({
    required this.result,
    required this.onDownload,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14142A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Track card
            Row(
              children: [
                _thumb(result.thumbnailUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(result.artist,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                          )),
                      if (result.album != null)
                        Text(result.album!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                            )),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Download / search
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onDownload,
              icon: const Icon(Icons.search_rounded),
              label: Text(
                'Найти «${result.title}» на YouTube',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white38,
                side: const BorderSide(color: Colors.white10),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onClose,
              child: const Text('Закрыть'),
            ),
          ],
        ),
      )
          .animate()
          .slideY(
              begin: 1,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOutCubic)
          .fadeIn(duration: 200.ms),
    );
  }

  Widget _thumb(String? url) {
    final placeholder = Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.music_note, color: Colors.white24, size: 36),
    );

    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 82,
        height: 82,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
