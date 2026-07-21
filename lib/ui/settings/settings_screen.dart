import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/bridge/native/api/settings.dart'
    as native_api;
import 'package:flutter_media_manager/ui/media/api_test_screen.dart';
import 'package:flutter_media_manager/functionality/home/app_bloc.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  native_api.StorageStats? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await native_api.getStorageStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // 忽略加载失败
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
        ),
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final settings = state.settings;
          final loc = AppLocalizations.of(context);
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl)),
            child: ListView(
              children: [
                _SectionHeader(title: AppLocalizations.of(context).themeMode),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text(AppLocalizations.of(context).themeMode),
                  subtitle: Text(_themeModeLabel(settings.themeMode)),
                  onTap: () => _showThemeModeDialog(context, settings),
                ),
                const Divider(),
                _SectionHeader(title: AppLocalizations.of(context).display),
                ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: Text(loc.gridColumns),
                  subtitle: Text('${settings.gridColumns} ${loc.columns}'),
                  onTap: () => _showGridColumnsDialog(context, settings),
                ),
                ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: Text(loc.sort),
                  subtitle: Text(loc.sortNewestFirst),
                  onTap: () => _showSortDialog(context),
                ),
                const Divider(),
                _SectionHeader(title: loc.storageSection),
                if (_loadingStats)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(loc.storageStats),
                    subtitle: Text(_buildStatsText(context)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(loc.clearThumbnailCache),
                    onTap: () => _clearThumbnailCache(context),
                  ),
                ],
                const Divider(),
                _SectionHeader(title: loc.dataSection),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(loc.clearAllData,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  subtitle: Text(loc.clearDataDesc),
                  onTap: () => _showClearDataDialog(context),
                ),
                const Divider(),
                _SectionHeader(title: loc.devSection),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: Text(loc.apiTest),
                  subtitle: Text(loc.apiTestDesc),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ApiTestScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                _SectionHeader(title: loc.aboutSection),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(loc.versionLabel),
                  subtitle: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(loc.techStack),
                  subtitle: Text(loc.techStackValue),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _buildStatsText(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_stats == null) return loc.storageStats;
    final s = _stats!;
    return '${s.totalMediaCount} ${loc.files} · ${_formatSize(s.totalSize)}';
  }

  String _formatSize(dynamic size) {
    final bytes = size is int ? size : (size as int);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearThumbnailCache(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final deleted = await native_api.clearThumbnailCache();
      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(loc.clearedThumbnailCount
                .replaceAll('%d', deleted.toString()))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cleanFailed.replaceAll('%s', e.toString()))),
      );
    }
  }

  String _themeModeLabel(native_api.ThemeMode mode) {
    final loc = AppLocalizations.of(context);
    switch (mode) {
      case native_api.ThemeMode.light:
        return loc.themeLight;
      case native_api.ThemeMode.dark:
        return loc.themeDark;
      default:
        return loc.themeSystem;
    }
  }

  void _showThemeModeDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.themeMode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeSystem),
                value: native_api.ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppBloc>().add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeLight),
                value: native_api.ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppBloc>().add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeDark),
                value: native_api.ThemeMode.dark,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppBloc>().add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever_rounded, size: 40, color: cs.error),
        title: Text(loc.clearAllData),
        content: Text(loc.clearDataConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await native_api.deleteAllData();
                await _loadStats();
                if (!mounted) return;
                context.read<AppBloc>().add(const AppInitializeEvent());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.allDataCleared)),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('${loc.clearFailed}: ${e.toString()}')),
                );
              }
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.sort),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(loc.sortNewestFirst),
              value: 'date_desc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              title: Text(loc.sortOldestFirst),
              value: 'date_asc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              title: Text(loc.sortNameAsc),
              value: 'name_asc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              title: Text(loc.sortNameDesc),
              value: 'name_desc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              title: Text(loc.sortSizeDesc),
              value: 'size_desc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              title: Text(loc.sortSizeAsc),
              value: 'size_asc',
              groupValue: 'date_desc',
              onChanged: (_) => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showGridColumnsDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.gridColumns),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [2, 3, 4, 5, 6].map((c) {
              return RadioListTile<int>(
                title: Text('$c ${loc.columns}'),
                value: c,
                groupValue: settings.gridColumns,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = native_api.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: value,
                      albumGridColumns: value,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: settings.language,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// 设置分组标题
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
