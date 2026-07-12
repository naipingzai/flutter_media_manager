/// 文件坐标: lib/bridge/native/api/album.dart
/// 作用:     相册业务 API 的 Dart 封装
/// 说明:     将底层 FFI 返回的原始数据转换为应用层强类型模型，
///           供 BLoC/UI 调用。

export '../models.dart';

import '../models.dart';
import 'album_ffi.dart';

/// 第 6 行: 获取顶层（无父级）相册列表
/// 返回带媒体数量信息的相册列表
Future<List<AlbumWithInfo>> getRootAlbums() async {
  final items = AlbumFfi.instance.getRootAlbums();
  return items
      .map((d) => AlbumWithInfo(
            album: Album(id: d.id, name: d.name, createdAt: 0),
            mediaCount: d.mediaCount,
          ))
      .toList();
}

/// 第 16 行: 获取指定父相册下的子相册
Future<List<AlbumWithInfo>> getChildAlbums({required String parentId}) async {
  final items = AlbumFfi.instance.getChildAlbums(parentId);
  return items
      .map((d) => AlbumWithInfo(
            album:
                Album(id: d.id, name: d.name, parentId: parentId, createdAt: 0),
            mediaCount: d.mediaCount,
          ))
      .toList();
}

/// 第 27 行: 创建新相册
/// 返回新相册的 id
Future<String> createAlbum({required String name, String? parentId}) async {
  return AlbumFfi.instance.createAlbum(name, parentId);
}

/// 第 31 行: 删除相册
Future<void> deleteAlbum({required String id}) async {
  AlbumFfi.instance.deleteAlbum(id);
}

/// 第 35 行: 重命名相册
Future<void> renameAlbum({required String id, required String newName}) async {
  AlbumFfi.instance.renameAlbum(id, newName);
}

/// 第 39 行: 批量将媒体添加到相册
Future<void> addMediaToAlbum(
    {required List<String> mediaIds, required String albumId}) async {
  for (final mediaId in mediaIds) {
    AlbumFfi.instance.addMediaToAlbum(mediaId, albumId);
  }
}

/// 第 46 行: 批量从相册移除媒体
Future<void> removeMediaFromAlbum(
    {required List<String> mediaIds, required String albumId}) async {
  for (final mediaId in mediaIds) {
    AlbumFfi.instance.removeMediaFromAlbum(mediaId, albumId);
  }
}

/// 第 53 行: 设置相册封面
/// 当前为占位实现，尚未通过 FFI 暴露
Future<void> setAlbumCover(
    {required String albumId, required String mediaId}) async {
  // TODO: expose via FFI if needed
}

/// 第 58 行: 获取相册面包屑导航路径
Future<List<BreadcrumbItem>> getAlbumBreadcrumb(
    {required String albumId}) async {
  return AlbumFfi.instance
      .getAlbumBreadcrumb(albumId)
      .map((d) => BreadcrumbItem(id: d.id, name: d.name))
      .toList();
}

/// 第 66 行: 获取相册内的所有媒体
Future<List<MediaItem>> getMediaByAlbum({required String albumId}) async {
  return AlbumFfi.instance.getMediaByAlbum(albumId).map((d) {
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
  }).toList();
}
