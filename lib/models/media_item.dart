class MediaItem {
  final String id;
  final String path;
  final DateTime creationTime;
  final bool isVideo;
  final int width;
  final int height;

  MediaItem({
    required this.id,
    required this.path,
    required this.creationTime,
    required this.isVideo,
    required this.width,
    required this.height,
  });

  String get dateKey {
    final month = creationTime.month.toString().padLeft(2, '0');
    final day = creationTime.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  int get year => creationTime.year;
}

