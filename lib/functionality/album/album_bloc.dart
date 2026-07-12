// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/album.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart';
import 'package:logger/logger.dart';

part 'album_event.dart';
part 'album_state.dart';

final _logger = Logger();

/// 第 14 行: 相册管理 BLoC
/// 负责处理相册的加载、创建、删除、重命名、媒体操作和导航状态
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
    on<AlbumNavigateToRootEvent>(_onNavigateToRoot);
    on<AlbumToggleMediaSelectionEvent>(_onToggleSelection);
    on<AlbumClearSelectionEvent>(_onClearSelection);
    on<AlbumRemoveSelectedMediaEvent>(_onRemoveSelectedMedia);
  }

  Future<void> _onLoadRoots(
    AlbumEvent event,
    Emitter<AlbumState> emit,
  ) async {
    emit(state.copyWith(status: AlbumStatus.loading));
    try {
      final albums = await getRootAlbums();
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
      final albums = await getChildAlbums(parentId: event.parentId);
      final media = await getMediaByAlbum(albumId: event.parentId);
      emit(state.copyWith(
        status: AlbumStatus.loaded,
        albums: albums,
        currentParentId: event.parentId,
        albumMedia: media,
        selectedMediaIds: const {},
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
      final albumId = await createAlbum(
        name: event.name,
        parentId: event.parentId,
      );
      _logger.i('创建相册成功: $albumId');
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
      await deleteAlbum(id: event.albumId);
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
      await renameAlbum(
        id: event.albumId,
        newName: event.newName,
      );
      _logger.i('重命名相册成功: ${event.newName}');
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
      await addMediaToAlbum(
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
      await removeMediaFromAlbum(
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
      await setAlbumCover(
        albumId: event.albumId,
        mediaId: event.mediaId,
      );
      _logger.i('设置相册封面成功');
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
      final breadcrumb = await getAlbumBreadcrumb(albumId: event.albumId);
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
      emit(state.copyWith(
        clearNavigation: true,
        breadcrumb: [],
      ));
      add(const AlbumLoadRootsEvent());
    }
  }

  void _onNavigateToRoot(
    AlbumNavigateToRootEvent event,
    Emitter<AlbumState> emit,
  ) {
    emit(state.copyWith(
      clearNavigation: true,
      breadcrumb: [],
      albumMedia: const [],
      selectedMediaIds: const {},
    ));
    add(const AlbumLoadRootsEvent());
  }

  void _onToggleSelection(
    AlbumToggleMediaSelectionEvent event,
    Emitter<AlbumState> emit,
  ) {
    final newSet = Set<String>.from(state.selectedMediaIds);
    if (newSet.contains(event.mediaId)) {
      newSet.remove(event.mediaId);
    } else {
      newSet.add(event.mediaId);
    }
    emit(state.copyWith(selectedMediaIds: newSet));
  }

  void _onClearSelection(
    AlbumClearSelectionEvent event,
    Emitter<AlbumState> emit,
  ) {
    emit(state.copyWith(selectedMediaIds: const {}));
  }

  Future<void> _onRemoveSelectedMedia(
    AlbumRemoveSelectedMediaEvent event,
    Emitter<AlbumState> emit,
  ) async {
    if (state.currentParentId == null || state.selectedMediaIds.isEmpty) return;
    try {
      await removeMediaFromAlbum(
        mediaIds: state.selectedMediaIds.toList(),
        albumId: state.currentParentId!,
      );
      _logger.i('从相册移除 ${state.selectedMediaIds.length} 个媒体成功');
      add(AlbumLoadChildrenEvent(state.currentParentId!));
    } catch (e) {
      _logger.e('从相册移除媒体失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
