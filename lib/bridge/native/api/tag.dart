export '../models.dart';

/// Tag API - C++ FFI implementation
import '../models.dart';
import 'tag_ffi.dart';

Future<List<Tag>> getAllTags() async {
  return TagFfi.instance
      .getAllTags()
      .map((d) => Tag(id: d.id, name: d.name, color: d.color, createdAt: 0))
      .toList();
}

Future<List<TagWithInfo>> getRootTags() async {
  return [];
}

Future<List<TagWithInfo>> getChildTags({required String parentId}) async {
  return [];
}

Future<String> createTag(
    {required String name, String? color, String? parentId}) async {
  return TagFfi.instance.createTag(name, color, parentId);
}

Future<void> deleteTag({required String id}) async {
  TagFfi.instance.deleteTag(id);
}

Future<void> renameTag({required String id, required String newName}) async {
  TagFfi.instance.renameTag(id, newName);
}

Future<void> updateTagColor(
    {required String id, required String color}) async {}
Future<void> updateTagParent({required String id, String? parentId}) async {}

Future<void> addTagToMedia(
    {required String mediaId, required String tagId}) async {
  TagFfi.instance.addTagToMedia(mediaId, tagId);
}

Future<void> removeTagFromMedia(
    {required String mediaId, required String tagId}) async {
  TagFfi.instance.removeTagFromMedia(mediaId, tagId);
}

Future<List<Tag>> getMediaTags({required String mediaId}) async {
  return TagFfi.instance
      .getMediaTags(mediaId)
      .map((d) => Tag(id: d.id, name: d.name, color: d.color, createdAt: 0))
      .toList();
}

Future<List<MediaItem>> getMediaByTagsAnd(
    {required List<String> tagIds}) async {
  return [];
}

Future<List<MediaItem>> getMediaByTagsOr({required List<String> tagIds}) async {
  return [];
}

Future<List<MediaItem>> getMediaByTag({required String tagId}) async {
  return getMediaByTagsAnd(tagIds: [tagId]);
}
