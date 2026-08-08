import 'dart:io';

/// Locations of the bundled Xray-core files and of the generated runtime config.
class XrayPaths {
  XrayPaths({Directory? bundleDir, Directory? dataDir})
      : bundleDir = bundleDir ?? _defaultBundleDir(),
        dataDir = dataDir ?? _defaultDataDir();

  /// `data/xray` next to the application executable, as installed by CMake.
  final Directory bundleDir;

  /// Writable directory holding the generated `config.json`.
  final Directory dataDir;

  File get executable => File('${bundleDir.path}${Platform.pathSeparator}xray.exe');

  File get configFile => File('${dataDir.path}${Platform.pathSeparator}config.json');

  bool get isBundled => executable.existsSync();

  static Directory _defaultBundleDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final separator = Platform.pathSeparator;
    return Directory('$exeDir${separator}data${separator}xray');
  }

  static Directory _defaultDataDir() {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}FL-xray');
  }
}
