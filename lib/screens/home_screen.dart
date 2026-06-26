import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/i18n/app_localizations.dart';
import 'media_screen.dart';
import 'album_screen.dart';
import 'tag_screen.dart';
import 'settings_screen.dart';

/// 主屏幕，包含底部导航栏（3个Tab：媒体/相册/标签）+ 设置按钮在顶部
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
            ],
          ),
        );
      },
    );
  }
}
