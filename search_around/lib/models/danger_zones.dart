import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Add this package import

enum RiskLevel { yellow, red, black }

class DangerZone {
  final String id;
  final String areaName;
  final List<LatLng> coordinates; // Now using latlong2's LatLng
  final RiskLevel riskLevel;

  DangerZone({
    required this.id,
    required this.areaName,
    required this.coordinates,
    required this.riskLevel,
  });

  // Convert our model directly into a flutter_map Polygon
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
      points: coordinates,
      borderColor: strokeColor,
      borderStrokeWidth: 2,
      color: fillColor,
      isFilled: true,
    );
  }
}