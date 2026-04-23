import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';

class RemoteStyleScreen extends StatefulWidget {
  const RemoteStyleScreen({super.key});

  @override
  State<RemoteStyleScreen> createState() => _RemoteStyleScreenState();
}

class _RemoteStyleScreenState extends State<RemoteStyleScreen> {
  final RemoteStyleController _styleController =
      Get.find<RemoteStyleController>();

  @override
  void initState() {
    super.initState();
    _styleController.prepareSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(ImageRes.kGetStartedBackgroundAsset2),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.adaptive.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: HapticAction.wrap(Get.back),
                      padding: const EdgeInsets.only(left: 12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Remote Style',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: _styleController.wallpapers.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final wallpaperPath = _styleController.wallpapers[index];
                      return Obx(() {
                        final isSelected =
                            _styleController.selectedWallpaper.value ==
                                wallpaperPath;

                        return GestureDetector(
                          onTap: () =>
                              _styleController.selectWallpaper(wallpaperPath),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4FC3F7)
                                    : Colors.white24,
                                width: isSelected ? 3 : 1,
                              ),
                              image: DecorationImage(
                                image: AssetImage(wallpaperPath),
                                fit: BoxFit.cover,
                              ),
                            ),
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? const Color(0xFF4FC3F7)
                                  : Colors.white70,
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _styleController.applySelection();
                      if (!context.mounted) return;
                      Get.back<void>();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
