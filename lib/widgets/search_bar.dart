import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';

/// 媒体搜索栏
class MediaSearchBar extends StatefulWidget {
  const MediaSearchBar({super.key});

  @override
  State<MediaSearchBar> createState() => _MediaSearchBarState();
}

class _MediaSearchBarState extends State<MediaSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SearchBar(
        controller: _controller,
        focusNode: _focusNode,
        hintText: '搜索媒体...',
        leading: const Icon(Icons.search),
        trailing: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                context.read<MediaBloc>().add(const MediaSearchEvent(''));
                _focusNode.unfocus();
              },
            ),
        ],
        onChanged: (value) {
          setState(() {});
          // 防抖搜索：延迟 300ms 执行
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted && _controller.text == value) {
              context.read<MediaBloc>().add(MediaSearchEvent(value));
            }
          });
        },
        onSubmitted: (value) {
          context.read<MediaBloc>().add(MediaSearchEvent(value));
        },
      ),
    );
  }
}
