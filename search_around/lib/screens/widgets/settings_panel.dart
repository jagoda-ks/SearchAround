import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

/// Bottom-right settings control that opens accessibility options.
class SettingsButton extends StatelessWidget {
  final SettingsController settings;

  const SettingsButton({super.key, required this.settings});

  Future<void> _openSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dyslexia-friendly font'),
                      subtitle: const Text(
                        'Use OpenDyslexic for easier reading',
                      ),
                      value: settings.useDyslexiaFont,
                      onChanged: (value) {
                        settings.setUseDyslexiaFont(value);
                      },
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

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings),
        onPressed: () => _openSettings(context),
      ),
    );
  }
}
