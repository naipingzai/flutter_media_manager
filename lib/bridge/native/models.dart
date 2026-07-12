////////////////////////////////////////////////////////////////////////
// 文件坐标: lib/bridge/native/models.dart
// 作用:     Dart 侧共享数据模型
// 说明:     被 C++ FFI 桥接层和 BLoC 状态管理层共同使用的不可变数据类。
//           替代了旧 Rust 自动生成的桥接模型。
////////////////////////////////////////////////////////////////////////
library;

// --------------------------------------------------------------------
/// Shared data models used by both C++ FFI and BLoC layers.
/// These replace the auto-generated Rust bridge models.

// --------------------------------------------------------------------
// 与 C++ 侧字符串 "image", "video", "audio", "document", "other" 对应
enum MediaType { image, video, audio, document, other }

// --------------------------------------------------------------------
// 用于 UI 筛选选项：全部、类型、是否有标签/相册等
enum FilterMode {
  all,
  image,
  video,
  audio,
  document,
  other,
  withTags,
  withoutTags,
  withAlbums,
  withoutAlbums
}

// --------------------------------------------------------------------
// 与 C++ 侧 theme_mode 0/1/2 对应
enum ThemeMode { system, light, dark }

// --------------------------------------------------------------------
class MediaItem {
  final String id;
  final String originalName;
  final String storageName;
  final String filePath;
  final String thumbnailPath;
  final MediaType mediaType;
  final String mimeType;
  final int size;
  final int? width;
  final int? height;
  final int? duration;
  final String sha256Hash;
  final int createdAt;
  final int updatedAt;

  const MediaItem({
    required this.id,
    required this.originalName,
    required this.storageName,
    required this.filePath,
    required this.thumbnailPath,
    required this.mediaType,
    required this.mimeType,
    required this.size,
    this.width,
    this.height,
    this.duration,
    required this.sha256Hash,
    required this.createdAt,
    required this.updatedAt,
  });

  // ----------------------------------------------------------------
  // 创建副本并选择性替换部分字段，保持不可变性
  MediaItem copyWith(
      {String? originalName,
      String? thumbnailPath,
      int? size,
      int? width,
      int? height,
      int? updatedAt}) {
    return MediaItem(
      id: id,
      originalName: originalName ?? this.originalName,
      storageName: storageName,
      filePath: filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mediaType: mediaType,
      mimeType: mimeType,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration,
      sha256Hash: sha256Hash,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// --------------------------------------------------------------------
// 用于图片/视频查看器的上一项/下一项
class AdjacentMedia {
  final MediaItem? previous;
  final MediaItem? next;
  const AdjacentMedia({this.previous, this.next});
}

// --------------------------------------------------------------------
class Album {
  final String id;
  final String name;
  final String? parentId;
  final String? coverMediaId;
  final int sortOrder;
  final int createdAt;

  const Album({
    required this.id,
    required this.name,
    this.parentId,
    this.coverMediaId,
    this.sortOrder = 0,
    required this.createdAt,
  });
}

// --------------------------------------------------------------------
class AlbumWithInfo {
  final Album album;
  final int mediaCount;
  final String? coverPath;

  const AlbumWithInfo({
    required this.album,
    this.mediaCount = 0,
    this.coverPath,
  });
}

// --------------------------------------------------------------------
class BreadcrumbItem {
  final String id;
  final String name;
  const BreadcrumbItem({required this.id, required this.name});
}

// --------------------------------------------------------------------
class Tag {
  final String id;
  final String name;
  final String? color;
  final String? parentId;
  final int createdAt;

  const Tag({
    required this.id,
    required this.name,
    this.color,
    this.parentId,
    required this.createdAt,
  });
}

// --------------------------------------------------------------------
class TagWithInfo {
  final Tag tag;
  final int mediaCount;
  const TagWithInfo({required this.tag, this.mediaCount = 0});

  bool get hasChildren => tag.parentId == null;
}

// --------------------------------------------------------------------
class TagBreadcrumb {
  final String id;
  final String name;
  const TagBreadcrumb({required this.id, required this.name});
}

// --------------------------------------------------------------------
enum ConflictStrategy { skip, replace, rename }

// --------------------------------------------------------------------
class Note {
  final String id;
  final String mediaId;
  final String content;
  final int createdAt;
  final int updatedAt;

  const Note({
    required this.id,
    required this.mediaId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}

// --------------------------------------------------------------------
class AppSettings {
  final ThemeMode themeMode;
  final int gridColumns;
  final int albumGridColumns;
  final int thumbnailQuality;
  final String language;
  final int dynamicColor;
  final String lastScanPath;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gridColumns = 3,
    this.albumGridColumns = 2,
    this.thumbnailQuality = 85,
    this.language = 'system',
    this.dynamicColor = 1,
    this.lastScanPath = '',
  });
}

// --------------------------------------------------------------------
class StorageStats {
  final int totalMediaCount;
  final int totalSize;
  final int thumbnailCacheSize;
  final int databaseSize;

  const StorageStats({
    this.totalMediaCount = 0,
    this.totalSize = 0,
    this.thumbnailCacheSize = 0,
    this.databaseSize = 0,
  });
}

// --------------------------------------------------------------------
class SearchFilter {
  final String query;
  final MediaType? mediaType;
  final List<String>? tags;
  final int? startDate;
  final int? endDate;
  final int? minSize;
  final int? maxSize;
  final bool hasNotes;
  final String? albumId;
  final List<String>? tagIds;
  final int? tagCount;

  const SearchFilter({
    this.query = '',
    this.mediaType,
    this.tags,
    this.startDate,
    this.endDate,
    this.minSize,
    this.maxSize,
    this.hasNotes = false,
    this.albumId,
    this.tagIds,
    this.tagCount,
  });

  static const SearchFilter default_ = SearchFilter();
}
