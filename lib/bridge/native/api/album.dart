/// Album API - C++ FFI implementation
library;

export '../models.dart';

import '../models.dart';
import 'album_ffi.dart';

Future<List<AlbumWithInfo>> getRootAlbums() async {
  return AlbumFfi.instance
      .getRootAlbums()
      .map((d) => AlbumWithInfo(
            album: Album(
              id: d.id,
              name: d.name,
              createdAt: 0,
            ),
            mediaCount: d.mediaCount,
          ))
      .toList();
}

Future<List<AlbumWithInfo>> getChildAlbums({required String parentId}) async {
  return AlbumFfi.instance
      .getChildAlbums(parentId)
      .map((d) => AlbumWithInfo(
            album: Album(
              id: d.id,
              name: d.name,
              parentId: parentId,
              createdAt: 0,
            ),
            mediaCount: d.mediaCount,
          ))
      .toList();
}

Future<String> createAlbum({required String name, String? parentId}) async {
  return AlbumFfi.instance.createAlbum(name, parentId);
}

Future<int> deleteAlbum({required String id}) async {
  return AlbumFfi.instance.deleteAlbum(id);
}

Future<int> renameAlbum({required String id, required String name}) async {
  return AlbumFfi.instance.renameAlbum(id, name);
}

Future<void> addMediaToAlbum({
  required List<String> mediaIds,
  required String albumId,
}) async {
  for (final mediaId in mediaIds) {
    AlbumFfi.instance.addMediaToAlbum(mediaId, albumId);
  }
}

Future<void> removeMediaFromAlbum({
  required String mediaId,
  required String albumId,
}) async {
  AlbumFfi.instance.removeMediaFromAlbum(mediaId, albumId);
}

Future<List<MediaItem>> getMediaByAlbum({required String albumId}) async {
  final data = AlbumFfi.instance.getMediaByAlbum(albumId);
  return data.map((d) {
    final ext = d.name.split('.').last.toLowerCase();
    MediaType mt;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif']
        .contains(ext)) {
      mt = MediaType.image;
    } else if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'].contains(ext)) {
      mt = MediaType.video;
    } else if (['mp3', 'wav', 'flac', 'aac', 'ogg'].contains(ext)) {
      mt = MediaType.audio;
    } else if (['pdf', 'doc', 'docx', 'txt', 'md', 'epub'].contains(ext)) {
      mt = MediaType.document;
    } else {
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

Future<List<BreadcrumbItem>> getAlbumBreadcrumb(
    {required String albumId}) async {
  return AlbumFfi.instance
      .getAlbumBreadcrumb(albumId)
      .map((d) => BreadcrumbItem(id: d.id, name: d.name))
      .toList();
}
