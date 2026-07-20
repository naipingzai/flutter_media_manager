import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// 图片查看器 - 支持双指缩放、双击缩放、旋转、拖拽平移
class ImageViewer extends StatelessWidget {
  final String filePath;

  const ImageViewer({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return PhotoView(
      imageProvider: FileImage(File(filePath)),
      minScale: PhotoViewComputedScale.contained * 0.5,
      maxScale: PhotoViewComputedScale.covered * 5,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      enableRotation: true,
      heroAttributes: const PhotoViewHeroAttributes(tag: 'image_viewer'),
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                '无法加载图片',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        );
      },
    );
  }
}
