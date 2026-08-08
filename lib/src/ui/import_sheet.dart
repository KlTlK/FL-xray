import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/vpn_controller.dart';

Future<void> showImportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _ImportSheet(),
    ),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _linksController = TextEditingController();
  final _subscriptionController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscriptionController.text =
        context.read<VpnController>().subscriptionUrl ?? '';
  }

  @override
  void dispose() {
    _tabs.dispose();
    _linksController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  Future<void> _import(Future<int> Function(VpnController) action) async {
    final controller = context.read<VpnController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final count = await action(controller);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(count == 0 ? 'Nothing to import' : 'Imported $count servers'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Share links'), Tab(text: 'Subscription')],
            ),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _linksTab(),
                  _subscriptionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linksTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _linksController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'vless://…\nvmess://…\ntrojan://…\nss://…',
                labelText: 'One link per line, base64 or raw Xray json',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _linksController.text = data!.text!;
                        }
                      },
                icon: const Icon(Icons.paste),
                label: const Text('Paste'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _import(
                          (controller) =>
                              controller.importText(_linksController.text.trim()),
                        ),
                child: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subscriptionTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          TextField(
            controller: _subscriptionController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Subscription URL',
              hintText: 'https://example.com/sub',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _import(
                        (controller) => controller
                            .importSubscription(_subscriptionController.text.trim()),
                      ),
              child: const Text('Fetch and import'),
            ),
          ),
        ],
      ),
    );
  }
}
