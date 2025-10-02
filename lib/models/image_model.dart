enum ImageQuality {
  large('LRG', 'Large'),
  medium('SM', 'Small'),
  thumbnail('TN', 'Thumbnail');

  const ImageQuality(this.code, this.displayName);

  final String code;
  final String displayName;
}

class ImageModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? dateTime;
  final int? size;
  final Map<ImageQuality, String> resources;
  final bool isDownloaded;
  final String? localPath;

  const ImageModel({
    required this.id,
    required this.title,
    this.description,
    this.dateTime,
    this.size,
    this.resources = const {},
    this.isDownloaded = false,
    this.localPath,
  });

  ImageModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    int? size,
    Map<ImageQuality, String>? resources,
    bool? isDownloaded,
    String? localPath,
  }) {
    return ImageModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      size: size ?? this.size,
      resources: resources ?? this.resources,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  String? get thumbnailUrl => resources[ImageQuality.thumbnail];
  String? get smallUrl => resources[ImageQuality.medium];
  String? get largeUrl => resources[ImageQuality.large];

  /// Get the best quality URL available (prefer large, then medium, then thumbnail)
  String? get bestQualityUrl {
    return largeUrl ?? smallUrl ?? thumbnailUrl;
  }

  /// Get URL for specific quality, fallback to best available
  String? getUrlForQuality(ImageQuality quality) {
    return resources[quality] ?? bestQualityUrl;
  }

  @override
  String toString() {
    return 'ImageModel(id: $id, title: $title, size: $size, isDownloaded: $isDownloaded)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageModel &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.dateTime == dateTime &&
        other.size == size &&
        _mapEquals(other.resources, resources) &&
        other.isDownloaded == isDownloaded &&
        other.localPath == localPath;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        dateTime.hashCode ^
        size.hashCode ^
        resources.hashCode ^
        isDownloaded.hashCode ^
        localPath.hashCode;
  }

  bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (final K key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) {
        return false;
      }
    }
    return true;
  }
}