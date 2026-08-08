import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vpn_settings.dart';
import '../state/vpn_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VpnController>();
    final settings = controller.settings;
    final locked = controller.status.isActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (locked)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Disconnect to change the tunnel configuration'),
            ),
          const _SectionHeader('Tunnel mode'),
          RadioGroup<TunnelMode>(
            groupValue: settings.mode,
            onChanged: locked
                ? (_) {}
                : (value) => controller.updateSettings(settings.copyWith(mode: value)),
            child: Column(
              children: [
                RadioListTile<TunnelMode>(
                  value: TunnelMode.tun,
                  enabled: !locked,
                  title: const Text('TUN (full device tunnel)'),
                  subtitle: Text(
                    controller.isElevated
                        ? 'Creates the wintun adapter and routes everything through Xray'
                        : 'Creates the wintun adapter — requires running as administrator',
                  ),
                ),
                RadioListTile<TunnelMode>(
                  value: TunnelMode.systemProxy,
                  enabled: !locked,
                  title: const Text('System proxy'),
                  subtitle:
                      const Text('Local SOCKS/HTTP inbounds, no elevation needed'),
                ),
              ],
            ),
          ),
          if (settings.mode == TunnelMode.systemProxy)
            SwitchListTile(
              title: const Text('Register as the Windows system proxy'),
              subtitle: Text('127.0.0.1:${settings.httpPort} while connected'),
              value: settings.setSystemProxy,
              onChanged: locked
                  ? null
                  : (value) => controller
                      .updateSettings(settings.copyWith(setSystemProxy: value)),
            ),
          const Divider(),
          const _SectionHeader('Network'),
          _NumberTile(
            title: 'SOCKS port',
            value: settings.socksPort,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(socksPort: value)),
          ),
          _NumberTile(
            title: 'HTTP port',
            value: settings.httpPort,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(httpPort: value)),
          ),
          _TextTile(
            title: 'Remote DNS',
            subtitle: 'Resolved through the proxy',
            value: settings.remoteDns,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(remoteDns: value)),
          ),
          _TextTile(
            title: 'Direct DNS',
            subtitle: 'Used by the direct-routing rules',
            value: settings.directDns,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(directDns: value)),
          ),
          _NumberTile(
            title: 'MTU',
            value: settings.mtu,
            enabled: !locked && settings.mode == TunnelMode.tun,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(mtu: value)),
          ),
          const Divider(),
          const _SectionHeader('Routing'),
          SwitchListTile(
            title: const Text('Bypass local networks'),
            subtitle: const Text('Send private and link-local traffic directly'),
            value: settings.bypassLan,
            onChanged: locked
                ? null
                : (value) =>
                    controller.updateSettings(settings.copyWith(bypassLan: value)),
          ),
          SwitchListTile(
            title: const Text('Bypass mainland China'),
            subtitle: const Text('Route geosite:cn and geoip:cn directly'),
            value: settings.bypassMainland,
            onChanged: locked
                ? null
                : (value) => controller
                    .updateSettings(settings.copyWith(bypassMainland: value)),
          ),
          SwitchListTile(
            title: const Text('IPv6'),
            subtitle: const Text('Route IPv6 instead of blocking it'),
            value: settings.enableIpv6,
            onChanged: locked
                ? null
                : (value) =>
                    controller.updateSettings(settings.copyWith(enableIpv6: value)),
          ),
          ListTile(
            title: const Text('Log level'),
            trailing: DropdownButton<String>(
              value: settings.logLevel,
              onChanged: locked
                  ? null
                  : (value) => value == null
                      ? null
                      : controller
                          .updateSettings(settings.copyWith(logLevel: value)),
              items: VpnSettings.logLevels
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Administrator rights'),
            subtitle: Text(controller.isElevated ? 'Granted' : 'Not granted'),
            trailing: controller.isElevated
                ? null
                : TextButton(
                    onPressed: controller.relaunchElevated,
                    child: const Text('Restart as admin'),
                  ),
          ),
          ListTile(
            title: const Text('Xray-core'),
            subtitle: Text(
              controller.coreInstalled
                  ? 'Bundled next to the application'
                  : 'Missing — rebuild the app to install it',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _TextTile extends StatelessWidget {
  const _TextTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      title: Text(title),
      subtitle: Text(subtitle == null ? value : '$value · $subtitle'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: enabled
          ? () async {
              final result = await promptForValue(context, title, value);
              if (result != null && result.isNotEmpty) onChanged(result);
            }
          : null,
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      title: Text(title),
      subtitle: Text('$value'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: enabled
          ? () async {
              final result = await promptForValue(
                context,
                title,
                '$value',
                keyboardType: TextInputType.number,
              );
              final parsed = int.tryParse(result ?? '');
              if (parsed != null && parsed > 0 && parsed < 65536) onChanged(parsed);
            }
          : null,
    );
  }
}

Future<String?> promptForValue(
  BuildContext context,
  String title,
  String initial, {
  TextInputType? keyboardType,
}) {
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: keyboardType,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
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
}
