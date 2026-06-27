import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/i18n/app_localizations.dart';
import 'media_screen.dart';
import 'album_screen.dart';
import 'tag_screen.dart';
import 'note_list_screen.dart';

/// 主屏幕，包含底部导航栏（4个Tab：媒体/相册/标签/笔记）+ 设置按钮在顶部
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final currentIndex = state.currentTabIndex;

        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: const [
              MediaScreen(),
              AlbumScreen(),
              TagScreen(),
              NoteListScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              context.read<AppBloc>().add(AppNavigationChangedEvent(index));
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.photo_library_outlined),
                selectedIcon: const Icon(Icons.photo_library),
                label: AppLocalizations.of(context).tabMedia,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder),
                label: AppLocalizations.of(context).tabAlbums,
              ),
              NavigationDestination(
                icon: const Icon(Icons.label_outlined),
                selectedIcon: const Icon(Icons.label),
                label: AppLocalizations.of(context).tabTags,
              ),
              NavigationDestination(
                icon: const Icon(Icons.note_alt_outlined),
                selectedIcon: const Icon(Icons.note_alt),
                label: AppLocalizations.of(context).tabNotes,
              ),
            ],
          ),
        );
      },
    );
  }
}
