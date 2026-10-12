import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

/// Bottom-right settings control with an inline accessibility panel.
class SettingsButton extends StatefulWidget {
  final SettingsController settings;

  const SettingsButton({super.key, required this.settings});

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: ListenableBuilder(
                    listenable: widget.settings,
                    builder: (context, _) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Dyslexia-friendly font'),
                              subtitle: const Text(
                                'Use OpenDyslexic for easier reading',
                              ),
                              value: widget.settings.useDyslexiaFont,
                              onChanged: (value) {
                                widget.settings.setUseDyslexiaFont(value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 56,
            height: 56,
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: const CircleBorder(),
              elevation: 6,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _open = !_open),
                child: Icon(
                  _open ? Icons.close : Icons.settings,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
