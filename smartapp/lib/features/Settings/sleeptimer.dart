import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';

import '../../controllers/sleep_timer_controller.dart';

class SleepTimerUI extends GetView<SleepTimerController> {
  const SleepTimerUI({super.key});

  @override
  Widget build(BuildContext context) {
    final presets = <_TimerPreset>[
      _TimerPreset(label: '10 min', duration: const Duration(minutes: 10)),
      _TimerPreset(label: '20 min', duration: const Duration(minutes: 20)),
      _TimerPreset(label: '30 min', duration: const Duration(minutes: 30)),
      _TimerPreset(label: '1 hr', duration: const Duration(hours: 1)),
      _TimerPreset(label: '3 hr', duration: const Duration(hours: 3)),
      _TimerPreset(label: 'Custom'),
    ];

    return Scaffold(
      body: Container(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  ImageRes.kGetStartedBackgroundAsset2,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white, size: 20),
                          onPressed: HapticAction.wrap(Get.back),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Sleep timer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SLEEP IN:',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: presets
                          .map((preset) => Obx(() {
                                final selected =
                                    controller.selectedDuration.value ==
                                        preset.duration;
                                return _buildButton(
                                  preset.label,
                                  isSelected: selected,
                                  onTap: () =>
                                      _handlePresetTap(context, preset),
                                );
                              }))
                          .toList(),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'SLEEP AT:',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    Obx(() {
                      final running = controller.isRunning.value;
                      if (!running) {
                        return _buildStatusChip(
                          icon: Icons.timer_off_outlined,
                          label: 'No active sleep timer',
                        );
                      }
                      return Column(
                        children: [
                          _buildStatusChip(
                            icon: Icons.timer_outlined,
                            label:
                                'Timer running: ${controller.remainingLabel}',
                          ),
                          const SizedBox(height: 12),
                          _buildStatusChip(
                            icon: Icons.schedule_outlined,
                            label: 'Sleep at ${controller.endTimeLabel}',
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 20),
                    Obx(() {
                      if (!controller.isRunning.value)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildFullWidthButton(
                          'Cancel timer',
                          onTap: controller.cancel,
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'The Sleep timer only works if the app is connected to your TV. In order to keep the app connected please do not close the app',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePresetTap(
    BuildContext context,
    _TimerPreset preset,
  ) async {
    final duration = preset.duration;
    if (duration == null) {
      final selectedDuration = await _showCustomTimerBottomSheet(context);
      if (selectedDuration != null) {
        controller.reset(selectedDuration);
      }
      return;
    }
    controller.reset(duration);
  }

  Future<Duration?> _showCustomTimerBottomSheet(BuildContext context) {
    var selectedHours = 0;
    var selectedMinutes = 15;

    return showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalMinutes = (selectedHours * 60) + selectedMinutes;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Sleep Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select hours and minutes',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _numberPickerColumn(
                            title: 'Hours',
                            value: selectedHours,
                            min: 0,
                            max: 12,
                            onChanged: (value) {
                              setState(() => selectedHours = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numberPickerColumn(
                            title: 'Minutes',
                            value: selectedMinutes,
                            min: 0,
                            max: 59,
                            onChanged: (value) {
                              setState(() => selectedMinutes = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      totalMinutes == 0
                          ? 'Please select a duration'
                          : 'Timer will run for ${selectedHours}h ${selectedMinutes}m',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFullWidthButton(
                            'Cancel',
                            onTap: () => Navigator.of(bottomSheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildFullWidthButton(
                            'Start',
                            onTap: () {
                              if (totalMinutes <= 0) return;
                              Navigator.of(bottomSheetContext).pop(
                                Duration(
                                  hours: selectedHours,
                                  minutes: selectedMinutes,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _numberPickerColumn({
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final items = List<int>.generate((max - min) + 1, (index) => min + index);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C1C1E),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              iconEnabledColor: Colors.white70,
              items: items
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item,
                      child: Text(item.toString().padLeft(2, '0')),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next == null) return;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String label, {
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: HapticAction.wrap(onTap),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005AFF) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: HapticAction.wrap(onTap),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({required IconData icon, required String label}) {
    return Container(
      width: double.infinity,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerPreset {
  const _TimerPreset({required this.label, this.duration});

  final String label;
  final Duration? duration;
}
