import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';

/// 标签浏览页面
class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(const TagLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateTagDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<TagBloc, TagState>(
        builder: (context, state) {
          switch (state.status) {
            case TagStatus.initial:
            case TagStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case TagStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: ${state.errorMessage ?? '未知错误'}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<TagBloc>()
                            .add(const TagLoadRootsEvent());
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            case TagStatus.loaded:
              if (state.tagsWithInfo.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.label_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '暂无标签',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '点击右上角按钮创建',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.tagsWithInfo.length,
                itemBuilder: (context, index) {
                  final tagInfo = state.tagsWithInfo[index];
                  return _TagListItem(
                    tagInfo: tagInfo,
                    onTap: () {
                      if (tagInfo.hasChildren != 0) {
                        context.read<TagBloc>().add(
                              TagNavigateToEvent(tagInfo.tag.id),
                            );
                      }
                    },
                  );
                },
              );
          }
        },
      ),
    );
  }

  void _showCreateTagDialog(BuildContext context) {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: '#FF6750A4');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: '标签名称',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  hintText: '颜色 (如 #FF6750A4)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final color = colorController.text.trim();
                if (name.isNotEmpty) {
                  final currentParentId =
                      context.read<TagBloc>().state.currentParentId;
                  context.read<TagBloc>().add(
                        TagCreateEvent(
                          name,
                          color: color.isNotEmpty ? color : null,
                          parentId: currentParentId,
                        ),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }
}

/// 标签列表项组件
class _TagListItem extends StatelessWidget {
  final dynamic tagInfo;
  final VoidCallback onTap;

  const _TagListItem({
    required this.tagInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tag = tagInfo.tag;
    final mediaCount = tagInfo.mediaCount;
    final hasChildren = tagInfo.hasChildren;
    final color = _parseColor(tag.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.label, color: Colors.white, size: 20),
        ),
        title: Text(tag.name),
        subtitle: Text('$mediaCount 项'),
        trailing: hasChildren != 0
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}
