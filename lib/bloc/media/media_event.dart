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

/// 切换选择模式
class MediaToggleSelectionModeEvent extends MediaEvent {
  const MediaToggleSelectionModeEvent();
}

/// 排序媒体
class MediaSortEvent extends MediaEvent {
  final SortField field;
  final SortOrder order;

  const MediaSortEvent(this.field, this.order);

  @override
  List<Object?> get props => [field, order];
}

/// 设置网格列数
class MediaSetGridColumnsEvent extends MediaEvent {
  final int columns;

  const MediaSetGridColumnsEvent(this.columns);

  @override
  List<Object?> get props => [columns];
}

/// 导入单个文件
class MediaImportFileEvent extends MediaEvent {
  final String filePath;

  const MediaImportFileEvent(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

/// 排序字段
enum SortField {
  date,
  name,
  size,
  type,
}

/// 排序顺序
enum SortOrder {
  ascending,
  descending,
}
