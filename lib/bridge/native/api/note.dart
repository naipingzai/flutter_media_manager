export '../models.dart';
/// Note API - C++ FFI implementation
import '../models.dart';
import 'note_ffi.dart';

Future<List<Note>> getAllNotes() async { return []; }
Future<Note?> getNoteByMediaId({required String mediaId}) async { return null; }

Future<void> saveNote({required String mediaId, required String content}) async {
  NoteFfi.instance.saveNote(mediaId, content);
}

Future<void> deleteNote({required String id}) async {
  NoteFfi.instance.deleteNote(id);
}
