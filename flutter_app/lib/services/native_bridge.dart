import 'package:flutter/services.dart';
import '../constants.dart';

class NativeBridge {
  static const _channel = MethodChannel(AppConstants.channelName);

  static Future<String> getProotPath() async => await _channel.invokeMethod('getProotPath');
  static Future<String> getArch() async => await _channel.invokeMethod('getArch');
  static Future<String> getFilesDir() async => await _channel.invokeMethod('getFilesDir');
  static Future<String> getNativeLibDir() async => await _channel.invokeMethod('getNativeLibDir');
  static Future<bool> isBootstrapComplete() async => await _channel.invokeMethod('isBootstrapComplete');
  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _channel.invokeMethod('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }
  static Future<bool> extractRootfs(String tarPath) async =>
      await _channel.invokeMethod('extractRootfs', {'tarPath': tarPath});
  static Future<String> runInProot(String command, {int timeout = 900}) async =>
      await _channel.invokeMethod('runInProot', {'command': command, 'timeout': timeout});
  static Future<bool> setupDirs() async => await _channel.invokeMethod('setupDirs');
  static Future<bool> writeResolv() async => await _channel.invokeMethod('writeResolv');
  static Future<bool> hasStoragePermission() async => await _channel.invokeMethod('hasStoragePermission');
  static Future<bool> requestStoragePermission() async => await _channel.invokeMethod('requestStoragePermission');

  // SSH
  static Future<bool> startSshd({int port = 8022}) async =>
      await _channel.invokeMethod('startSshd', {'port': port});
  static Future<bool> stopSshd() async => await _channel.invokeMethod('stopSshd');
  static Future<bool> isSshdRunning() async => await _channel.invokeMethod('isSshdRunning');
  static Future<int> getSshdPort() async => await _channel.invokeMethod('getSshdPort');
  static Future<List<String>> getDeviceIps() async {
    final result = await _channel.invokeMethod('getDeviceIps');
    return List<String>.from(result);
  }
  static Future<bool> setRootPassword(String password) async =>
      await _channel.invokeMethod('setRootPassword', {'password': password});
  static Future<bool> bringToForeground() async => await _channel.invokeMethod('bringToForeground');
}
