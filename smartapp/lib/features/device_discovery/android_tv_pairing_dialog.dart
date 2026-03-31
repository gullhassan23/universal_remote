import 'package:flutter/material.dart';

/// PIN shown on the TV during Android TV Remote pairing.
Future<String?> showAndroidTvPairingDialog(BuildContext context) async {
  final controller = TextEditingController();
  const pinPattern = r'^[0-9A-Fa-f]{6}$';
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim().toUpperCase();
            final valid = RegExp(pinPattern).hasMatch(value);
            if (!valid) {
              setState(() {
                errorText =
                    'Code is not correct. Enter exactly 6 characters (0-9, A-F).';
              });
              return;
            }
            Navigator.of(context).pop(value);
          }

          return AlertDialog(
            title: const Text('Android TV pairing'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the 6-character code shown on your TV (0-9, A-F), then confirm on TV if asked.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.visiblePassword,
                  maxLength: 6,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'PIN',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setState(() {
                        errorText = null;
                      });
                    }
                  },
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}
