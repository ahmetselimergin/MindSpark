import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(appProgressControllerProvider).value;
    final controller = ref.read(appProgressControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: SafeArea(
        child: progress == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  SwitchListTile(
                    title: const Text('Sound'),
                    subtitle: const Text('Coming soon'),
                    value: progress.soundEnabled,
                    onChanged: controller.setSoundEnabled,
                  ),
                  SwitchListTile(
                    title: const Text('Vibration'),
                    subtitle: const Text('Coming soon'),
                    value: progress.vibrationEnabled,
                    onChanged: controller.setVibrationEnabled,
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('RESET PROGRESS'),
                      onPressed: () => _confirmReset(context, ref),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final controller = ref.read(appProgressControllerProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This erases all progress and returns you to level 1. '
          'Your sound and vibration settings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await controller.resetProgress();
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }
}
