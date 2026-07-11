export '../models.dart';

/// Media API - C++ FFI implementation
import '../models.dart';
import 'media_ffi.dart';

Future<List<MediaItem>> getAllMedia() async {
  final items = MediaFfi.instance.getAllMedia();
  return items.map(_toMediaItem).toList();
}

Future<MediaItem?> getMediaById({required String id}) async {
  final items = MediaFfi.instance.getAllMedia();
  try {
    return _toMediaItem(items.firstWhere((i) => i.id == id));
  } catch (_) {
    return null;
  }
}

Future<void> deleteMedia({required String id}) async {
  MediaFfi.instance.deleteMedia(id);
}

Future<List<MediaItem>> searchMedia({required String query}) async {
  return MediaFfi.instance.searchMedia(query).map(_toMediaItem).toList();
}

Future<List<MediaItem>> filterMediaByType(
    {required MediaType mediaType}) async {
  return MediaFfi.instance
      .filterByType(mediaType.name)
      .map(_toMediaItem)
      .toList();
}

Future<void> updateMedia({required MediaItem media}) async {
  // C++ update not yet exposed via FFI callback
}

Future<List<MediaItem>> getMediaByFilter({required FilterMode filter}) async {
  if (filter == FilterMode.all) return getAllMedia();
  return filterMediaByType(mediaType: MediaType.values[filter.index - 1]);
}

Future<void> batchDeleteMedia({required List<String> ids}) async {
  for (final id in ids) {
    MediaFfi.instance.deleteMedia(id);
  }
}

Future<AdjacentMedia?> getAdjacentMedia({required String id}) async {
  return null;
}

Future<MediaItem?> getMediaWithTags({required String id}) async {
  return getMediaById(id: id);
}

Future<int> scanDirectory(
    {required String directory, required String appDir}) async {
  return MediaFfi.instance.scanDirectory(directory, appDir);
}

Future<int> importSingleFile({required String filePath}) async {
  return MediaFfi.instance.importFile(filePath);
}

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
