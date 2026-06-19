import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/danger_zones.dart';

class MapAssetService {
  Future<String> loadMapStyle() async {
    try {
      return await rootBundle.loadString('assets/map_style.json');
    } catch (_) {
      return '';
    }
  }

  // Parses the extracted Google My Maps JSON format
  Future<List<DangerZone>> loadDangerZonesFromAsset() async {
    List<DangerZone> zones = [];
    try {
      final String response = await rootBundle.loadString('assets/danger_regions.json');
      final Map<String, dynamic> data = json.decode(response);
      
      final features = data['features'] as List<dynamic>;

      for (var feature in features) {
        final properties = feature['properties'] ?? {};
        final geometry = feature['geometry'] ?? {};
        final String name = properties['name'] ?? 'Unnamed Area';
        final String description = (properties['description'] ?? '').toString().toLowerCase();
        
        // Infer risk categorization from My Maps layer text descriptions
        RiskLevel level = RiskLevel.yellow; 
        if (description.contains('alto') || description.contains('high') || description.contains('médio')) {
          level = RiskLevel.red;
        } else if (description.contains('crítico') || description.contains('black') || description.contains('perigoso')) {
          level = RiskLevel.black;
        }

        // Handle poly coordinate conversion mapping safely
        if (geometry['type'] == 'Polygon') {
          List<LatLng> points = [];
          var coordinatesList = geometry['coordinates'][0] as List<dynamic>;
          
          for (var coord in coordinatesList) {
            // GeoJSON coordinates come ordered as [Longitude, Latitude]
            points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
          }

          zones.add(DangerZone(
            id: name.replaceAll(' ', '_').toLowerCase(),
            areaName: name,
            coordinates: points,
            riskLevel: level,
          ));
        }
      }
    } catch (e) {
      // Return fallback shapes placeholder if asset compilation fails
      print('Failed parsing map asset details: $e');
    }
    return zones;
  }
}