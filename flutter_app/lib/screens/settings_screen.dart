import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/native_bridge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      _arch = await NativeBridge.getArch();
      _prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      _status = Map<String, dynamic>.from(status);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('XLinux ${AppConstants.version}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _info('Architecture', _arch),
          _info('PRoot', _prootPath.isNotEmpty ? 'Found' : 'Missing'),
          _info('Rootfs', _status['rootfsExists'] == true ? 'Ready' : 'Not installed'),
          _info('Shell', _status['binBashExists'] == true ? 'Available' : 'Missing'),
        ]),
      )),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: const Icon(Icons.refresh),
        title: const Text('Refresh Status'),
        onTap: _loadInfo,
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('Reset Environment', style: TextStyle(color: Colors.red)),
        subtitle: const Text('Remove rootfs and re-extract'),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Reset Environment?'),
              content: const Text('This will delete the Linux rootfs. You will need to re-extract it.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm == true) {
            await NativeBridge.extractRootfs('');
            await _loadInfo();
          }
        },
      )),
    ]);
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[400])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
