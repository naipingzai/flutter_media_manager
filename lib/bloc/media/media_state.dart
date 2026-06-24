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
  final MediaType? currentFilter;
  final String currentQuery;
  final AdjacentMedia? adjacentMedia;
  final String? errorMessage;

  const MediaState({
    this.status = MediaStatus.initial,
    this.mediaList = const [],
    this.filteredList = const [],
    this.selectedMediaIds = const {},
    this.currentFilter,
    this.currentQuery = '',
    this.adjacentMedia,
    this.errorMessage,
  });

  MediaState copyWith({
    MediaStatus? status,
    List<MediaItem>? mediaList,
    List<MediaItem>? filteredList,
    Set<String>? selectedMediaIds,
    MediaType? currentFilter,
    String? currentQuery,
    AdjacentMedia? adjacentMedia,
    String? errorMessage,
  }) {
    return MediaState(
      status: status ?? this.status,
      mediaList: mediaList ?? this.mediaList,
      filteredList: filteredList ?? this.filteredList,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      currentFilter: currentFilter,
      currentQuery: currentQuery ?? this.currentQuery,
      adjacentMedia: adjacentMedia,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        mediaList,
        filteredList,
        selectedMediaIds,
        currentFilter,
        currentQuery,
        adjacentMedia,
        errorMessage,
      ];
}
