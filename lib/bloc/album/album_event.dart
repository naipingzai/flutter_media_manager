part of 'album_bloc.dart';

/// AlbumBloc 事件基类
abstract class AlbumEvent extends Equatable {
  const AlbumEvent();

  @override
  List<Object?> get props => [];
}

/// 加载根相册
class AlbumLoadRootsEvent extends AlbumEvent {
  const AlbumLoadRootsEvent();
}

/// 加载子相册
class AlbumLoadChildrenEvent extends AlbumEvent {
  final String parentId;

  const AlbumLoadChildrenEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// 创建相册
class AlbumCreateEvent extends AlbumEvent {
  final String name;
  final String? parentId;

  const AlbumCreateEvent(this.name, {this.parentId});

  @override
  List<Object?> get props => [name, parentId];
}

/// 删除相册
class AlbumDeleteEvent extends AlbumEvent {
  final String albumId;

  const AlbumDeleteEvent(this.albumId);

  @override
  List<Object?> get props => [albumId];
}

/// 重命名相册
class AlbumRenameEvent extends AlbumEvent {
  final String albumId;
  final String newName;

  const AlbumRenameEvent(this.albumId, this.newName);

  @override
  List<Object?> get props => [albumId, newName];
}

/// 添加媒体到相册
class AlbumAddMediaEvent extends AlbumEvent {
  final List<String> mediaIds;
  final String albumId;

  const AlbumAddMediaEvent(this.mediaIds, this.albumId);

  @override
  List<Object?> get props => [mediaIds, albumId];
}

/// 从相册移除媒体
class AlbumRemoveMediaEvent extends AlbumEvent {
  final List<String> mediaIds;
  final String albumId;

  const AlbumRemoveMediaEvent(this.mediaIds, this.albumId);

  @override
  List<Object?> get props => [mediaIds, albumId];
}

/// 设置相册封面
class AlbumSetCoverEvent extends AlbumEvent {
  final String albumId;
  final String mediaId;

  const AlbumSetCoverEvent(this.albumId, this.mediaId);

  @override
  List<Object?> get props => [albumId, mediaId];
}

/// 加载面包屑导航
class AlbumLoadBreadcrumbEvent extends AlbumEvent {
  final String albumId;

  const AlbumLoadBreadcrumbEvent(this.albumId);

  @override
  List<Object?> get props => [albumId];
}

/// 导航到指定相册
class AlbumNavigateToEvent extends AlbumEvent {
  final String albumId;

  const AlbumNavigateToEvent(this.albumId);

  @override
  List<Object?> get props => [albumId];
}

/// 导航到上一级
class AlbumNavigateUpEvent extends AlbumEvent {
  const AlbumNavigateUpEvent();
}
