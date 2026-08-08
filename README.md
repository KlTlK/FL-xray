# FL-xray

VPN client for Windows built on [Xray-core](https://github.com/XTLS/Xray-core) and Flutter.

## Features

- Import `vless://`, `vmess://`, `trojan://` and `ss://` links, or a whole subscription (plain or base64)
- Two tunnelling modes, switchable in settings:
  - **TUN** — a wintun adapter with split default routes captures all traffic (requires administrator rights)
  - **System proxy** — local SOCKS/HTTP inbounds, optionally registered as the Windows system proxy
- Server list with TCP latency measurement, rename and delete
- Live connection state, uptime and proxied traffic counters (from the Xray metrics endpoint)
- Routing options: bypass LAN, bypass mainland China (via the bundled geo files), IPv6 on/off
- Live Xray log tail

## Building

Requires Flutter 3.35+ with the Windows desktop toolchain (Visual Studio with the
"Desktop development with C++" workload).

```powershell
flutter pub get
flutter build windows --release
```

The build downloads the official `Xray-windows-64.zip` release (pinned by version and
SHA-256 in `windows/CMakeLists.txt`) and installs `xray.exe`, `wintun.dll` and the geo
databases into `data/xray` next to the app, so nothing binary is committed to the repo.

The release bundle lands in `build\windows\x64\runner\Release`. CI builds the same bundle
on every pull request and uploads it as an artifact.

## Running

Start `fl_xray.exe`, add a server, pick a mode and hit the power button.

TUN mode needs elevation — the app detects this and offers to restart itself through UAC.
System proxy mode works unelevated; while connected the inbounds are reachable at
`127.0.0.1:10808` (SOCKS) and `127.0.0.1:10809` (HTTP).

## Development

```powershell
flutter analyze
flutter test
```
