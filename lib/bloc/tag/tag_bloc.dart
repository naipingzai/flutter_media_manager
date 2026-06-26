// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/src/rust/api/tag.dart';
import 'package:advance_media_kb/src/rust/api/media.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';

part 'tag_event.dart';
part 'tag_state.dart';

final _logger = Logger();

/// 标签管理 Bloc
class TagBloc extends Bloc<TagEvent, TagState> {
  TagBloc() : super(const TagState()) {
    on<TagLoadEvent>(_onLoadAll);
    on<TagLoadAllEvent>(_onLoadAll);
    on<TagLoadRootsEvent>(_onLoadRoots);
    on<TagLoadChildrenEvent>(_onLoadChildren);
    on<TagCreateEvent>(_onCreate);
    on<TagDeleteEvent>(_onDelete);
    on<TagRenameEvent>(_onRename);
    on<TagAddToMediaEvent>(_onAddToMedia);
    on<TagRemoveFromMediaEvent>(_onRemoveFromMedia);
    on<TagLoadMediaTagsEvent>(_onLoadMediaTags);
    on<TagLoadMediaByTagsAndEvent>(_onLoadMediaByTagsAnd);
    on<TagLoadMediaByTagsOrEvent>(_onLoadMediaByTagsOr);
    on<TagNavigateToEvent>(_onNavigateTo);
    on<TagNavigateUpEvent>(_onNavigateUp);
    on<TagNavigateToRootEvent>(_onNavigateToRoot);
  }

