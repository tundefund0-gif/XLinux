import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ssh_service.dart';

class SshScreen extends StatefulWidget {
  const SshScreen({super.key});
  @override
  State<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends State<SshScreen> {
  bool _loading = true;
  bool _installed = false;
  bool _running = false;
  bool _toggling = false;
  bool _settingPassword = false;
  final _portController = TextEditingController(text: '8022');
  final _passwordController = TextEditingController();
  List<String> _ips = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _installed = await SshService.isInstalled();
      _running = await SshService.isSshdRunning();
      _ips = await SshService.getIpAddresses();
      final port = await SshService.getPort();
      _portController.text = port.toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleSsh() async {
    setState(() => _toggling = true);
    try {
      if (_running) {
        await SshService.stopSshd();
      } else {
        final password = _passwordController.text.trim();
        if (password.isNotEmpty) {
          await SshService.setPassword(password);
        }
        final port = int.tryParse(_portController.text) ?? 8022;
        await SshService.startSshd(port: port);
      }
      await Future.delayed(const Duration(seconds: 1));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (!_installed) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text('OpenSSH not installed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Install OpenSSH inside your Linux environment first:', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
            child: const Text('apt update && apt install -y openssh-server', style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('Refresh')),
        ]),
      ));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_running ? Icons.wifi : Icons.wifi_off, color: _running ? Colors.green : Colors.grey, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_running ? 'SSH Server Running' : 'SSH Server Stopped',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_running) Text('Port: ${_portController.text}', style: TextStyle(color: Colors.grey[400])),
              ])),
              Switch(value: _running, onChanged: _toggling ? null : (_) => _toggleSsh(),
                activeColor: Colors.green),
            ]),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Root Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _settingPassword ? null : () async {
                    setState(() => _settingPassword = true);
                    await SshService.setPassword(_passwordController.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password set')));
                      setState(() => _settingPassword = false);
                    }
                  },
                ),
              ),
              obscureText: true,
            ),
          ]),
        )),
        const SizedBox(height: 12),
        if (_running) Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Connection Info', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._ips.map((ip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('ssh root@$ip:${_portController.text}',
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent))),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'ssh root@$ip:${_portController.text}'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
              ]),
            )),
            if (_ips.isEmpty) const Text('No network connection found'),
          ]),
        )),
      ]),
    );
  }
}
