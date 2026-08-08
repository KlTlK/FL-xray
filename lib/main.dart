import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/state/vpn_controller.dart';
import 'src/ui/root_page.dart';

void main() {
  runApp(const FlXrayApp());
}

class FlXrayApp extends StatelessWidget {
  const FlXrayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VpnController()..initialize(),
      child: MaterialApp(
        title: 'FL-xray',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3D5AFE),
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF3D5AFE),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const RootPage(),
      ),
    );
  }
}
