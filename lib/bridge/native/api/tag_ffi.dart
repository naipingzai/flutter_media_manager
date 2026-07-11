import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _TagCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _GetAllTagsFn = Int32 Function(Pointer<NativeFunction<_TagCb>>);
typedef _CreateTagFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _DeleteTagFn = Int32 Function(Pointer<Utf8>);
typedef _RenameTagFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _AddTagToMediaFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RemoveTagFromMediaFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _GetMediaTagsFn = Int32 Function(Pointer<Utf8>, Pointer<NativeFunction<_TagCb>>);

class TagData {
  final String id;
  final String name;
  final String? color;
  TagData(this.id, this.name, this.color);
}

class TagFfi {
  static TagFfi? _inst;
  late final DynamicLibrary _lib;
  TagFfi._() { _lib = _openLib(); }
  static TagFfi get instance { _inst ??= TagFfi._(); return _inst!; }

  DynamicLibrary _openLib() {
    if (Platform.isLinux || Platform.isAndroid) return DynamicLibrary.open('libadvance_media_kb.so');
    if (Platform.isWindows) return DynamicLibrary.open('advance_media_kb.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libadvance_media_kb.dylib');
    throw UnsupportedError('Unsupported platform');
  }

  static List<TagData>? _currentTags;
  static void _collectTag(Pointer<Utf8> id, Pointer<Utf8> name, Pointer<Utf8> color) {
    final c = color == nullptr ? null : color.toDartString();
    _currentTags?.add(TagData(id.toDartString(), name.toDartString(), c));
  }

  List<TagData> getAllTags() {
    _currentTags = [];
    final cb = Pointer.fromFunction<_TagCb>(_collectTag);
    _lib.lookupFunction<_GetAllTagsFn, int Function(Pointer<NativeFunction<_TagCb>>)>('amkb_get_all_tags')(cb);
    final r = _currentTags!; _currentTags = null; return r;
  }

  String createTag(String name, String? color, String? parentId) {
    final n = name.toNativeUtf8();
    final c = color?.toNativeUtf8() ?? nullptr;
    final p = parentId?.toNativeUtf8() ?? nullptr;
    final result = _lib.lookupFunction<_CreateTagFn, Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>('amkb_create_tag')(n, c, p);
    calloc.free(n);
    if (color != null) calloc.free(c);
    if (parentId != null) calloc.free(p);
    return result.toDartString();
  }

  int deleteTag(String id) {
    final p = id.toNativeUtf8();
    final r = _lib.lookupFunction<_DeleteTagFn, int Function(Pointer<Utf8>)>('amkb_delete_tag')(p);
    calloc.free(p); return r;
  }

  int renameTag(String id, String name) {
    final i = id.toNativeUtf8();
    final n = name.toNativeUtf8();
    final r = _lib.lookupFunction<_RenameTagFn, int Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_rename_tag')(i, n);
    calloc.free(i); calloc.free(n); return r;
  }

  int addTagToMedia(String mediaId, String tagId) {
    final m = mediaId.toNativeUtf8();
    final t = tagId.toNativeUtf8();
    final r = _lib.lookupFunction<_AddTagToMediaFn, int Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_add_tag_to_media')(m, t);
    calloc.free(m); calloc.free(t); return r;
  }

  int removeTagFromMedia(String mediaId, String tagId) {
    final m = mediaId.toNativeUtf8();
    final t = tagId.toNativeUtf8();
    final r = _lib.lookupFunction<_RemoveTagFromMediaFn, int Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_remove_tag_from_media')(m, t);
    calloc.free(m); calloc.free(t); return r;
  }

  List<TagData> getMediaTags(String mediaId) {
    _currentTags = [];
    final cb = Pointer.fromFunction<_TagCb>(_collectTag);
    final m = mediaId.toNativeUtf8();
    _lib.lookupFunction<_GetMediaTagsFn, int Function(Pointer<Utf8>, Pointer<NativeFunction<_TagCb>>)>('amkb_get_media_tags')(m, cb);
    calloc.free(m);
    final r = _currentTags!; _currentTags = null; return r;
  }
}
