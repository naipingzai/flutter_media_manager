part of 'album_bloc.dart';

enum AlbumStatus { initial, loading, loaded, error }

class AlbumState extends Equatable {
  final AlbumStatus status;
  final String? errorMessage;
  final List<AlbumWithInfo> albums;

  const AlbumState({
    this.status = AlbumStatus.initial,
    this.errorMessage,
    this.albums = const [],
  });

  AlbumState copyWith({
    AlbumStatus? status,
    String? errorMessage,
    List<AlbumWithInfo>? albums,
  }) {
    return AlbumState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      albums: albums ?? this.albums,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, albums];
}
