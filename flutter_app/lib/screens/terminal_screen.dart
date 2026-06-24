import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import 'ssh_screen.dart';
import 'settings_screen.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late Terminal terminal;
  Pty? pty;
  bool loading = true;
  String? error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    terminal = Terminal();
    _initTerminal();
  }

  Future<void> _initTerminal() async {
    try {
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config);
      final env = TerminalService.buildHostEnv(config);

      pty = Pty.start(
        args.isNotEmpty ? args[0] : '/system/bin/sh',
        arguments: args.length > 1 ? args.sublist(1) : [],
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
        environment: env,
        workingDirectory: config['homeDir'] ?? '/',
      );

      pty!.output.listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        terminal.write(text);
      });

      pty!.exitCode.then((code) {
        if (mounted) setState(() { error = 'Shell exited ($code)'; loading = false; });
      });

      terminal.onResize = (w, h, pw, ph) {
        pty?.resize(h, w, pw, ph);
      };

      terminal.onInput = (data) {
        pty?.write(utf8.encode(data));
      };

      if (mounted) setState(() { loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  void dispose() {
    pty?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildTerminalView(),
      const SshScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'XLinux' : (_selectedIndex == 1 ? 'SSH' : 'Settings')),
        actions: _selectedIndex == 0 ? [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            terminal.clear();
            loading = true;
            error = null;
            setState(() {});
            _initTerminal();
          }),
          IconButton(icon: const Icon(Icons.copy), onPressed: () {
            final text = terminal.buffer.toString();
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
          }),
        ] : null,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.terminal), label: 'Terminal'),
          NavigationDestination(icon: Icon(Icons.wifi), label: 'SSH'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    if (loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Starting Linux environment...'),
        ],
      ));
    }
    if (error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {
            setState(() { error = null; loading = true; });
            _initTerminal();
          }, child: const Text('Retry')),
        ],
      ));
    }
    return TerminalView(terminal: terminal);
  }
}
