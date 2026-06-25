import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../bloc/bloc.dart';
import '../widgets/media_grid.dart';
import '../widgets/search_bar.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/scanner.dart';

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
                crossAxisCount: state.gridColumns,
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
                  context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('排序'),
                onTap: () {
                  Navigator.pop(context);
                  _showSortOptions(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: const Text('网格设置'),
                onTap: () {
                  Navigator.pop(context);
                  _showGridOptions(context);
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
                onTap: () async {
                  Navigator.pop(context);
                  await _scanDirectory(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('导入文件'),
                onTap: () async {
                  Navigator.pop(context);
                  await _importFiles(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    if (!context.mounted) return;

    // 显示扫描进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在扫描文件夹...'),
            ],
          ),
        );
      },
    );

    try {
      final scanResult = await scanDirectory(path: result);

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭进度对话框

      // 显示结果
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('扫描完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入: ${scanResult.importedCount}'),
                Text('重复: ${scanResult.duplicateCount}'),
                Text('失败: ${scanResult.failedCount}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭进度对话框

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败: $e')),
      );
    }
  }

  Future<void> _importFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    if (!context.mounted) return;

    final bloc = context.read<MediaBloc>();
    int successCount = 0;
    int failCount = 0;

    for (final file in result.files) {
      if (file.path != null) {
        try {
          bloc.add(MediaImportFileEvent(file.path!));
          successCount++;
        } catch (e) {
          failCount++;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('导入请求已发送: $successCount 成功, $failCount 失败'),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final bloc = context.read<MediaBloc>();
    final currentField = bloc.state.sortField;
    final currentOrder = bloc.state.sortOrder;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('排序方式', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildSortTile(context, '按日期', SortField.date, currentField, currentOrder, bloc),
              _buildSortTile(context, '按名称', SortField.name, currentField, currentOrder, bloc),
              _buildSortTile(context, '按大小', SortField.size, currentField, currentOrder, bloc),
              _buildSortTile(context, '按类型', SortField.type, currentField, currentOrder, bloc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile(
    BuildContext context,
    String title,
    SortField field,
    SortField currentField,
    SortOrder currentOrder,
    MediaBloc bloc,
  ) {
    final isSelected = field == currentField;
    final icon = isSelected
        ? (currentOrder == SortOrder.ascending ? Icons.arrow_upward : Icons.arrow_downward)
        : null;

    return ListTile(
      leading: isSelected ? Icon(icon, color: Theme.of(context).primaryColor) : const SizedBox(width: 24),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        Navigator.pop(context);
        final newOrder = isSelected && currentOrder == SortOrder.descending
            ? SortOrder.ascending
            : SortOrder.descending;
        bloc.add(MediaSortEvent(field, newOrder));
      },
    );
  }

  void _showGridOptions(BuildContext context) {
    final bloc = context.read<MediaBloc>();
    final currentColumns = bloc.state.gridColumns;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('网格列数', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (int i = 2; i <= 6; i++)
                ListTile(
                  leading: Icon(Icons.grid_view, color: i == currentColumns ? Theme.of(context).primaryColor : null),
                  title: Text('$i 列'),
                  trailing: i == currentColumns ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.pop(context);
                    bloc.add(MediaSetGridColumnsEvent(i));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
