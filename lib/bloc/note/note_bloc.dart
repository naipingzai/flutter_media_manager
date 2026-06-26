// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/src/rust/api/note.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';

part 'note_event.dart';
part 'note_state.dart';

final _logger = Logger();

/// 笔记管理 Bloc
class NoteBloc extends Bloc<NoteEvent, NoteState> {
  NoteBloc() : super(const NoteState()) {
    on<NoteLoadAllEvent>(_onLoadAll);
    on<NoteLoadByMediaEvent>(_onLoadByMedia);
    on<NoteLoadByIdEvent>(_onLoadById);
    on<NoteCreateEvent>(_onCreate);
    on<NoteUpdateEvent>(_onUpdate);
    on<NoteSaveEvent>(_onSave);
    on<NoteDeleteEvent>(_onDelete);
    on<NoteSearchEvent>(_onSearch);
  }

  Future<void> _onLoadAll(
    NoteLoadAllEvent event,
    Emitter<NoteState> emit,
  ) async {
    emit(state.copyWith(status: NoteStatus.loading));
    try {
      final notes = await RustLib.instance.api.crateApiNoteGetAllNotes();
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
      final notes = await RustLib.instance.api
          .crateApiNoteGetNotesByMediaId(mediaId: event.mediaId);
      emit(state.copyWith(
        status: NoteStatus.loaded,
        notes: notes,
        currentNote: notes.isNotEmpty ? notes.first : null,
      ));
    } catch (e) {
      _logger.e('加载媒体笔记失败: $e');
      emit(state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadById(
    NoteLoadByIdEvent event,
    Emitter<NoteState> emit,
  ) async {
    emit(state.copyWith(status: NoteStatus.loading));
    try {
      final note = await RustLib.instance.api
          .crateApiNoteGetNoteById(id: event.noteId);
      emit(state.copyWith(
        status: NoteStatus.loaded,
        currentNote: note,
      ));
    } catch (e) {
      _logger.e('加载笔记详情失败: $e');
      emit(state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreate(
    NoteCreateEvent event,
    Emitter<NoteState> emit,
  ) async {
    try {
      final noteId = await RustLib.instance.api.crateApiNoteCreateNote(
        mediaId: event.mediaId,
        title: event.title,
        content: event.content,
      );
      _logger.i('创建笔记成功: $noteId');
      // 刷新笔记列表
      if (event.mediaId != null) {
        add(NoteLoadByMediaEvent(event.mediaId!));
      } else {
        add(const NoteLoadAllEvent());
      }
    } catch (e) {
      _logger.e('创建笔记失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdate(
    NoteUpdateEvent event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiNoteUpdateNote(
        id: event.id,
        title: event.title,
        content: event.content,
      );
      _logger.i('更新笔记成功: ${event.id}');
      // 重新加载当前笔记
      add(NoteLoadByIdEvent(event.id));
    } catch (e) {
      _logger.e('更新笔记失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSave(
    NoteSaveEvent event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiNoteSaveNote(
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
      await RustLib.instance.api.crateApiNoteDeleteNote(id: event.noteId);
      _logger.i('删除笔记成功: ${event.noteId}');
      // 从当前列表中移除
      final updatedNotes = state.notes
          .where((note) => note.id != event.noteId)
          .toList();
      emit(state.copyWith(notes: updatedNotes));
    } catch (e) {
      _logger.e('删除笔记失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSearch(
    NoteSearchEvent event,
    Emitter<NoteState> emit,
  ) async {
    emit(state.copyWith(status: NoteStatus.loading));
    try {
      final results = await RustLib.instance.api
          .crateApiNoteSearchNotes(query: event.query);
      emit(state.copyWith(
        status: NoteStatus.loaded,
        searchResults: results,
      ));
    } catch (e) {
      _logger.e('搜索笔记失败: $e');
      emit(state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
