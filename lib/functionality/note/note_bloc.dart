// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/note.dart';
import 'package:logger/logger.dart';
import 'package:flutter_media_knowledge_base/functionality/media/media_bloc.dart';

part 'note_event.dart';
part 'note_state.dart';

final _logger = Logger();

/// 笔记管理 Bloc（Skill-14）
class NoteBloc extends Bloc<NoteEvent, NoteState> {
  NoteBloc() : super(const NoteState()) {
    on<NoteLoadAllEvent>(_onLoadAll);
    on<NoteLoadByMediaEvent>(_onLoadByMedia);
    on<NoteSaveEvent>(_onSave);
    on<NoteDeleteEvent>(_onDelete);
  }

  Future<void> _onLoadAll(
    NoteLoadAllEvent event,
    Emitter<NoteState> emit,
  ) async {
    emit(state.copyWith(status: NoteStatus.loading));
    try {
      final notes = await getAllNotes();
      emit(state.copyWith(
        status: NoteStatus.loaded,
        notes: notes,
      ));
    } catch (e) {
      _logger.e('加载所有笔记失败: $e');
      emit(state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadByMedia(
    NoteLoadByMediaEvent event,
    Emitter<NoteState> emit,
  ) async {
    emit(state.copyWith(status: NoteStatus.loading));
    try {
      final note = await getNoteByMediaId(mediaId: event.mediaId);
      emit(state.copyWith(
        status: NoteStatus.loaded,
        notes: note == null ? <Note>[] : <Note>[note],
      ));
    } catch (e) {
      _logger.e('加载媒体笔记失败: $e');
      emit(state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSave(
    NoteSaveEvent event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await saveNote(
        mediaId: event.mediaId,
        content: event.content,
      );
      _logger.i('保存笔记成功');
      // 重新加载该媒体的笔记
      add(NoteLoadByMediaEvent(event.mediaId));
    } catch (e) {
      _logger.e('保存笔记失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
    NoteDeleteEvent event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await deleteNote(id: event.noteId);
      _logger.i('删除笔记成功: ${event.noteId}');
      final updatedNotes =
          state.notes.where((note) => note.id != event.noteId).toList();
      emit(state.copyWith(notes: updatedNotes));
    } catch (e) {
      _logger.e('删除笔记失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
