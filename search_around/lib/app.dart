import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

class DangerZoneApp extends StatelessWidget {
  const DangerZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eircode Danger Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}