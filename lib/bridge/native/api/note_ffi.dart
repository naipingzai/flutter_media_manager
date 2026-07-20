import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _SaveNoteFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DeleteNoteFn = Int32 Function(Pointer<Utf8>);

class NoteFfi {
  static NoteFfi? _inst;
  late final DynamicLibrary _lib;
  NoteFfi._() {
    _lib = _openLib();
  }
  static NoteFfi get instance {
    _inst ??= NoteFfi._();
    return _inst!;
  }

  DynamicLibrary _openLib() {
    if (Platform.isLinux || Platform.isAndroid) {
      return DynamicLibrary.open('libflutter_media_manager.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('flutter_media_manager.dll');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libflutter_media_manager.dylib');
    }
    throw UnsupportedError('Unsupported platform');
  }

  int saveNote(String mediaId, String content) {
    final m = mediaId.toNativeUtf8();
    final c = content.toNativeUtf8();
    final r = _lib.lookupFunction<_SaveNoteFn,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_save_note')(m, c);
    calloc.free(m);
    calloc.free(c);
    return r;
  }

  int deleteNote(String id) {
    final p = id.toNativeUtf8();
    final r = _lib.lookupFunction<_DeleteNoteFn, int Function(Pointer<Utf8>)>(
        'amkb_delete_note')(p);
    calloc.free(p);
    return r;
  }
}
