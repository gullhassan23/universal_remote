import 'package:flutter/material.dart';

/// Shows a dialog to enter the Sony TV Pre-Shared Key (PSK).
/// Returns the entered PSK on OK, or null on Cancel.
Future<String?> showSonyPairingDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Sony TV – Pre-Shared Key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter the key set in TV Settings > Network > IP Control',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.isEmpty ? null : value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
