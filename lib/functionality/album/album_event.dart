part of 'album_bloc.dart';

sealed class AlbumEvent extends Equatable {
  const AlbumEvent();

  @override
  List<Object?> get props => [];
}

class AlbumLoadEvent extends AlbumEvent {
  final String? parentId;
  const AlbumLoadEvent({this.parentId});

  @override
  List<Object?> get props => [parentId];
}
