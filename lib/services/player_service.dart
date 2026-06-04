import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'eq_service.dart';

class PlayerService extends ChangeNotifier {
  late final AudioPlayer _player;
  AndroidEqualizer? _eq;
  AndroidLoudnessEnhancer? _loudness;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _queueIndex = 0;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  String? _error;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;
  bool get hasPrev => _queueIndex > 0;
  bool get hasNext => _queueIndex < _queue.length - 1;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  String? get error => _error;

  PlayerService(EqService eqService) {
    _init(eqService);
  }

  Future<void> _init(EqService eqService) async {
    if (Platform.isAndroid) {
      _eq = AndroidEqualizer();
      _loudness = AndroidLoudnessEnhancer();
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [_loudness!, _eq!],
        ),
      );
      eqService.attachAndroidEffects(_eq!, _loudness!);
    } else {
      _player = AudioPlayer();
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace _) {
        _error = 'Ошибка воспроизведения: $e';
        notifyListeners();
      },
    );
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onTrackComplete();
    });
  }

  // ------------------------------------------------------------------
  //  Playback
  // ------------------------------------------------------------------

  Future<void> play(Track track, {List<Track>? queue, int? index}) async {
    _error = null;
    if (_currentTrack?.id == track.id) {
      _player.playing ? await _player.pause() : await _player.play();
      return;
    }
    if (track.localPath == null) return;

    if (queue != null) {
      _queue = queue;
      _queueIndex = index ?? queue.indexWhere((t) => t.id == track.id);
    }

    _currentTrack = track;
    notifyListeners();

    try {
      await _player.setFilePath(track.localPath!);
      await _player.play();
    } catch (e) {
      _error = 'Не удалось открыть файл: $e';
      notifyListeners();
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration pos) => _player.seek(pos);

  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
    _queue = [];
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (!hasNext) return;
    _queueIndex++;
    await play(_queue[_queueIndex], queue: _queue, index: _queueIndex);
  }

  Future<void> skipPrev() async {
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (!hasPrev) return;
    _queueIndex--;
    await play(_queue[_queueIndex], queue: _queue, index: _queueIndex);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    await _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    _loopMode = switch (_loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  void _onTrackComplete() {
    if (_loopMode == LoopMode.one) return;
    if (hasNext) {
      skipNext();
    } else if (_loopMode == LoopMode.all && _queue.isNotEmpty) {
      _queueIndex = 0;
      play(_queue[0], queue: _queue, index: 0);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
