import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../functionality/home/app_bloc.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/ui/media/media_screen.dart';
import 'package:flutter_media_manager/ui/album/album_screen.dart';
import 'package:flutter_media_manager/ui/tag/tag_screen.dart';
import 'package:flutter_media_manager/ui/settings/settings_screen.dart';

/// 主屏幕，包含底部导航栏（4 个 Tab：媒体/相册/标签/设置）
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
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              context.read<AppBloc>().add(AppNavigationChangedEvent(index));
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.perm_media_outlined),
                selectedIcon: const Icon(Icons.perm_media_rounded),
                label: AppLocalizations.of(context).tabAllMedia,
              ),
              NavigationDestination(
                icon: const Icon(Icons.camera_alt_outlined),
                selectedIcon: const Icon(Icons.camera_alt_rounded),
                label: AppLocalizations.of(context).tabAlbums,
              ),
              NavigationDestination(
                icon: const Icon(Icons.label_outline_rounded),
                selectedIcon: const Icon(Icons.label_rounded),
                label: AppLocalizations.of(context).tabTags,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: AppLocalizations.of(context).settings,
              ),
            ],
          ),
        );
      },
    );
  }
}
