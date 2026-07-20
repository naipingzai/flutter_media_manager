import 'package:flutter/material.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';

/// Search screen (placeholder).
class SearchScreen extends StatelessWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.search),
      ),
      body: const Center(
        child: Text('搜索功能开发中...'),
      ),
    );
  }
}
