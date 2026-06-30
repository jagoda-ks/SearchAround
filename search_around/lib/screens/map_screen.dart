import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';
import '../services/map_asset_service.dart';
import '../models/danger_zones.dart';
import 'widgets/address_input.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final GeocodingService _geocodingService = GeocodingService();
  final MapAssetService _mapAssetService = MapAssetService();

  final LatLng _dublinCenter = const LatLng(53.3498, -6.2603);
  List<Polygon> _mapPolygons = [];
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _loadDangerZones();
  }

  Future<void> _loadDangerZones() async {
    List<DangerZone> loadedZones = await _mapAssetService.loadDangerZonesFromAsset();
    if (mounted) {
      setState(() {
        _mapPolygons = loadedZones.map((zone) => zone.toPolygon()).toList();
      });
    }
  }

  Future<void> _handleEircodeSearch(String eircode) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checking registry for: $eircode...')),
    );

    LatLng? location = await _geocodingService.getCoordinatesFromEircode(eircode);

    if (location != null) {
      setState(() {
        _markers = [
          Marker(
            point: location,
            width: 45,
            height: 45,
            child: const Icon(
              Icons.location_on,
              color: Colors.blueAccent,
              size: 45,
            ),
          )
        ];
      });

      // Animates camera center onto searched target address smoothly
      _mapController.move(location, 14.5);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eircode location not found in Ireland entries.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _dublinCenter,
              initialZoom: 11.5,
            ),
            children: [
              // FREE LAYER 1: OpenStreetMap Base Imagery
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.search_around',
              ),
              // FREE LAYER 2: Danger Zone Polygons loaded from your GeoJSON asset file
              PolygonLayer(
                polygons: _mapPolygons,
              ),
              // FREE LAYER 3: Interactive Location Search Pin drops
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          // User input layer box layout floating over map context
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AddressInput(onSearch: _handleEircodeSearch),
            ),
          ),
        ],
      ),
    );
  }
}