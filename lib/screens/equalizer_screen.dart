import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/eq_preset.dart';
import '../services/eq_service.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Эквалайзер',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(eq.enabled ? 'ВКЛ' : 'ВЫКЛ',
                    style: TextStyle(
                        fontSize: 12,
                        color: eq.enabled
                            ? const Color(0xFF7C4DFF)
                            : Colors.white38)),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: eq.enabled,
                  activeColor: const Color(0xFF7C4DFF),
                  onChanged: eq.setEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // EQ curve
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _EqCurve(gains: eq.gains, enabled: eq.enabled),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          // Band sliders
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(5, (i) {
                  return Expanded(
                    child: _BandSlider(
                      label: EqPreset.bands[i],
                      gain: eq.gains[i],
                      enabled: eq.enabled,
                      onChanged: (v) => eq.setBandGain(i, v),
                    ).animate(delay: (i * 60).ms).slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 350.ms,
                        curve: Curves.easeOut),
                  );
                }),
              ),
            ),
          ),

          // Bass boost toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => eq.setBassBoost(!eq.bassBoost),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: eq.bassBoost
                      ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                      : const Color(0xFF1C1C2E),
                  border: Border.all(
                    color: eq.bassBoost
                        ? const Color(0xFF7C4DFF)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.speaker,
                        size: 20,
                        color:
                            eq.bassBoost ? const Color(0xFF7C4DFF) : Colors.white38),
                    const SizedBox(width: 8),
                    Text(
                      'Bass Boost',
                      style: TextStyle(
                        color: eq.bassBoost
                            ? const Color(0xFF7C4DFF)
                            : Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!eq.hasHardwareEq)
                      Text('  (только Android)',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

          // Presets
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('ПРЕСЕТЫ',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: EqPreset.defaults.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final active = eq.presetIndex == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  child: ChoiceChip(
                    label: Text(EqPreset.defaults[i].name),
                    selected: active,
                    selectedColor: const Color(0xFF7C4DFF),
                    backgroundColor: const Color(0xFF1C1C2E),
                    labelStyle: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontSize: 12),
                    side: BorderSide(
                        color: active
                            ? const Color(0xFF7C4DFF)
                            : Colors.white12),
                    onSelected: (_) => eq.applyPreset(i),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── EQ Curve ────────────────────────────────────────────────────────────────

class _EqCurve extends StatelessWidget {
  final List<double> gains;
  final bool enabled;
  const _EqCurve({required this.gains, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _CurvePainter(gains: gains, enabled: enabled),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<double> gains;
  final bool enabled;

  const _CurvePainter({required this.gains, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    const minDb = -12.0;
    const maxDb = 12.0;
    final midY = size.height / 2;

    // Grid line (0 dB)
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..strokeWidth = 1,
    );

    if (gains.isEmpty) return;

    // Build points
    final n = gains.length;
    final points = List.generate(n, (i) {
      final x = size.width * i / (n - 1);
      final gain = gains[i].clamp(minDb, maxDb);
      final y = midY - (gain / maxDb) * midY * 0.88;
      return Offset(x, y);
    });

    // Draw filled gradient area
    final path = Path()..moveTo(points.first.dx, midY);
    _addCurve(path, points);
    path.lineTo(points.last.dx, midY);
    path.close();

    final color = enabled ? const Color(0xFF7C4DFF) : Colors.white24;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Draw stroke
    final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
    _addCurve(strokePath, points);
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = enabled ? const Color(0xFF7C4DFF) : Colors.white24
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw band dots
    final dotPaint = Paint()
      ..color = enabled ? const Color(0xFFE040FB) : Colors.white24
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(
          p,
          4.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  void _addCurve(Path path, List<Offset> pts) {
    for (var i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      !listEquals(old.gains, gains) || old.enabled != enabled;

  bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─── Band Slider ─────────────────────────────────────────────────────────────

class _BandSlider extends StatelessWidget {
  final String label;
  final double gain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.label,
    required this.gain,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // dB value
        Text(
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
          style: TextStyle(
            color: enabled ? const Color(0xFF7C4DFF) : Colors.white24,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: enabled
                    ? const Color(0xFF7C4DFF)
                    : Colors.white24,
                inactiveTrackColor: Colors.white12,
                thumbColor: enabled ? Colors.white : Colors.white24,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackHeight: 3,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: gain.clamp(-12.0, 12.0),
                min: -12,
                max: 12,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        // Frequency label
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
