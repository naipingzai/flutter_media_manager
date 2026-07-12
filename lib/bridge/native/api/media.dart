/// 文件坐标: lib/bridge/native/api/media.dart
/// 作用:     媒体业务 API 的 Dart 封装
/// 说明:     将 FFI 返回的 MediaItemData 转换为强类型 MediaItem，
///           提供查询、搜索、删除、导入等高层接口。
library;

export '../models.dart';

import '../models.dart';
import 'media_ffi.dart';

/// 第 6 行: 获取所有媒体项
/// 按创建时间倒序排列
Future<List<MediaItem>> getAllMedia() async {
  final items = MediaFfi.instance.getAllMedia();
  return items.map(_toMediaItem).toList();
}

/// 第 11 行: 根据 id 获取单个媒体项
Future<MediaItem?> getMediaById({required String id}) async {
  final items = MediaFfi.instance.getAllMedia();
  try {
    return _toMediaItem(items.firstWhere((i) => i.id == id));
  } catch (_) {
    return null;
  }
}

/// 第 19 行: 删除指定媒体
Future<void> deleteMedia({required String id}) async {
  MediaFfi.instance.deleteMedia(id);
}

/// 第 22 行: 按名称搜索媒体
Future<List<MediaItem>> searchMedia({required String query}) async {
  return MediaFfi.instance.searchMedia(query).map(_toMediaItem).toList();
}

/// 第 28 行: 按媒体类型过滤
Future<List<MediaItem>> filterMediaByType(
    {required MediaType mediaType}) async {
  return MediaFfi.instance
      .filterByType(mediaType.name)
      .map(_toMediaItem)
      .toList();
}

/// 第 36 行: 更新媒体元数据
/// 当前为占位实现，FFI 尚未暴露更新接口
Future<void> updateMedia({required MediaItem media}) async {
  // C++ update not yet exposed via FFI callback
}

/// 第 40 行: 按筛选模式获取媒体
Future<List<MediaItem>> getMediaByFilter({required FilterMode filter}) async {
  if (filter == FilterMode.all) return getAllMedia();
  return filterMediaByType(mediaType: MediaType.values[filter.index - 1]);
}

/// 第 45 行: 批量删除媒体
Future<void> batchDeleteMedia({required List<String> ids}) async {
  for (final id in ids) {
    MediaFfi.instance.deleteMedia(id);
  }
}

/// 第 51 行: 获取相邻媒体（上一条/下一条）
/// 当前为占位实现
Future<AdjacentMedia?> getAdjacentMedia({required String id}) async {
  return null;
}

/// 第 55 行: 获取媒体及其标签
/// 当前仅返回媒体本身
Future<MediaItem?> getMediaWithTags({required String id}) async {
  return getMediaById(id: id);
}

/// 第 59 行: 扫描目录并导入媒体
/// 返回导入的文件数量
Future<int> scanDirectory(
    {required String directory, required String appDir}) async {
  return MediaFfi.instance.scanDirectory(directory, appDir);
}

/// 第 64 行: 导入单个文件
/// 返回导入结果码
Future<int> importSingleFile({required String filePath}) async {
  return MediaFfi.instance.importFile(filePath);
}

/// 第 68 行: 将 FFI 原始数据 MediaItemData 转换为业务模型 MediaItem
MediaItem _toMediaItem(MediaItemData d) {
  MediaType mt;
  switch (d.type) {
    case 'image':
      mt = MediaType.image;
      break;
    case 'video':
      mt = MediaType.video;
      break;
    case 'audio':
      mt = MediaType.audio;
      break;
    case 'document':
      mt = MediaType.document;
      break;
    default:
      mt = MediaType.other;
  }
  return MediaItem(
    id: d.id,
    originalName: d.name,
    storageName: '',
    filePath: d.path,
    thumbnailPath: d.thumbPath,
    mediaType: mt,
    mimeType: '',
    size: d.size,
    sha256Hash: '',
    createdAt: 0,
    updatedAt: 0,
  );
}
