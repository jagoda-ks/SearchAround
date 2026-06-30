import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/danger_zones.dart';

class MapAssetService {
  Future<String> loadMapStyle() async {
    try {
      return await rootBundle.loadString('assets/map_style.json');
    } catch (_) {
      return '';
    }
  }

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
        
        // Extract style indicators directly injected by the map converter
        final String fillHex = (properties['fill'] ?? properties['stroke'] ?? '').toString().toLowerCase();
        final String description = (properties['description'] ?? '').toString().toLowerCase();
        final String nameLower = name.toLowerCase();
        
        // 1. DETERMINE RISK LEVEL ACCURATELY BY RECOGNIZING BOTH TEXT AND HEX COLOR CODES
        RiskLevel level = RiskLevel.yellow; // Default fallback

        // Catching Black/Critical zones
        if (fillHex.contains('000000') || 
            description.contains('crítico') || description.contains('critico') || 
            description.contains('critical') || description.contains('black') ||
            nameLower.contains('crítico') || nameLower.contains('black')) {
          level = RiskLevel.black;
          
        // Catching Red/High-risk zones (Google Maps often uses variations of red/orange hexes like #ff0000 or #e65100)
        } else if (fillHex.contains('ff0000') || fillHex.contains('e651') || fillHex.contains('d500') ||
                   description.contains('alto') || description.contains('high') || 
                   description.contains('red') || nameLower.contains('red')) {
          level = RiskLevel.red;
        }

        final String geometryType = geometry['type'] ?? '';

        // 2. EXTRACT GEOMETRIES CORRECTLY BY SEPARATING POLYGONS FROM RADIUS STRIP PLACEMENTS
        if (geometryType == 'Polygon') {
          List<LatLng> points = [];
          var coordinatesList = geometry['coordinates'][0] as List<dynamic>;
          
          for (var coord in coordinatesList) {
            points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
          }

          zones.add(DangerZone(
            id: '${name.replaceAll(' ', '_').toLowerCase()}_${zones.length}',
            areaName: name,
            coordinates: points,
            riskLevel: level,
          ));
          
        } else if (geometryType == 'MultiPolygon') {
          var multiCoordinatesList = geometry['coordinates'] as List<dynamic>;
          
          int subIndex = 0;
          for (var polygonCoords in multiCoordinatesList) {
            List<LatLng> points = [];
            var outerRing = polygonCoords[0] as List<dynamic>;
            
            for (var coord in outerRing) {
              points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }

            zones.add(DangerZone(
              id: '${name.replaceAll(' ', '_').toLowerCase()}_mp_${subIndex}_${zones.length}',
              areaName: name,
              coordinates: points,
              riskLevel: level,
            ));
            subIndex++;
          }

        // 3. CAPTURE INDIVIDUAL PINS AND GENERATE AN APPROXIMATE RADIUS SHAPE AROUND THEM
        } else if (geometryType == 'Point') {
          var coord = geometry['coordinates'] as List<dynamic>;
          final double lat = coord[1].toDouble();
          final double lon = coord[0].toDouble();

          // Create a small bounding box polygon around the lone pin point so it renders visually as a zone
          double offset = 0.003; // Roughly 300 meters wide boundary space
          List<LatLng> boundingPoints = [
            LatLng(lat + offset, lon - offset),
            LatLng(lat + offset, lon + offset),
            LatLng(lat - offset, lon + offset),
            LatLng(lat - offset, lon - offset),
            LatLng(lat + offset, lon - offset),
          ];

          zones.add(DangerZone(
            id: '${name.replaceAll(' ', '_').toLowerCase()}_point_${zones.length}',
            areaName: name,
            coordinates: boundingPoints,
            riskLevel: level,
          ));
        }
      }
    } catch (e) {
      print('Failed parsing map asset details: $e');
    }
    return zones;
  }
}