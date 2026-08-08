import 'dart:ffi';

import 'package:win32_registry/win32_registry.dart';

/// Registers the local Xray HTTP inbound as the WinINET system proxy.
class SystemProxy {
  const SystemProxy();

  static const _internetSettingsPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const _bypassList =
      '<local>;localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;'
      '172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;'
      '172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*';

  void enable(int httpPort) {
    _withKey((key) {
      key.createValue(const RegistryValue.int32('ProxyEnable', 1));
      key.createValue(
        RegistryValue.string('ProxyServer', '127.0.0.1:$httpPort'),
      );
      key.createValue(const RegistryValue.string('ProxyOverride', _bypassList));
    });
    _notifyWinInet();
  }

  void disable() {
    _withKey((key) {
      key.createValue(const RegistryValue.int32('ProxyEnable', 0));
    });
    _notifyWinInet();
  }

  bool get isEnabled {
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: _internetSettingsPath,
    );
    try {
      return key.getIntValue('ProxyEnable') == 1;
    } finally {
      key.close();
    }
  }

  void _withKey(void Function(RegistryKey key) action) {
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: _internetSettingsPath,
      desiredAccessRights: AccessRights.allAccess,
    );
    try {
      action(key);
    } finally {
      key.close();
    }
  }

  /// Running processes only pick the new settings up after these notifications.
  void _notifyWinInet() {
    _internetSetOption(nullptr, _internetOptionSettingsChanged, nullptr, 0);
    _internetSetOption(nullptr, _internetOptionRefresh, nullptr, 0);
  }
}

const _internetOptionRefresh = 37;
const _internetOptionSettingsChanged = 39;

final _internetSetOption = DynamicLibrary.open('wininet.dll').lookupFunction<
    Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
    int Function(Pointer<Void>, int, Pointer<Void>, int)>('InternetSetOptionW');
