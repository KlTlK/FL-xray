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
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          if (locked)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: const Text('Отключитесь для изменения настроек туннеля'),
            ),
          const _SectionHeader('Режим туннеля'),
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
                  title: const Text('TUN (полный туннель)'),
                  subtitle: Text(
                    controller.isElevated
                        ? 'Создаёт адаптер wintun и маршрутизирует всё через Xray'
                        : 'Создаёт адаптер wintun — требует запуска от администратора',
                  ),
                ),
                RadioListTile<TunnelMode>(
                  value: TunnelMode.systemProxy,
                  enabled: !locked,
                  title: const Text('Системный прокси'),
                  subtitle:
                      const Text('Локальные SOCKS/HTTP, повышение прав не требуется'),
                ),
              ],
            ),
          ),
          if (settings.mode == TunnelMode.systemProxy)
            SwitchListTile(
              title: const Text('Зарегистрировать как системный прокси Windows'),
              subtitle: Text('127.0.0.1:${settings.httpPort} while connected'),
              value: settings.setSystemProxy,
              onChanged: locked
                  ? null
                  : (value) => controller
                      .updateSettings(settings.copyWith(setSystemProxy: value)),
            ),
          const Divider(),
          const _SectionHeader('Сеть'),
          _NumberTile(
            title: 'Порт SOCKS',
            value: settings.socksPort,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(socksPort: value)),
          ),
          _NumberTile(
            title: 'Порт HTTP',
            value: settings.httpPort,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(httpPort: value)),
          ),
          _TextTile(
            title: 'Удалённый DNS',
            subtitle: 'Разрешается через прокси',
            value: settings.remoteDns,
            enabled: !locked,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(remoteDns: value)),
          ),
          _TextTile(
            title: 'Прямой DNS',
            subtitle: 'Используется правилами прямого маршрута',
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
          const _SectionHeader('Маршрутизация'),
          SwitchListTile(
            title: const Text('Обход локальных сетей'),
            subtitle: const Text('Приватный и локальный трафик идёт напрямую'),
            value: settings.bypassLan,
            onChanged: locked
                ? null
                : (value) =>
                    controller.updateSettings(settings.copyWith(bypassLan: value)),
          ),
          SwitchListTile(
            title: const Text('Обход материкового Китая'),
            subtitle: const Text('geosite:cn и geoip:cn идут напрямую'),
            value: settings.bypassMainland,
            onChanged: locked
                ? null
                : (value) => controller
                    .updateSettings(settings.copyWith(bypassMainland: value)),
          ),
          SwitchListTile(
            title: const Text('IPv6'),
            subtitle: const Text('Маршрутизировать IPv6 вместо блокировки'),
            value: settings.enableIpv6,
            onChanged: locked
                ? null
                : (value) =>
                    controller.updateSettings(settings.copyWith(enableIpv6: value)),
          ),
          ListTile(
            title: const Text('Уровень логов'),
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
            title: const Text('Права администратора'),
            subtitle: Text(controller.isElevated ? 'Получены' : 'Не получены'),
            trailing: controller.isElevated
                ? null
                : TextButton(
                    onPressed: controller.relaunchElevated,
                    child: const Text('Перезапуск от админа'),
                  ),
          ),
          ListTile(
            title: const Text('Xray-core'),
            subtitle: Text(
              controller.coreInstalled
                  ? 'Встроен в приложение'
                  : 'Отсутствует — пересоберите приложение',
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
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}
