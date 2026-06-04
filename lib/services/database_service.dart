import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/track.dart';

class DatabaseService extends ChangeNotifier {
  static const _boxName = 'bm_tracks';

  // ignore: prefer_typing_uninitialized_variables
  late Box _box;
  List<Track> _tracks = [];

  List<Track> get tracks => List.unmodifiable(_tracks);

  static Future<void> init() async {
    await Hive.initFlutter();
  }

  Future<void> open() async {
    _box = await Hive.openBox(_boxName);
    _reload();
  }

  void _reload() {
    _tracks = _box.values
        .whereType<Map>()
        .map((m) => Track.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => (b.downloadedAt ?? DateTime(0))
          .compareTo(a.downloadedAt ?? DateTime(0)));
    notifyListeners();
  }

  Future<void> saveTrack(Track track) async {
    await _box.put(track.id, track.toMap());
    _reload();
  }

  Future<void> deleteTrack(String id) async {
    await _box.delete(id);
    _tracks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  bool isDownloaded(String id) => _box.containsKey(id);

  Track? getTrack(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Track.fromMap(Map<String, dynamic>.from(raw as Map));
  }
}
