import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  late GoogleMapController _mapController;
  final GeocodingService _geocodingService = GeocodingService();
  final MapAssetService _mapAssetService = MapAssetService();

  String? _mapStyle;
  final LatLng _dublinCenter = const LatLng(53.3498, -6.2603);
  
  Set<Polygon> _mapPolygons = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  Future<void> _setupMapData() async {
    // 1. Load customization theme styles
    String style = await _mapAssetService.loadMapStyle();
    
    // 2. Fetch polygons translated from 'Dublin Areas de Risco' map data
    List<DangerZone> loadedZones = await _mapAssetService.loadDangerZonesFromAsset();
    
    if (mounted) {
      setState(() {
        _mapStyle = style.isNotEmpty ? style : null;
        _mapPolygons = loadedZones.map((zone) => zone.toPolygon()).toSet();
      });
    }
  }

  Future<void> _handleEircodeSearch(String eircode) async {
    // Basic formatting clean-up to ensure seamless cross-referencing
    final formattedEircode = eircode.trim().toUpperCase();
    
    LatLng? location = await _geocodingService.getCoordinatesFromEircode(formattedEircode);

    if (location != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('eircode_target'),
            position: location,
            infoWindow: InfoWindow(title: 'Location Match', snippet: formattedEircode),
          )
        };
      });

      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 14.0),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Irish Eircode routing format.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _dublinCenter,
              zoom: 11.5,
            ),
            polygons: _mapPolygons,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_mapStyle != null) {
                _mapController.setMapStyle(_mapStyle);
              }
            },
          ),
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