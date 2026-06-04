/// Represents a YouTube search result or a locally downloaded track.
class Track {
  final String id;
  final String videoId;
  final String title;
  final String artist;
  final int durationSeconds;
  final String thumbnailUrl;
  final String? localPath;
  final bool isDownloaded;
  final DateTime? downloadedAt;

  const Track({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.thumbnailUrl,
    this.localPath,
    this.isDownloaded = false,
    this.downloadedAt,
  });

  Track copyWith({
    String? localPath,
    bool? isDownloaded,
    DateTime? downloadedAt,
  }) {
    return Track(
      id: id,
      videoId: videoId,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'durationSeconds': durationSeconds,
        'thumbnailUrl': thumbnailUrl,
        'localPath': localPath,
        'isDownloaded': isDownloaded ? 1 : 0,
        'downloadedAt': downloadedAt?.millisecondsSinceEpoch,
      };

  factory Track.fromMap(Map<String, dynamic> map) => Track(
        id: map['id'] as String,
        videoId: map['videoId'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        durationSeconds: (map['durationSeconds'] as num).toInt(),
        thumbnailUrl: map['thumbnailUrl'] as String,
        localPath: map['localPath'] as String?,
        isDownloaded: (map['isDownloaded'] as int? ?? 0) == 1,
        downloadedAt: map['downloadedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (map['downloadedAt'] as num).toInt())
            : null,
      );

  String get durationFormatted {
    final d = Duration(seconds: durationSeconds);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
