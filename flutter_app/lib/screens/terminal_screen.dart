import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';
import 'ssh_screen.dart';
import 'settings_screen.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      onTitleChanged: (title) => setState(() {}),
      maxLines: 10000,
    );
    _controller = TerminalController();
    _initTerminal();
  }

  Future<void> _initTerminal() async {
    try {
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();
      final config = await TerminalService.getProotShellConfig();
      final columns = _terminal.width;
      final rows = _terminal.height;
      final args = TerminalService.buildProotArgs(config, columns: columns, rows: rows);
      final env = TerminalService.buildHostEnv(config);
      final workDir = config['homeDir'] ?? '/';

      _pty = Pty.start(
        args.isNotEmpty ? args[0] : '/system/bin/sh',
        arguments: args.length > 1 ? args.sublist(1) : [],
        columns: columns,
        rows: rows,
        environment: env,
        workingDirectory: workDir,
      );

      _pty!.output.listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        _terminal.write(text);
      });

      _pty!.exitCode.then((code) {
        if (mounted) {
          setState(() { _error = 'Shell exited with code $code'; _loading = false; });
        }
      });

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w, pw, ph);
      };

      _terminal.onInput = (data) {
        _pty?.write(utf8.encode(data));
      };

      if (mounted) setState(() { _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _pty?.kill();
    _terminal.dispose();
    _controller.dispose();
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { _terminal.clear(); _initTerminal(); },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = _terminal.buffer.getText();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
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
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Starting Linux environment...'),
        ],
      ));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () { setState(() { _error = null; _loading = true; }); _initTerminal(); },
            child: const Text('Retry')),
        ],
      ));
    }
    return Column(children: [
      Expanded(child: TerminalView(
        terminal: _terminal,
        controller: _controller,
        textStyle: const TextStyle(
          fontFamily: 'DejaVu Sans Mono',
          fontSize: 14,
          color: Color(0xFFCCCCCC),
        ),
      )),
      TerminalToolbar(
        terminal: _terminal,
        ctrlNotifier: _ctrlNotifier,
        altNotifier: _altNotifier,
      ),
    ]);
  }
}
