import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'services/settings_controller.dart';

class DangerZoneApp extends StatefulWidget {
  const DangerZoneApp({super.key});

  @override
  State<DangerZoneApp> createState() => _DangerZoneAppState();
}

class _DangerZoneAppState extends State<DangerZoneApp> {
  final SettingsController _settings = SettingsController();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  ThemeData _buildTheme(bool useDyslexiaFont) {
    final base = ThemeData(
      primarySwatch: Colors.red,
      useMaterial3: true,
      fontFamily: useDyslexiaFont ? 'OpenDyslexic' : null,
    );

    if (!useDyslexiaFont) return base;

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'OpenDyslexic'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'OpenDyslexic'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep MapScreen as a stable child so theme/settings updates do not
    // recreate the map (which would drop markers and reset UI state).
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Eircode Danger Map',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(_settings.useDyslexiaFont),
          home: child,
        );
      },
      child: MapScreen(settings: _settings),
    );
  }
}
