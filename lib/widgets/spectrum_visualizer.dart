import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class SpectrumVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color colorBottom;
  final Color colorTop;
  final int barCount;
  final double height;
  final bool mirrored;

  const SpectrumVisualizer({
    super.key,
    required this.isPlaying,
    this.colorBottom = const Color(0xFF7C4DFF),
    this.colorTop = const Color(0xFFE040FB),
    this.barCount = 28,
    this.height = 72,
    this.mirrored = false,
  });

  @override
  State<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends State<SpectrumVisualizer> {
  final _rand = Random();
  late List<double> _pos;
  late List<double> _vel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pos = List.filled(widget.barCount, 0.04);
    _vel = List.filled(widget.barCount, 0.0);
    if (widget.isPlaying) _start();
  }

  @override
  void didUpdateWidget(SpectrumVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _start();
    } else if (!widget.isPlaying && old.isPlaying) {
      _settle();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _settle() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      bool allDone = true;
      setState(() {
        for (var i = 0; i < _pos.length; i++) {
          _vel[i] += (0.04 - _pos[i]) * 0.25;
          _vel[i] *= 0.65;
          _pos[i] = (_pos[i] + _vel[i]).clamp(0.04, 1.0);
          if (_pos[i] > 0.06) allDone = false;
        }
      });
      if (allDone) _timer?.cancel();
    });
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < widget.barCount; i++) {
        // More energy in low-mid range (perceptual loudness curve)
        final norm = i / widget.barCount;
        final weight = norm < 0.3
            ? 1.5
            : norm < 0.65
                ? 1.15
                : 0.6;
        final target = _rand.nextDouble() * weight;
        _vel[i] += (target - _pos[i]) * 0.35;
        _vel[i] *= 0.68;
        _pos[i] = (_pos[i] + _vel[i]).clamp(0.04, 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mirrored) return _buildMirrored();

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: _Bar(
                heightFraction: _pos[i],
                maxHeight: widget.height,
                colorBottom: widget.colorBottom,
                colorTop: widget.colorTop,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMirrored() {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left half (reversed)
          ...List.generate(widget.barCount ~/ 2, (i) {
            final idx = (widget.barCount ~/ 2) - 1 - i;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.2),
                child: _Bar(
                  heightFraction: _pos[idx],
                  maxHeight: widget.height,
                  colorBottom: widget.colorBottom,
                  colorTop: widget.colorTop,
                  centered: true,
                ),
              ),
            );
          }),
          // Right half
          ...List.generate(widget.barCount ~/ 2, (i) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.2),
                child: _Bar(
                  heightFraction: _pos[i],
                  maxHeight: widget.height,
                  colorBottom: widget.colorBottom,
                  colorTop: widget.colorTop,
                  centered: true,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _Bar extends StatelessWidget {
  final double heightFraction;
  final double maxHeight;
  final Color colorBottom;
  final Color colorTop;
  final bool centered;

  const _Bar({
    required this.heightFraction,
    required this.maxHeight,
    required this.colorBottom,
    required this.colorTop,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = (maxHeight * heightFraction).clamp(2.0, maxHeight);
    return Align(
      alignment: centered ? Alignment.center : Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 35),
        width: double.infinity,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [colorBottom, colorTop],
          ),
          boxShadow: [
            BoxShadow(
              color: colorBottom.withValues(alpha: 0.4 * heightFraction),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }
}
