part of 'album_bloc.dart';

/// 相册状态枚举
enum AlbumStatus {
  initial,
  loading,
  loaded,
  error,
}

/// AlbumBloc 状态
class AlbumState extends Equatable {
  final AlbumStatus status;
  final List<AlbumWithInfo> albums;
  final List<MediaItem> albumMedia;
  final Set<String> selectedMediaIds;
  final String? currentAlbumId;
  final String? currentParentId;
  final List<BreadcrumbItem> breadcrumb;
  final String? errorMessage;

  const AlbumState({
    this.status = AlbumStatus.initial,
    this.albums = const [],
    this.albumMedia = const [],
    this.selectedMediaIds = const {},
    this.currentAlbumId,
    this.currentParentId,
    this.breadcrumb = const [],
    this.errorMessage,
  });

  bool get isRoot => currentAlbumId == null;

  AlbumState copyWith({
    AlbumStatus? status,
    List<AlbumWithInfo>? albums,
    List<MediaItem>? albumMedia,
    Set<String>? selectedMediaIds,
    String? currentAlbumId,
    String? currentParentId,
    List<BreadcrumbItem>? breadcrumb,
    String? errorMessage,
    bool clearNavigation = false,
  }) {
    return AlbumState(
      status: status ?? this.status,
      albums: albums ?? this.albums,
      albumMedia: albumMedia ?? this.albumMedia,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      currentAlbumId: clearNavigation ? null : (currentAlbumId ?? this.currentAlbumId),
      currentParentId: clearNavigation ? null : (currentParentId ?? this.currentParentId),
      breadcrumb: breadcrumb ?? this.breadcrumb,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        albums,
        albumMedia,
        selectedMediaIds,
        currentAlbumId,
        currentParentId,
        breadcrumb,
        errorMessage,
      ];
}
