import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../src/rust/api/settings.dart' as rust_settings;

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final settings = state.settings;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              _SectionHeader(title: '外观'),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('主题模式'),
                subtitle: Text(_themeModeLabel(settings.themeMode)),
                onTap: () => _showThemeModeDialog(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: const Text('网格列数'),
                subtitle: Text('${settings.gridColumns} 列'),
                onTap: () => _showGridColumnsDialog(context, settings),
              ),
              const Divider(),
              _SectionHeader(title: '数据'),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: const Text('导入数据'),
                onTap: () {
                  // TODO: 实现数据导入
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('导出数据'),
                onTap: () {
                  // TODO: 实现数据导出
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  '清除所有数据',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _showClearDataConfirmDialog(context),
              ),
              const Divider(),
              _SectionHeader(title: '关于'),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('技术栈'),
                subtitle: const Text('Flutter + Rust'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _themeModeLabel(rust_settings.ThemeMode mode) {
    switch (mode) {
      case rust_settings.ThemeMode.light:
        return '浅色';
      case rust_settings.ThemeMode.dark:
        return '深色';
      default:
        return '跟随系统';
    }
  }

  void _showThemeModeDialog(BuildContext context, rust_settings.AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择主题模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('跟随系统'),
                value: rust_settings.ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppBloc>().add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('浅色'),
                value: rust_settings.ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppBloc>().add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('深色'),
                value: rust_settings.ThemeMode.dark,
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

  void _showGridColumnsDialog(BuildContext context, rust_settings.AppSettings settings) {
    final columns = [2, 3, 4, 5];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择网格列数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: columns.map((count) {
              return RadioListTile<int>(
                title: Text('$count 列'),
                value: count,
                groupValue: settings.gridColumns,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: value,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: settings.language,
                    );
                    context.read<AppBloc>().add(
                          AppSettingsUpdatedEvent(newSettings),
                        );
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

  void _showClearDataConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认清除'),
          content: const Text(
            '此操作将删除所有媒体、相册、标签和笔记数据，不可恢复。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                // TODO: 调用清除数据 API
              },
              child: const Text('清除'),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
