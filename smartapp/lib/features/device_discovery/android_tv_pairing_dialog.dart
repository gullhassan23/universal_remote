import 'package:flutter/material.dart';

/// PIN shown on the TV during Android TV Remote pairing.
// Future<String?> showAndroidTvPairingDialog(BuildContext context) async {
//   final controller = TextEditingController();
//   const pinPattern = r'^[0-9A-Fa-f]{6}$';
//   return showDialog<String>(
//     context: context,
//     barrierDismissible: false,
//     builder: (context) {
//       String? errorText;
//       return StatefulBuilder(
//         builder: (context, setState) {
//           void submit() {
//             final value = controller.text.trim().toUpperCase();
//             final valid = RegExp(pinPattern).hasMatch(value);
//             if (!valid) {
//               setState(() {
//                 errorText = 'Enter exactly 6 characters (0-9, A-F).';
//               });
//               return;
//             }
//             Navigator.of(context).pop(value);
//           }

//           return AnimatedPadding(
//             duration: const Duration(milliseconds: 200),
//             curve: Curves.easeOut,
//             padding: EdgeInsets.only(
//               left: 20,
//               right: 20,
//               top: 24,
//               bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
//             ),
//             child: Center(
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 420),
//                 child: Dialog(
//                   backgroundColor: Colors.transparent,
//                   insetPadding: EdgeInsets.zero,
//                   child: SingleChildScrollView(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF2D2D2D),
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
//                             child: Column(
//                               children: [
//                                 const Text(
//                                   'Device pairing',
//                                   textAlign: TextAlign.center,
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   'Please enter the pin code displayed on\nyour TV.',
//                                   textAlign: TextAlign.center,
//                                   style: TextStyle(
//                                     color: Colors.white.withValues(alpha: 0.9),
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w500,
//                                     height: 1.2,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 14),
//                                 TextField(
//                                   controller: controller,
//                                   keyboardType: TextInputType.visiblePassword,
//                                   maxLength: 6,
//                                   autofocus: true,
//                                   textInputAction: TextInputAction.done,
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 17,
//                                     letterSpacing: 2.0,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                   decoration: InputDecoration(
//                                     hintText: '------',
//                                     hintStyle: TextStyle(
//                                       color: Colors.white.withValues(alpha: 0.35),
//                                       letterSpacing: 2.0,
//                                     ),
//                                     filled: true,
//                                     fillColor: const Color(0xFF3A3A3A),
//                                     border: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(10),
//                                       borderSide: BorderSide.none,
//                                     ),
//                                     contentPadding: const EdgeInsets.symmetric(
//                                       horizontal: 12,
//                                       vertical: 12,
//                                     ),
//                                     errorText: errorText,
//                                     counterText: '',
//                                   ),
//                                   onChanged: (_) {
//                                     if (errorText != null) {
//                                       setState(() {
//                                         errorText = null;
//                                       });
//                                     }
//                                   },
//                                   onSubmitted: (_) => submit(),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Divider(
//                             height: 1,
//                             thickness: 1,
//                             color: Colors.white.withValues(alpha: 0.2),
//                           ),
//                           SizedBox(
//                             height: 50,
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: TextButton(
//                                     onPressed: () => Navigator.of(context).pop(null),
//                                     style: TextButton.styleFrom(
//                                       foregroundColor: Colors.white,
//                                       shape: const RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.only(
//                                           bottomLeft: Radius.circular(16),
//                                         ),
//                                       ),
//                                     ),
//                                     child: const Text(
//                                       'Cancel',
//                                       style: TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 VerticalDivider(
//                                   width: 1,
//                                   thickness: 1,
//                                   color: Colors.white.withValues(alpha: 0.2),
//                                 ),
//                                 Expanded(
//                                   child: TextButton(
//                                     onPressed: submit,
//                                     style: TextButton.styleFrom(
//                                       foregroundColor: Colors.white,
//                                       shape: const RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.only(
//                                           bottomRight: Radius.circular(16),
//                                         ),
//                                       ),
//                                     ),
//                                     child: const Text(
//                                       'OK',
//                                       style: TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//     },
//   );
// }


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
                errorText = 'Enter exactly 6 characters (0-9, A-F).';
              });
              return;
            }

            Navigator.of(context).pop(value);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.minHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// TOP CONTENT
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 10),
                              child: Column(
                                children: [
                                  const Text(
                                    'Device pairing',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please enter the pin code displayed on\nyour TV.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  /// INPUT FIELD
                                  TextField(
                                    controller: controller,
                                    keyboardType:
                                        TextInputType.visiblePassword,
                                    maxLength: 6,
                                    autofocus: true,
                                    textInputAction: TextInputAction.done,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: '------',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        letterSpacing: 2,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF3A3A3A),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      errorText: errorText,
                                      counterText: '',
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
                            ),

                            /// DIVIDER
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),

                            /// BUTTONS
                            SizedBox(
                              height: 50,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(null),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        shape:
                                            const RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.only(
                                            bottomLeft:
                                                Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color:
                                        Colors.white.withOpacity(0.2),
                                  ),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: submit,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        shape:
                                            const RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.only(
                                            bottomRight:
                                                Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}
