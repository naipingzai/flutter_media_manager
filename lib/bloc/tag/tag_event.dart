part of 'tag_bloc.dart';

/// TagBloc 事件基类
abstract class TagEvent extends Equatable {
  const TagEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有标签
class TagLoadEvent extends TagEvent {
  const TagLoadEvent();
}

class TagLoadAllEvent extends TagEvent {
  const TagLoadAllEvent();
}

/// 加载根标签
class TagLoadRootsEvent extends TagEvent {
  const TagLoadRootsEvent();
}

/// 加载子标签
class TagLoadChildrenEvent extends TagEvent {
  final String parentId;

  const TagLoadChildrenEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// 创建标签
class TagCreateEvent extends TagEvent {
  final String name;
  final String? color;
  final String? parentId;

  const TagCreateEvent(this.name, {this.color, this.parentId});

  @override
  List<Object?> get props => [name, color, parentId];
}

/// 删除标签
class TagDeleteEvent extends TagEvent {
  final String tagId;

  const TagDeleteEvent(this.tagId);

  @override
  List<Object?> get props => [tagId];
}

/// 重命名标签
class TagRenameEvent extends TagEvent {
  final String tagId;
  final String newName;

  const TagRenameEvent(this.tagId, this.newName);

  @override
  List<Object?> get props => [tagId, newName];
}

/// 添加标签到媒体
class TagAddToMediaEvent extends TagEvent {
  final String mediaId;
  final String tagId;

  const TagAddToMediaEvent(this.mediaId, this.tagId);

  @override
  List<Object?> get props => [mediaId, tagId];
}

/// 从媒体移除标签
class TagRemoveFromMediaEvent extends TagEvent {
  final String mediaId;
  final String tagId;

  const TagRemoveFromMediaEvent(this.mediaId, this.tagId);

  @override
  List<Object?> get props => [mediaId, tagId];
}

/// 加载媒体的标签
class TagLoadMediaTagsEvent extends TagEvent {
  final String mediaId;

  const TagLoadMediaTagsEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// 按标签AND筛选媒体
class TagLoadMediaByTagsAndEvent extends TagEvent {
  final List<String> tagIds;

  const TagLoadMediaByTagsAndEvent(this.tagIds);

  @override
  List<Object?> get props => [tagIds];
}

/// 按标签OR筛选媒体
class TagLoadMediaByTagsOrEvent extends TagEvent {
  final List<String> tagIds;

  const TagLoadMediaByTagsOrEvent(this.tagIds);

  @override
  List<Object?> get props => [tagIds];
}

/// 导航到指定标签
class TagNavigateToEvent extends TagEvent {
  final String tagId;

  const TagNavigateToEvent(this.tagId);

  @override
  List<Object?> get props => [tagId];
}

/// 导航到上一级
class TagNavigateUpEvent extends TagEvent {
  const TagNavigateUpEvent();
}

/// 导航到根目录
class TagNavigateToRootEvent extends TagEvent {
  const TagNavigateToRootEvent();
}
