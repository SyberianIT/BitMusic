import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'eq_service.dart';

class PlayerService extends ChangeNotifier {
  AudioPlayer? _player;
  AndroidEqualizer? _eq;
  AndroidLoudnessEnhancer? _loudness;
  bool _initialized = false;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _queueIndex = 0;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  String? _error;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _player?.playing ?? false;
  Duration get position => _player?.position ?? Duration.zero;
  Duration get duration => _player?.duration ?? Duration.zero;
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
    final AudioPlayer player;
    if (Platform.isAndroid) {
      _eq = AndroidEqualizer();
      _loudness = AndroidLoudnessEnhancer();
      player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [_loudness!, _eq!],
        ),
      );
      eqService.attachAndroidEffects(_eq!, _loudness!);
    } else {
      player = AudioPlayer();
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    player.playerStateStream.listen((_) => notifyListeners());
    player.positionStream.listen((_) => notifyListeners());
    player.durationStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace _) {
        _error = 'Ошибка воспроизведения: $e';
        notifyListeners();
      },
    );
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onTrackComplete();
    });

    _player = player;
    _initialized = true;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  //  Playback
  // ------------------------------------------------------------------

  Future<void> play(Track track, {List<Track>? queue, int? index}) async {
    if (!_initialized || _player == null) return;
    _error = null;
    if (_currentTrack?.id == track.id) {
      _player!.playing ? await _player!.pause() : await _player!.play();
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
      await _player!.setFilePath(track.localPath!);
      await _player!.play();
    } catch (e) {
      _error = 'Не удалось открыть файл: $e';
      notifyListeners();
    }
  }

  Future<void> pause() => _player?.pause() ?? Future.value();
  Future<void> resume() => _player?.play() ?? Future.value();
  Future<void> seek(Duration pos) => _player?.seek(pos) ?? Future.value();

  Future<void> stop() async {
    await _player?.stop();
    _currentTrack = null;
    _queue = [];
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (!_initialized || !hasNext) return;
    _queueIndex++;
    await play(_queue[_queueIndex], queue: _queue, index: _queueIndex);
  }

  Future<void> skipPrev() async {
    if (!_initialized) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (!hasPrev) return;
    _queueIndex--;
    await play(_queue[_queueIndex], queue: _queue, index: _queueIndex);
  }

  Future<void> toggleShuffle() async {
    if (!_initialized) return;
    _shuffle = !_shuffle;
    await _player?.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    if (!_initialized) return;
    _loopMode = switch (_loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player?.setLoopMode(_loopMode);
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
    _player?.dispose();
    super.dispose();
  }
}
