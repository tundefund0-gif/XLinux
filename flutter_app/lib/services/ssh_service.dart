import 'dart:io';
import 'native_bridge.dart';

class SshService {
  static String? _rootfsDir;

  static Future<String> _getRootfsDir() async {
    if (_rootfsDir != null) return _rootfsDir!;
    final filesDir = await NativeBridge.getFilesDir();
    _rootfsDir = '$filesDir/rootfs/ubuntu';
    return _rootfsDir!;
  }

  static Future<bool> isInstalled() async {
    final rootfs = await _getRootfsDir();
    return File('$rootfs/usr/sbin/sshd').existsSync() ||
        File('$rootfs/usr/bin/sshd').existsSync() ||
        File('$rootfs/usr/sbin/dropbear').existsSync() ||
        File('$rootfs/usr/bin/dropbear').existsSync();
  }

  static Future<bool> isSshdRunning() async {
    try { return await NativeBridge.isSshdRunning(); } catch (_) { return false; }
  }

  static Future<void> startSshd({int port = 8022}) async {
    await NativeBridge.startSshd(port: port);
  }

  static Future<void> stopSshd() async {
    await NativeBridge.stopSshd();
  }

  static Future<void> setPassword(String password) async {
    await NativeBridge.setRootPassword(password);
  }

  static Future<List<String>> getIpAddresses() async {
    try { return await NativeBridge.getDeviceIps(); } catch (_) { return []; }
  }

  static Future<int> getPort() async {
    try { return await NativeBridge.getSshdPort(); } catch (_) { return 8022; }
  }
}
