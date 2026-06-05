import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../models/eq_preset.dart';

class EqService extends ChangeNotifier {
  static const _boxName = 'bm_eq';

  AndroidEqualizer? _androidEq;
  AndroidLoudnessEnhancer? _loudnessEnhancer;

  List<double> _gains = List.from(EqPreset.defaults[0].gains);
  int _presetIndex = 0;
  bool _enabled = true;
  bool _bassBoost = false;

  List<double> get gains => List.unmodifiable(_gains);
  int get presetIndex => _presetIndex;
  bool get enabled => _enabled;
  bool get bassBoost => _bassBoost;

  bool get hasHardwareEq => _androidEq != null;

  /// Called by PlayerService after creating the AudioPlayer pipeline.
  void attachAndroidEffects(
      AndroidEqualizer eq, AndroidLoudnessEnhancer loudness) {
    _androidEq = eq;
    _loudnessEnhancer = loudness;
    _applyAll();
  }

  Future<void> loadSaved() async {
    final box = await Hive.openBox(_boxName);
    _presetIndex = (box.get('preset', defaultValue: 0) as num).toInt();
    _enabled = box.get('enabled', defaultValue: true) as bool;
    _bassBoost = box.get('bassBoost', defaultValue: false) as bool;
    final saved = box.get('gains');
    if (saved != null) {
      _gains = (saved as List).map((v) => (v as num).toDouble()).toList();
    } else {
      _gains = List.from(EqPreset.defaults[_presetIndex].gains);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final box = await Hive.openBox(_boxName);
    await box.put('preset', _presetIndex);
    await box.put('enabled', _enabled);
    await box.put('bassBoost', _bassBoost);
    await box.put('gains', _gains);
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    _applyAll();
    notifyListeners();
    await _save();
  }

  Future<void> setBassBoost(bool v) async {
    _bassBoost = v;
    await _applyLoudness();
    notifyListeners();
    await _save();
  }

  Future<void> applyPreset(int index) async {
    _presetIndex = index;
    _gains = List.from(EqPreset.defaults[index].gains);
    _applyAll();
    notifyListeners();
    await _save();
  }

  Future<void> setBandGain(int band, double gain) async {
    _gains[band] = gain.clamp(-12.0, 12.0);
    _presetIndex = EqPreset.defaults.length - 1; // Custom
    _applyAll();
    notifyListeners();
    await _save();
  }

  void _applyAll() {
    _applyEq();
    _applyLoudness();
  }

  Future<void> _applyEq() async {
    if (_androidEq == null) return;
    try {
      await _androidEq!.setEnabled(_enabled);
      final params = await _androidEq!.parameters;
      for (var i = 0; i < params.bands.length && i < _gains.length; i++) {
        await params.bands[i].setGain(_enabled ? _gains[i] : 0.0);
      }
    } catch (_) {}
  }

  Future<void> _applyLoudness() async {
    if (_loudnessEnhancer == null) return;
    try {
      await _loudnessEnhancer!.setEnabled(_bassBoost);
      if (_bassBoost) await _loudnessEnhancer!.setTargetGain(0.8);
    } catch (_) {}
  }

  // Returns Android equalizer bands metadata (for dynamic UI).
  // Returns null on non-Android.
  Future<AndroidEqualizerParameters?> get androidParams async {
    if (!Platform.isAndroid || _androidEq == null) return null;
    try {
      return await _androidEq!.parameters;
    } catch (_) {
      return null;
    }
  }
}
