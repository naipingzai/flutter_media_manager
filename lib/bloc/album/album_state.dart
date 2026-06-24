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
  final String? currentAlbumId;
  final String? currentParentId;
  final List<BreadcrumbItem> breadcrumb;
  final String? errorMessage;

  const AlbumState({
    this.status = AlbumStatus.initial,
    this.albums = const [],
    this.currentAlbumId,
    this.currentParentId,
    this.breadcrumb = const [],
    this.errorMessage,
  });

  AlbumState copyWith({
    AlbumStatus? status,
    List<AlbumWithInfo>? albums,
    String? currentAlbumId,
    String? currentParentId,
    List<BreadcrumbItem>? breadcrumb,
    String? errorMessage,
  }) {
    return AlbumState(
      status: status ?? this.status,
      albums: albums ?? this.albums,
      currentAlbumId: currentAlbumId,
      currentParentId: currentParentId,
      breadcrumb: breadcrumb ?? this.breadcrumb,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        albums,
        currentAlbumId,
        currentParentId,
        breadcrumb,
        errorMessage,
      ];
}
