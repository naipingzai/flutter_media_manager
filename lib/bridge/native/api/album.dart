export '../models.dart';
/// Album API - C++ FFI implementation
import '../models.dart';
import 'album_ffi.dart';

Future<List<AlbumWithInfo>> getRootAlbums() async {
  final items = AlbumFfi.instance.getRootAlbums();
  return items.map((d) => AlbumWithInfo(
    album: Album(id: d.id, name: d.name, createdAt: 0),
    mediaCount: d.mediaCount,
  )).toList();
}

Future<List<AlbumWithInfo>> getChildAlbums({required String parentId}) async {
  final items = AlbumFfi.instance.getChildAlbums(parentId);
  return items.map((d) => AlbumWithInfo(
    album: Album(id: d.id, name: d.name, parentId: parentId, createdAt: 0),
    mediaCount: d.mediaCount,
  )).toList();
}

Future<String> createAlbum({required String name, String? parentId}) async {
  return AlbumFfi.instance.createAlbum(name, parentId);
}

Future<void> deleteAlbum({required String id}) async {
  AlbumFfi.instance.deleteAlbum(id);
}

Future<void> renameAlbum({required String id, required String newName}) async {
  AlbumFfi.instance.renameAlbum(id, newName);
}

Future<void> addMediaToAlbum({required List<String> mediaIds, required String albumId}) async {}
Future<void> removeMediaFromAlbum({required List<String> mediaIds, required String albumId}) async {}
Future<void> setAlbumCover({required String albumId, required String mediaId}) async {}

Future<List<BreadcrumbItem>> getAlbumBreadcrumb({required String albumId}) async {
  return [];
}

Future<List<Album>> getAlbumsByParentId({String? parentId}) async {
  return [];
}

Future<List<MediaItem>> getMediaByAlbum({required String albumId}) async {
  return [];
}
