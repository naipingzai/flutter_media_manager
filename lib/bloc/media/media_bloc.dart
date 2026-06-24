import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/src/rust/api/media.dart';
import 'package:advance_media_kb/src/rust/api/search.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';

part 'media_event.dart';
part 'media_state.dart';

final _logger = Logger();

/// 媒体管理 Bloc，管理媒体列表、搜索、筛选等
class MediaBloc extends Bloc<MediaEvent, MediaState> {
  MediaBloc() : super(const MediaState()) {
    on<MediaLoadAllEvent>(_onLoadAll);
    on<MediaSearchEvent>(_onSearch);
    on<MediaFilterByTypeEvent>(_onFilterByType);
    on<MediaAdvancedSearchEvent>(_onAdvancedSearch);
    on<MediaDeleteEvent>(_onDelete);
    on<MediaUpdateEvent>(_onUpdate);
    on<MediaRefreshEvent>(_onRefresh);
    on<MediaSelectEvent>(_onSelect);
    on<MediaClearSelectionEvent>(_onClearSelection);
    on<MediaLoadAdjacentEvent>(_onLoadAdjacent);
  }

  Future<void> _onLoadAll(
    MediaLoadAllEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final mediaList = await RustLib.instance.api.crateApiMediaGetAllMedia();
      emit(state.copyWith(
        status: MediaStatus.loaded,
        mediaList: mediaList,
        filteredList: mediaList,
      ));
    } catch (e) {
      _logger.e('加载媒体列表失败: $e');
      emit(state.copyWith(
        status: MediaStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSearch(
    MediaSearchEvent event,
    Emitter<MediaState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: state.mediaList,
        currentQuery: '',
      ));
      return;
    }
    emit(state.copyWith(status: MediaStatus.loading, currentQuery: event.query));
    try {
      final results = await RustLib.instance.api
          .crateApiMediaSearchMedia(query: event.query);
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: results,
      ));
    } catch (e) {
      _logger.e('搜索媒体失败: $e');
      emit(state.copyWith(
        status: MediaStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onFilterByType(
    MediaFilterByTypeEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final results = await RustLib.instance.api
          .crateApiMediaFilterMediaByType(mediaType: event.mediaType);
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: results,
        currentFilter: event.mediaType,
      ));
    } catch (e) {
      _logger.e('筛选媒体失败: $e');
      emit(state.copyWith(
        status: MediaStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAdvancedSearch(
    MediaAdvancedSearchEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final results = await RustLib.instance.api
          .crateApiSearchSearchMediaAdvanced(filter: event.filter);
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: results,
      ));
    } catch (e) {
      _logger.e('高级搜索失败: $e');
      emit(state.copyWith(
        status: MediaStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDelete(
    MediaDeleteEvent event,
    Emitter<MediaState> emit,
  ) async {
    try {
      await RustLib.instance.api
          .crateApiMediaDeleteMedia(id: event.mediaId);
      final updatedList = state.mediaList
          .where((m) => m.id != event.mediaId)
          .toList();
      final updatedFiltered = state.filteredList
          .where((m) => m.id != event.mediaId)
          .toList();
      emit(state.copyWith(
        mediaList: updatedList,
        filteredList: updatedFiltered,
      ));
    } catch (e) {
      _logger.e('删除媒体失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdate(
    MediaUpdateEvent event,
    Emitter<MediaState> emit,
  ) async {
    try {
      await RustLib.instance.api
          .crateApiMediaUpdateMedia(media: event.media);
      // 刷新列表
      add(const MediaRefreshEvent());
    } catch (e) {
      _logger.e('更新媒体失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRefresh(
    MediaRefreshEvent event,
    Emitter<MediaState> emit,
  ) async {
    // 重新加载当前列表
    if (state.currentQuery.isNotEmpty) {
      add(MediaSearchEvent(state.currentQuery));
    } else if (state.currentFilter != null) {
      add(MediaFilterByTypeEvent(state.currentFilter!));
    } else {
      add(const MediaLoadAllEvent());
    }
  }

  void _onSelect(
    MediaSelectEvent event,
    Emitter<MediaState> emit,
  ) {
    final selected = Set<String>.from(state.selectedMediaIds);
    if (selected.contains(event.mediaId)) {
      selected.remove(event.mediaId);
    } else {
      selected.add(event.mediaId);
    }
    emit(state.copyWith(selectedMediaIds: selected));
  }

  void _onClearSelection(
    MediaClearSelectionEvent event,
    Emitter<MediaState> emit,
  ) {
    emit(state.copyWith(selectedMediaIds: {}));
  }

  Future<void> _onLoadAdjacent(
    MediaLoadAdjacentEvent event,
    Emitter<MediaState> emit,
  ) async {
    try {
      final adjacent = await RustLib.instance.api
          .crateApiMediaGetAdjacentMedia(id: event.mediaId);
      emit(state.copyWith(adjacentMedia: adjacent));
    } catch (e) {
      _logger.e('加载相邻媒体失败: $e');
    }
  }
}
