import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_media_manager/bridge/native/api/album.dart';
import 'package:flutter_media_manager/bridge/native/models.dart';
import 'package:logger/logger.dart';

part 'album_event.dart';
part 'album_state.dart';

final _albumLogger = Logger();

class AlbumBloc extends Bloc<AlbumEvent, AlbumState> {
  AlbumBloc() : super(const AlbumState()) {
    on<AlbumLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(AlbumLoadEvent event, Emitter<AlbumState> emit) async {
    emit(state.copyWith(status: AlbumStatus.loading));
    try {
      final albums = await getRootAlbums();
      emit(state.copyWith(status: AlbumStatus.loaded, albums: albums));
    } catch (e) {
      _albumLogger.e('Failed to load albums: $e');
      emit(state.copyWith(
          status: AlbumStatus.error, errorMessage: e.toString()));
    }
  }
}
