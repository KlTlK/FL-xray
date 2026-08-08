import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/vpn_controller.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VpnController>();
    final logs = controller.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: logs.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: logs.join('\n'))),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: logs.isEmpty ? null : controller.clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No log entries yet'))
          : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: logs.length,
              itemBuilder: (context, index) => SelectableText(
                logs[logs.length - 1 - index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
