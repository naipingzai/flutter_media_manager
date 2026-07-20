import 'package:flutter/material.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';

/// API test screen for debugging native bridge calls.
class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final List<String> _logs = [];

  void _addLog(String msg) {
    setState(() => _logs.add('[${DateTime.now().toIso8601String()}] $msg'));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('API Test')),
      body: _logs.isEmpty
          ? Center(child: Text(loc.noMedia))
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text(_logs[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addLog('Test OK'),
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
