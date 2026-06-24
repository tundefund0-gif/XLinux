class AppConstants {
  static const String appName = 'XLinux';
  static const String version = '2.0.0';
  static const String packageName = 'com.xlinux.terminal';

  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String channelName = 'com.xlinux.terminal/native';
  static const String eventChannelName = 'com.xlinux.terminal/logs';

  static const String ubuntuRootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';

  static String getRootfsUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return rootfsArm64;
      case 'arm':
        return rootfsArmhf;
      default:
        return rootfsArm64;
    }
  }
}
