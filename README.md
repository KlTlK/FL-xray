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

