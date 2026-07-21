import 'package:flutter/material.dart';
import 'widgets/advanced_search_dialog.dart';

/// 搜索页面：直接弹出高级搜索对话框
///
/// 历史原因：此页面曾是占位符，导致点击搜索按钮后看到"开发中"。
/// 实际已有完整的 AdvancedSearchDialog 实现，这里直接展示该对话框。
class SearchScreen extends StatelessWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return const AdvancedSearchDialog();
  }
}
