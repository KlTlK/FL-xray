import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows elevation helpers: the tun adapter can only be created by an admin.
class Elevation {
  const Elevation();

  static const _tokenElevation = 20;
  static const _seeMaskNoCloseProcess = 0x00000040;

  bool get isElevated {
    final token = calloc<IntPtr>();
    final elevation = calloc<Uint32>();
    final returned = calloc<Uint32>();
    try {
      if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, token) == 0) {
        return false;
      }
      final ok = GetTokenInformation(
        token.value,
        _tokenElevation,
        elevation.cast(),
        sizeOf<Uint32>(),
        returned,
      );
      return ok != 0 && elevation.value != 0;
    } finally {
      if (token.value != 0) CloseHandle(token.value);
      free(token);
      free(elevation);
      free(returned);
    }
  }

  /// Restarts the app through the UAC prompt. Returns false when the user declines.
  bool relaunchElevated() {
    final info = calloc<SHELLEXECUTEINFO>();
    final verb = 'runas'.toNativeUtf16();
    final file = Platform.resolvedExecutable.toNativeUtf16();
    final directory =
        File(Platform.resolvedExecutable).parent.path.toNativeUtf16();
    try {
      info.ref
        ..cbSize = sizeOf<SHELLEXECUTEINFO>()
        ..fMask = _seeMaskNoCloseProcess
        ..lpVerb = verb
        ..lpFile = file
        ..lpDirectory = directory
        ..nShow = SW_SHOWNORMAL;
      return ShellExecuteEx(info) != 0;
    } finally {
      free(info);
      free(verb);
      free(file);
      free(directory);
    }
  }
}
