import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vpn_settings.dart';
import '../models/vpn_status.dart';
import '../state/vpn_controller.dart';
import '../utils/formatters.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _toggle(VpnController controller) async {
    if (controller.status.isActive) {
      await controller.disconnect();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final error = await controller.connect();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } on ElevationRequired {
      if (mounted) await _askForElevation(controller);
    }
  }

  Future<void> _askForElevation(VpnController controller) async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Administrator rights required'),
        content: const Text(
          'TUN mode creates a wintun network adapter, which Windows only allows '
          'for elevated processes. Restart FL-xray as administrator?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restart as admin'),
          ),
        ],
      ),
    );
    if (restart == true) controller.relaunchElevated();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VpnController>();
    final status = controller.status;
    final theme = Theme.of(context);
    final selected = controller.selected;
    final tunMode = controller.settings.mode == TunnelMode.tun;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FL-xray'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text(tunMode ? 'TUN' : 'System proxy'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!controller.coreInstalled)
              Card(
                color: theme.colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.error_outline),
                  title: Text('xray.exe is missing from the app folder'),
                  subtitle: Text(
                    'Rebuild the app so CMake installs Xray-core into data/xray.',
                  ),
                ),
              ),
            const Spacer(),
            Center(
              child: _PowerButton(
                status: status,
                onPressed: () => _toggle(controller),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text(_label(status), style: theme.textTheme.titleMedium)),
            if (status.message != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  status.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.state == VpnState.error
                        ? theme.colorScheme.error
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(selected?.name ?? 'No server selected'),
                subtitle: Text(
                  selected == null
                      ? 'Add a server on the Servers tab'
                      : '${selected.endpoint} · ${selected.transport}',
                ),
              ),
            ),
            if (status.state == VpnState.connected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.timer_outlined,
                      label: 'Uptime',
                      value: formatDuration(status.uptime),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      icon: Icons.upload_outlined,
                      label: 'Uploaded',
                      value: formatBytes(status.uplink),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      icon: Icons.download_outlined,
                      label: 'Downloaded',
                      value: formatBytes(status.downlink),
                    ),
                  ),
                ],
              ),
              if (!tunMode) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'SOCKS 127.0.0.1:${controller.settings.socksPort} · '
                    'HTTP 127.0.0.1:${controller.settings.httpPort}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _label(VpnStatus status) {
    switch (status.state) {
      case VpnState.idle:
        return 'Disconnected';
      case VpnState.connecting:
        return 'Connecting…';
      case VpnState.connected:
        return 'Connected';
      case VpnState.stopping:
        return 'Disconnecting…';
      case VpnState.error:
        return 'Connection failed';
    }
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.status, required this.onPressed});

  final VpnStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = status.state == VpnState.connected;
    final busy = status.state == VpnState.connecting || status.state == VpnState.stopping;
    return SizedBox(
      width: 180,
      height: 180,
      child: Material(
        color: active ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? const CircularProgressIndicator()
                : Icon(
                    Icons.power_settings_new,
                    size: 72,
                    color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
