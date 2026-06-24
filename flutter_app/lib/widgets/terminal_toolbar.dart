import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Virtual keyboard toolbar for terminal with Ctrl/Alt modifiers and special keys.
class TerminalToolbar extends StatelessWidget {
  final Terminal terminal;
  final ValueNotifier<bool> ctrlNotifier;
  final ValueNotifier<bool> altNotifier;

  const TerminalToolbar({
    super.key,
    required this.terminal,
    required this.ctrlNotifier,
    required this.altNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _modKey('Ctrl', ctrlNotifier),
          const SizedBox(width: 4),
          _modKey('Alt', altNotifier),
          const SizedBox(width: 8),
          _keyBtn('Tab'),
          _keyBtn('Esc'),
          _keyBtn('/'),
          _keyBtn('Up', Icons.keyboard_arrow_up),
          _keyBtn('Down', Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _modKey(String label, ValueNotifier<bool> notifier) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, active, __) => GestureDetector(
        onTap: () => notifier.value = !notifier.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.greenAccent.withAlpha(60) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? Colors.greenAccent : Colors.grey.shade800),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.greenAccent : Colors.grey.shade400,
          )),
        ),
      ),
    );
  }

  Widget _keyBtn(String key, [IconData? icon]) {
    return GestureDetector(
      onTap: () {
        String char;
        switch (key) {
          case 'Tab': char = '\t'; break;
          case 'Esc': char = '\x1b'; break;
          case 'Up': char = '\x1b[A'; break;
          case 'Down': char = '\x1b[B'; break;
          default: char = key;
        }
        if (ctrlNotifier.value) {
          char = String.fromCharCode(key.codeUnitAt(0) - (key.codeUnitAt(0) >= 97 ? 32 : 0) + 1);
          ctrlNotifier.value = false;
        }
        if (altNotifier.value) {
          char = '\x1b$key';
          altNotifier.value = false;
        }
        terminal.write(char);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: icon != null ? Icon(icon, size: 16, color: Colors.grey.shade400)
            : Text(key, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ),
    );
  }
}
