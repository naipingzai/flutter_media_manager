# Skill-13 媒体详情 / 全屏预览 (F5)

## 目标
定义媒体全屏查看的行为:启动 `MediaViewerActivity`(独立 Activity)、`HorizontalPager` 切换媒体、图片 / 视频分别处理、视频用 ExoPlayer。

## 设计要点

| 项 | 设计 |
|---|------|
| 入口 | 主页 / 相册 / 标签 / 搜索 长按以外的「单击」 |
| 启动 | `Intent(context, MediaViewerActivity::class.java).putExtra("mediaIds", ids).putExtra("startIndex", i)` |
| 布局 | `HorizontalPager(state = pagerState, count = ids.size)` |
| 图片页 | `ZoomableImage(uri)`:支持双指缩放 / 双击放大 / 拖动 |
| 视频页 | `ExoPlayerView(player, uri)`:支持播放 / 暂停 / 进度条 |
| 顶栏 | 隐藏式(下滑显示),显示 1/N + 媒体名 + 编辑按钮 |
| 底栏 | 隐藏式,显示日期 / 大小 / 标签 |
| 编辑按钮 | 进入「详情编辑」模式:改所属相册 / 改标签 / 删除 |
| 返回 | 系统返回 / 顶栏返回按钮 |

### 数据流

```
MediaViewerActivity.onCreate
  ↓
MediaViewerViewModel.init(mediaIds, startIndex)
  ↓
observeMediaByIds(mediaIds) : Flow<List<MediaEntity>>
  ↓
HorizontalPager 显示
  ↓
当前页 media → 详情 (顶栏 / 底栏)
```

### 视频播放

- 用 `Media3 ExoPlayer` 1.4+。
- 进入视频页 → 自动播放(`SettingsDataStore.viewerAutoPlay = true` 时)。
- 离开视频页 → `onPause` 调用 `player.pause()`。
- 切换图片 / 视频 → 重建 player(`DisposableEffect` 清理旧 player)。

## 代码检查点

- [ ] `MediaViewerActivity` 是独立 Activity(在 manifest 中 `parentActivityName=".MainActivity"`)。
- [ ] ExoPlayer 必须 `release()`,放在 `DisposableEffect.onDispose` / `onDestroy`。
- [ ] 视频自动播放受 `viewerAutoPlay` 设置项控制。
- [ ] `HorizontalPager` 的 `key` 用 `mediaId`,确保滚动位置不错乱。
- [ ] 图片缩放组件**不**自己实现,优先 `me.saket.telephoto:zoomable-image-coil` 或官方 `Modifier.pointerInput` + `detectTransformGestures`。
- [ ] 编辑模式改标签调用 `TagSelectorDialog(BIND)`。

## 验收标准

- 横向滑动切换媒体无白屏(预加载 +1/-1 页)。
- 视频自动播放 / 暂停符合设置。
- 编辑标签后返回,主页 / 相册 / 标签的标签显示同步更新。
- 旋转屏幕不丢失当前页位置(`rememberSaveable`)。

## 已知问题

- 大图(>10MB)缩放首屏可能卡顿,可加采样加载。
- ExoPlayer 1.x 与某些 HEVC 编码视频不兼容。

## 相关文件

- `app/src/main/java/com/advancemediakb/MediaViewerActivity.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/MediaViewerScreen.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/MediaViewerViewModel.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/page/ImagePage.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/page/VideoPage.kt`
- `app/src/main/AndroidManifest.xml`
