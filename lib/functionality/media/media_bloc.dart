// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/bridge/native/api/media.dart';
import 'package:advance_media_kb/bridge/native/api/enums.dart';
import 'package:advance_media_kb/bridge/native/api/search.dart';
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
    on<MediaToggleSelectAllEvent>(_onToggleSelectAll);
    on<MediaToggleSelectionModeEvent>(_onToggleSelectionMode);
    on<MediaLoadAdjacentEvent>(_onLoadAdjacent);
    on<MediaSortEvent>(_onSort);
    on<MediaSetGridColumnsEvent>(_onSetGridColumns);
    on<MediaFilterByFilterModeEvent>(_onFilterByFilterMode);
    on<MediaImportFileEvent>(_onImportFile);
  }

  Future<void> _onLoadAll(
    MediaLoadAllEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final mediaList = await getAllMedia();
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
    emit(
        state.copyWith(status: MediaStatus.loading, currentQuery: event.query));
    try {
      final results = await searchMedia(query: event.query);
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
      final results = await filterMediaByType(mediaType: event.mediaType);
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: results,
        currentFilter: event.mediaType,
        clearCurrentFilterMode: true,
        currentQuery: '',
      ));
    } catch (e) {
      _logger.e('筛选媒体失败: $e');
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: state.mediaList,
        clearCurrentFilter: true,
        clearCurrentFilterMode: true,
        currentQuery: '',
      ));
    }
  }

  Future<void> _onAdvancedSearch(
    MediaAdvancedSearchEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final results = await searchMediaAdvanced(filter: event.filter);
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
      await deleteMedia(id: event.mediaId);
      final updatedList =
          state.mediaList.where((m) => m.id != event.mediaId).toList();
      final updatedFiltered =
          state.filteredList.where((m) => m.id != event.mediaId).toList();
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
      await updateMedia(media: event.media);
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

  void _onToggleSelectAll(
    MediaToggleSelectAllEvent event,
    Emitter<MediaState> emit,
  ) {
    final allIds = state.filteredList.map((m) => m.id).toSet();
    final currentlySelected = state.selectedMediaIds;
    final allSelected =
        allIds.isNotEmpty && allIds.every(currentlySelected.contains);
    if (allSelected) {
      emit(state.copyWith(selectedMediaIds: {}));
    } else {
      emit(state.copyWith(selectedMediaIds: allIds, isSelectionMode: true));
    }
  }

  void _onToggleSelectionMode(
    MediaToggleSelectionModeEvent event,
    Emitter<MediaState> emit,
  ) {
    emit(state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedMediaIds: state.isSelectionMode ? {} : state.selectedMediaIds,
    ));
  }

  Future<void> _onLoadAdjacent(
    MediaLoadAdjacentEvent event,
    Emitter<MediaState> emit,
  ) async {
    try {
      final adjacent = await getAdjacentMedia(id: event.mediaId);
      emit(state.copyWith(adjacentMedia: adjacent));
    } catch (e) {
      _logger.e('加载相邻媒体失败: $e');
    }
  }

  void _onSort(
    MediaSortEvent event,
    Emitter<MediaState> emit,
  ) {
    final sortedList = List<MediaItem>.from(state.filteredList);

    sortedList.sort((a, b) {
      int comparison;
      switch (event.field) {
        case SortField.name:
          comparison = a.originalName.compareTo(b.originalName);
          break;
        case SortField.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortField.type:
          comparison = a.mediaType.index.compareTo(b.mediaType.index);
          break;
        case SortField.date:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return event.order == SortOrder.ascending ? comparison : -comparison;
    });

    emit(state.copyWith(
      filteredList: sortedList,
      sortField: event.field,
      sortOrder: event.order,
    ));
  }

  void _onSetGridColumns(
    MediaSetGridColumnsEvent event,
    Emitter<MediaState> emit,
  ) {
    emit(state.copyWith(gridColumns: event.columns.clamp(2, 6)));
  }

  Future<void> _onFilterByFilterMode(
    MediaFilterByFilterModeEvent event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final results = await getMediaByFilter(filter: event.filterMode);
      emit(state.copyWith(
        status: MediaStatus.loaded,
        filteredList: results,
        currentFilterMode: event.filterMode,
        clearCurrentFilter: true,
        currentQuery: '',
      ));
    } catch (e) {
      _logger.e('按模式过滤媒体失败: $e');
      emit(state.copyWith(
        status: MediaStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onImportFile(
    MediaImportFileEvent event,
    Emitter<MediaState> emit,
  ) async {
    try {
      await importSingleFile(filePath: event.filePath);
      add(const MediaRefreshEvent());
    } catch (e) {
      _logger.e('导入文件失败: $e');
      emit(state.copyWith(errorMessage: '导入失败: $e'));
    }
  }
}
