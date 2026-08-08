import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/vpn_controller.dart';
import 'connection_page.dart';
import 'logs_page.dart';
import 'servers_page.dart';
import 'settings_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  static const _pages = [
    ConnectionPage(),
    ServersPage(),
    LogsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final ready = context.select<VpnController, bool>((controller) => controller.ready);
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Connection'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Servers'),
          NavigationDestination(icon: Icon(Icons.article_outlined), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