  Future<void> _onLoadAll(
    TagEvent event,
    Emitter<TagState> emit,
  ) async {
    emit(state.copyWith(status: TagStatus.loading));
    try {
      final tags = await RustLib.instance.api.crateApiTagGetAllTags();
      emit(state.copyWith(
        status: TagStatus.loaded,
        tags: tags,
      ));
    } catch (e) {
      _logger.e('加载所有标签失败: $e');
      emit(state.copyWith(
        status: TagStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadRoots(
    TagLoadRootsEvent event,
    Emitter<TagState> emit,
  ) async {
    emit(state.copyWith(status: TagStatus.loading));
    try {
      final tags = await RustLib.instance.api.crateApiTagGetRootTags();
      emit(state.copyWith(
        status: TagStatus.loaded,
        tagsWithInfo: tags,
      ));
    } catch (e) {
      _logger.e('加载根标签失败: $e');
      emit(state.copyWith(
        status: TagStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadChildren(
    TagLoadChildrenEvent event,
    Emitter<TagState> emit,
  ) async {
    emit(state.copyWith(status: TagStatus.loading));
    try {
      final tags = await RustLib.instance.api
          .crateApiTagGetChildTags(parentId: event.parentId);
      emit(state.copyWith(
        status: TagStatus.loaded,
        tagsWithInfo: tags,
        currentParentId: event.parentId,
      ));
    } catch (e) {
      _logger.e('加载子标签失败: $e');
      emit(state.copyWith(
        status: TagStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreate(
    TagCreateEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      final tagId = await RustLib.instance.api.crateApiTagCreateTag(
        name: event.name,
        color: event.color,
        parentId: event.parentId,
      );
      _logger.i('创建标签成功: $tagId');
      // 刷新当前列表
      if (event.parentId != null) {
        add(TagLoadChildrenEvent(event.parentId!));
      } else {
        add(const TagLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('创建标签失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
    TagDeleteEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiTagDeleteTag(id: event.tagId);
      // 刷新当前列表
      if (state.currentParentId != null) {
        add(TagLoadChildrenEvent(state.currentParentId!));
      } else {
        add(const TagLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('删除标签失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRename(
    TagRenameEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiTagRenameTag(
        id: event.tagId,
        newName: event.newName,
      );
      // 刷新当前列表
      if (state.currentParentId != null) {
        add(TagLoadChildrenEvent(state.currentParentId!));
      } else {
        add(const TagLoadRootsEvent());
      }
    } catch (e) {
      _logger.e('重命名标签失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onAddToMedia(
    TagAddToMediaEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiTagAddTagToMedia(
        mediaId: event.mediaId,
        tagId: event.tagId,
      );
      _logger.i('添加标签到媒体成功');
    } catch (e) {
      _logger.e('添加标签到媒体失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoveFromMedia(
    TagRemoveFromMediaEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiTagRemoveTagFromMedia(
        mediaId: event.mediaId,
        tagId: event.tagId,
      );
      _logger.i('从媒体移除标签成功');
    } catch (e) {
      _logger.e('从媒体移除标签失败: $e');
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMediaTags(
    TagLoadMediaTagsEvent event,
    Emitter<TagState> emit,
  ) async {
    try {
      final tags = await RustLib.instance.api
          .crateApiTagGetMediaTags(mediaId: event.mediaId);
      emit(state.copyWith(mediaTags: tags));
    } catch (e) {
      _logger.e('加载媒体标签失败: $e');
    }
  }

  Future<void> _onLoadMediaByTagsAnd(
    TagLoadMediaByTagsAndEvent event,
    Emitter<TagState> emit,
  ) async {
    emit(state.copyWith(status: TagStatus.loading));
    try {
      final media = await RustLib.instance.api
          .crateApiTagGetMediaByTagsAnd(tagIds: event.tagIds);
      emit(state.copyWith(
        status: TagStatus.loaded,
        filteredMedia: media,
      ));
    } catch (e) {
      _logger.e('按标签AND筛选媒体失败: $e');
      emit(state.copyWith(
        status: TagStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMediaByTagsOr(
    TagLoadMediaByTagsOrEvent event,
    Emitter<TagState> emit,
  ) async {
    emit(state.copyWith(status: TagStatus.loading));
    try {
      final media = await RustLib.instance.api
          .crateApiTagGetMediaByTagsOr(tagIds: event.tagIds);
      emit(state.copyWith(
        status: TagStatus.loaded,
        filteredMedia: media,
      ));
    } catch (e) {
      _logger.e('按标签OR筛选媒体失败: $e');
      emit(state.copyWith(
        status: TagStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onNavigateTo(
    TagNavigateToEvent event,
    Emitter<TagState> emit,
  ) {
    // 查找标签名称并构建面包屑
    final tagName = _findTagName(event.tagId);
    final newBreadcrumb = [
      ...state.breadcrumb,
      BreadcrumbItem(id: event.tagId, name: tagName),
    ];
    emit(state.copyWith(
      currentTagId: event.tagId,
      currentParentId: event.tagId,
      breadcrumb: newBreadcrumb,
    ));
    add(TagLoadChildrenEvent(event.tagId));
  }

  void _onNavigateUp(
    TagNavigateUpEvent event,
    Emitter<TagState> emit,
  ) {
    if (state.breadcrumb.length > 1) {
      final newBreadcrumb = state.breadcrumb.sublist(0, state.breadcrumb.length - 1);
      final parentId = newBreadcrumb.last.id;
      emit(state.copyWith(
        currentTagId: parentId,
        currentParentId: parentId,
        breadcrumb: newBreadcrumb,
      ));
      add(TagLoadChildrenEvent(parentId));
    } else {
      // 回到根
      emit(state.copyWith(
        clearNavigation: true,
        breadcrumb: [],
      ));
      add(const TagLoadRootsEvent());
    }
  }

  void _onNavigateToRoot(
    TagNavigateToRootEvent event,
    Emitter<TagState> emit,
  ) {
    emit(state.copyWith(
      clearNavigation: true,
      breadcrumb: [],
    ));
    add(const TagLoadRootsEvent());
  }

  /// 从当前状态中查找标签名称
  String _findTagName(String tagId) {
    for (final tagInfo in state.tagsWithInfo) {
      if (tagInfo.tag.id == tagId) return tagInfo.tag.name;
    }
    for (final tag in state.tags) {
      if (tag.id == tagId) return tag.name;
    }
    return tagId;
  }
}
