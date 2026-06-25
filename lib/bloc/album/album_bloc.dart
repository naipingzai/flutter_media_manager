// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/src/rust/api/album.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';

part 'album_event.dart';
part 'album_state.dart';

final _logger = Logger();

/// 相册管理 Bloc
class AlbumBloc extends Bloc<AlbumEvent, AlbumState> {
  AlbumBloc() : super(const AlbumState()) {
    on<AlbumLoadEvent>(_onLoadRoots);
    on<AlbumLoadRootsEvent>(_onLoadRoots);
    on<AlbumLoadChildrenEvent>(_onLoadChildren);
    on<AlbumCreateEvent>(_onCreate);
    on<AlbumDeleteEvent>(_onDelete);
    on<AlbumRenameEvent>(_onRename);
    on<AlbumAddMediaEvent>(_onAddMedia);
    on<AlbumRemoveMediaEvent>(_onRemoveMedia);
    on<AlbumSetCoverEvent>(_onSetCover);
    on<AlbumLoadBreadcrumbEvent>(_onLoadBreadcrumb);
    on<AlbumNavigateToEvent>(_onNavigateTo);
    on<AlbumNavigateUpEvent>(_onNavigateUp);
  }

  Future<void> _onLoadRoots(
    AlbumEvent event,
    Emitter<AlbumState> emit,
  ) async {
    emit(state.copyWith(status: AlbumStatus.loading));
    try {
      final albums = await RustLib.instance.api.crateApiAlbumGetRootAlbums();
      emit(state.copyWith(
        status: AlbumStatus.loaded,
        albums: albums,
      ));
    } catch (e) {
      _logger.e('加载根相册失败: $e');
      emit(state.copyWith(
        status: AlbumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadChildren(
    AlbumLoadChildrenEvent event,
    Emitter<AlbumState> emit,
  ) async {
    emit(state.copyWith(status: AlbumStatus.loading));
    try {
      final albums = await RustLib.instance.api
          .crateApiAlbumGetChildAlbums(parentId: event.parentId);
      emit(state.copyWith(
        status: AlbumStatus.loaded,
        albums: albums,
        currentParentId: event.parentId,
      ));
    } catch (e) {
      _logger.e('加载子相册失败: $e');
      emit(state.copyWith(
        status: AlbumStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreate(
    AlbumCreateEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      final albumId = await RustLib.instance.api.crateApiAlbumCreateAlbum(
        name: event.name,
        parentId: event.parentId,
      );
      _logger.i('创建相册成功: $albumId');
      // 刷新当前列表
      if (event.parentId != null) {
        add(AlbumLoadChildrenEvent(event.parentId!));
      } else {
        add(const AlbumLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('创建相册失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
    AlbumDeleteEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiAlbumDeleteAlbum(id: event.albumId);
      // 刷新当前列表
      if (state.currentParentId != null) {
        add(AlbumLoadChildrenEvent(state.currentParentId!));
      } else {
        add(const AlbumLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('删除相册失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRename(
    AlbumRenameEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiAlbumRenameAlbum(
        id: event.albumId,
        newName: event.newName,
      );
      // 刷新当前列表
      if (state.currentParentId != null) {
        add(AlbumLoadChildrenEvent(state.currentParentId!));
      } else {
        add(const AlbumLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('重命名相册失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onAddMedia(
    AlbumAddMediaEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiAlbumAddMediaToAlbum(
        mediaIds: event.mediaIds,
        albumId: event.albumId,
      );
      _logger.i('添加媒体到相册成功');
    } catch (e) {
      _logger.e('添加媒体到相册失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoveMedia(
    AlbumRemoveMediaEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiAlbumRemoveMediaFromAlbum(
        mediaIds: event.mediaIds,
        albumId: event.albumId,
      );
      _logger.i('从相册移除媒体成功');
    } catch (e) {
      _logger.e('从相册移除媒体失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSetCover(
    AlbumSetCoverEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiAlbumSetAlbumCover(
        albumId: event.albumId,
        mediaId: event.mediaId,
      );
      _logger.i('设置相册封面成功');
      // 刷新当前列表
      if (state.currentParentId != null) {
        add(AlbumLoadChildrenEvent(state.currentParentId!));
      } else {
        add(const AlbumLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('设置相册封面失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadBreadcrumb(
    AlbumLoadBreadcrumbEvent event,
    Emitter<AlbumState> emit,
  ) async {
    try {
      final breadcrumb = await RustLib.instance.api
          .crateApiAlbumGetAlbumBreadcrumb(albumId: event.albumId);
      emit(state.copyWith(breadcrumb: breadcrumb));
    } catch (e) {
      _logger.e('加载面包屑失败: $e');
    }
  }

  void _onNavigateTo(
    AlbumNavigateToEvent event,
    Emitter<AlbumState> emit,
  ) {
    emit(state.copyWith(
      currentAlbumId: event.albumId,
      currentParentId: event.albumId,
    ));
    add(AlbumLoadChildrenEvent(event.albumId));
    add(AlbumLoadBreadcrumbEvent(event.albumId));
  }

  void _onNavigateUp(
    AlbumNavigateUpEvent event,
    Emitter<AlbumState> emit,
  ) {
    // 导航到上一级，需要重新计算
    if (state.breadcrumb.length > 1) {
      final parentIndex = state.breadcrumb.length - 2;
      final parentId = state.breadcrumb[parentIndex].id;
      emit(state.copyWith(
        currentAlbumId: parentId,
        currentParentId: parentId,
      ));
      add(AlbumLoadChildrenEvent(parentId));
      add(AlbumLoadBreadcrumbEvent(parentId));
    } else {
      // 回到根
      emit(state.copyWith(
        currentAlbumId: null,
        currentParentId: null,
        breadcrumb: [],
      ));
      add(const AlbumLoadRootsEvent());
    }
  }
}
