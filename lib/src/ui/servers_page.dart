import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/server_profile.dart';
import '../state/vpn_controller.dart';
import 'import_sheet.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VpnController>();
    final profiles = controller.profiles;
    final selected = controller.selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            tooltip: 'Measure latency',
            onPressed: controller.busy || profiles.isEmpty
                ? null
                : () => controller.measureLatency(),
            icon: controller.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') {
                await controller.clearProfiles();
              } else if (value == 'refresh') {
                await _refreshSubscription(context, controller);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                enabled: controller.subscriptionUrl != null,
                child: const Text('Refresh subscription'),
              ),
              const PopupMenuItem(value: 'clear', child: Text('Remove all')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showImportSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: profiles.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return _ServerTile(
                  profile: profile,
                  selected: profile.id == selected?.id,
                );
              },
            ),
    );
  }

  Future<void> _refreshSubscription(
    BuildContext context,
    VpnController controller,
  ) async {
    final url = controller.subscriptionUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await controller.importSubscription(url);
      messenger.showSnackBar(SnackBar(content: Text('Imported $count servers')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.profile, required this.selected});

  final ServerProfile profile;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<VpnController>();
    return ListTile(
      selected: selected,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
      title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${profile.endpoint} · ${profile.transport}'),
      onTap: () => controller.select(profile.id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile.delayMs != null)
            Text(
              '${profile.delayMs} ms',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  await _rename(context, controller, profile);
                case 'copy':
                  await Clipboard.setData(ClipboardData(text: profile.outbound));
                case 'delete':
                  await controller.remove(profile);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'copy', child: Text('Copy outbound json')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    VpnController controller,
    ServerProfile profile,
  ) async {
    final field = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename server'),
        content: TextField(controller: field, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await controller.rename(profile, name);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No servers yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a vless://, vmess://, trojan:// or ss:// link, '
              'or import a subscription.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
