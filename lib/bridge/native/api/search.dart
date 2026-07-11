export '../models.dart';
/// Search API - C++ FFI implementation
import '../models.dart';
import 'media.dart' as media_api;

Future<List<MediaItem>> searchMediaAdvanced({required SearchFilter filter}) async {
  if (filter.query.isEmpty) return media_api.getAllMedia();
  return media_api.searchMedia(query: filter.query);
}
