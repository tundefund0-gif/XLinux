# XLinux Terminal

Lightweight Linux terminal for Android with built-in SSH server. Based on OpenClaw-termux's proven PRoot infrastructure, stripped to essentials.

## Features

- **Linux Terminal** — Full PRoot-based Linux environment (Ubuntu, Alpine, etc.)
- **Built-in SSH Server** — Dropbear/OpenSSH with auto-restart (up to 50 retries)
- **Background SSH** — Persistent foreground service with wake lock
- **GUI Support** — VNC/X11 via PRoot bind mounts
- **ARMv7 + ARM64** — Native support for both architectures
- **Lightweight** — No Node.js, no AI gateway, just terminal + SSH

## How It Works

XLinux uses Android's `nativeLibraryDir` to store PRoot binaries (libproot.so, libprootloader.so, libtalloc.so). Android extracts these to an executable directory, bypassing Android 15's noexec restrictions.

The SSH service runs as a foreground service with exponential backoff restart logic (2s → 3s → 5s delays) and uses system DNS servers from Android's NetworkInterface.

## Build

```bash
cd flutter_app
flutter pub get
flutter build apk --debug
```

## SSH Usage

1. Install OpenSSH in your Linux environment: `apt install openssh-server`
2. Set a root password in the app
3. Toggle SSH on
4. Connect: `ssh root@<device-ip>:8022`

## License

MIT — Based on [OpenClaw-termux](https://github.com/mithun50/openclaw-termux)
