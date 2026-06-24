import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';

/// 相册浏览页面
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AlbumBloc>().add(const AlbumLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相册'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateAlbumDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<AlbumBloc, AlbumState>(
        builder: (context, state) {
          switch (state.status) {
            case AlbumStatus.initial:
            case AlbumStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case AlbumStatus.error:
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
                            .read<AlbumBloc>()
                            .add(const AlbumLoadRootsEvent());
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            case AlbumStatus.loaded:
              if (state.albums.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '暂无相册',
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
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: state.albums.length,
                itemBuilder: (context, index) {
                  final albumInfo = state.albums[index];
                  return _AlbumCard(
                    albumInfo: albumInfo,
                    onTap: () {
                      if (albumInfo.hasChildren) {
                        context.read<AlbumBloc>().add(
                              AlbumNavigateToEvent(albumInfo.album.id),
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

  void _showCreateAlbumDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建相册'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '相册名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final currentParentId =
                      context.read<AlbumBloc>().state.currentParentId;
                  context.read<AlbumBloc>().add(
                        AlbumCreateEvent(name, parentId: currentParentId),
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

/// 相册卡片组件
class _AlbumCard extends StatelessWidget {
  final dynamic albumInfo;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.albumInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final album = albumInfo.album;
    final mediaCount = albumInfo.mediaCount;
    final hasChildren = albumInfo.hasChildren;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: albumInfo.coverThumbnailPath != null
                    ? Image.file(
                        File(albumInfo.coverThumbnailPath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.folder,
                            size: 48,
                            color: Colors.grey,
                          );
                        },
                      )
                    : const Icon(
                        Icons.folder,
                        size: 48,
                        color: Colors.grey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$mediaCount 项',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (hasChildren) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
