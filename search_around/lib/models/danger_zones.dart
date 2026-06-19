import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RiskLevel { yellow, red, black }

class DangerZone {
  final String id;
  final String areaName;
  final List<LatLng> coordinates;
  final RiskLevel riskLevel;

  DangerZone({
    required this.id,
    required this.areaName,
    required this.coordinates,
    required this.riskLevel,
  });

  // Generates a map polygon styling package dynamically based on level
  Polygon toPolygon() {
    Color strokeColor;
    Color fillColor;

    switch (riskLevel) {
      case RiskLevel.yellow:
        strokeColor = Colors.yellow.shade700;
        fillColor = Colors.yellow.withOpacity(0.3);
        break;
      case RiskLevel.red:
        strokeColor = Colors.red.shade800;
        fillColor = Colors.red.withOpacity(0.4);
        break;
      case RiskLevel.black:
        strokeColor = Colors.black;
        fillColor = Colors.black.withOpacity(0.65);
        break;
    }

    return Polygon(
      polygonId: PolygonId(id),
      points: coordinates,
      strokeWidth: 2,
      strokeColor: strokeColor,
      fillColor: fillColor,
    );
  }
}