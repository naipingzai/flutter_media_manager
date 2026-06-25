part of 'media_bloc.dart';

/// 媒体状态枚举
enum MediaStatus {
  initial,
  loading,
  loaded,
  error,
}

/// MediaBloc 状态
class MediaState extends Equatable {
  final MediaStatus status;
  final List<MediaItem> mediaList;
  final List<MediaItem> filteredList;
  final Set<String> selectedMediaIds;
  final bool isSelectionMode;
  final MediaType? currentFilter;
  final String currentQuery;
  final AdjacentMedia? adjacentMedia;
  final String? errorMessage;
  final SortField sortField;
  final SortOrder sortOrder;
  final int gridColumns;

  const MediaState({
    this.status = MediaStatus.initial,
    this.mediaList = const [],
    this.filteredList = const [],
    this.selectedMediaIds = const {},
    this.isSelectionMode = false,
    this.currentFilter,
    this.currentQuery = '',
    this.adjacentMedia,
    this.errorMessage,
    this.sortField = SortField.date,
    this.sortOrder = SortOrder.descending,
    this.gridColumns = 3,
  });

  MediaState copyWith({
    MediaStatus? status,
    List<MediaItem>? mediaList,
    List<MediaItem>? filteredList,
    Set<String>? selectedMediaIds,
    bool? isSelectionMode,
    MediaType? currentFilter,
    String? currentQuery,
    AdjacentMedia? adjacentMedia,
    String? errorMessage,
    SortField? sortField,
    SortOrder? sortOrder,
    int? gridColumns,
  }) {
    return MediaState(
      status: status ?? this.status,
      mediaList: mediaList ?? this.mediaList,
      filteredList: filteredList ?? this.filteredList,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      currentFilter: currentFilter,
      currentQuery: currentQuery ?? this.currentQuery,
      adjacentMedia: adjacentMedia,
      errorMessage: errorMessage,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
      gridColumns: gridColumns ?? this.gridColumns,
    );
  }

  @override
  List<Object?> get props => [
        status,
        mediaList,
        filteredList,
        selectedMediaIds,
        isSelectionMode,
        currentFilter,
        currentQuery,
        adjacentMedia,
        errorMessage,
        sortField,
        sortOrder,
        gridColumns,
      ];
}
