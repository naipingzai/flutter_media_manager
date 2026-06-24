part of 'media_bloc.dart';

/// MediaBloc 事件基类
abstract class MediaEvent extends Equatable {
  const MediaEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有媒体
class MediaLoadAllEvent extends MediaEvent {
  const MediaLoadAllEvent();
}

/// 搜索媒体
class MediaSearchEvent extends MediaEvent {
  final String query;

  const MediaSearchEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// 按类型筛选媒体
class MediaFilterByTypeEvent extends MediaEvent {
  final MediaType mediaType;

  const MediaFilterByTypeEvent(this.mediaType);

  @override
  List<Object?> get props => [mediaType];
}

/// 高级搜索
class MediaAdvancedSearchEvent extends MediaEvent {
  final SearchFilter filter;

  const MediaAdvancedSearchEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// 删除媒体
class MediaDeleteEvent extends MediaEvent {
  final String mediaId;

  const MediaDeleteEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// 更新媒体
class MediaUpdateEvent extends MediaEvent {
  final MediaItem media;

  const MediaUpdateEvent(this.media);

  @override
  List<Object?> get props => [media];
}

/// 刷新媒体列表
class MediaRefreshEvent extends MediaEvent {
  const MediaRefreshEvent();
}

/// 选择/取消选择媒体
class MediaSelectEvent extends MediaEvent {
  final String mediaId;

  const MediaSelectEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// 清除选择
class MediaClearSelectionEvent extends MediaEvent {
  const MediaClearSelectionEvent();
}

/// 加载相邻媒体（用于浏览导航）
class MediaLoadAdjacentEvent extends MediaEvent {
  final String mediaId;

  const MediaLoadAdjacentEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}
