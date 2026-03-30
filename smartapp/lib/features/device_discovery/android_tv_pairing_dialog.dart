import 'package:flutter/material.dart';

/// PIN shown on the TV during Android TV Remote pairing.
Future<String?> showAndroidTvPairingDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Android TV pairing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit code shown on your TV, then confirm on the TV if asked.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'PIN',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim()),
            ),
          ],
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
