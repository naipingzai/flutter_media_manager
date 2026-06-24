import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../widgets/media_grid.dart';
import '../widgets/search_bar.dart';

/// 媒体浏览页面
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  @override
  void initState() {
    super.initState();
    // 页面首次加载时获取所有媒体
    context.read<MediaBloc>().add(const MediaLoadAllEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: MediaSearchBar(),
        ),
      ),
      body: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) {
          switch (state.status) {
            case MediaStatus.initial:
              return const Center(child: CircularProgressIndicator());
            case MediaStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case MediaStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      '加载失败: ${state.errorMessage ?? '未知错误'}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<MediaBloc>()
                            .add(const MediaLoadAllEvent());
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            case MediaStatus.loaded:
              if (state.filteredList.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '暂无媒体文件',
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '点击右下角按钮导入',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return MediaGrid(
                mediaList: state.filteredList,
                selectedIds: state.selectedMediaIds,
              );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showImportOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('仅图片'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(
                        const MediaFilterByTypeEvent(MediaType.image),
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('仅视频'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(
                        const MediaFilterByTypeEvent(MediaType.video),
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.audio_file),
                title: const Text('仅音频'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(
                        const MediaFilterByTypeEvent(MediaType.audio),
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('显示全部'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(
                        const MediaLoadAllEvent(),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.select_all),
                title: const Text('选择模式'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现选择模式
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('排序'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现排序
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('网格设置'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现网格设置
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('扫描文件夹'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现文件夹扫描
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('导入文件'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现文件导入
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
