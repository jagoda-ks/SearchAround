import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/address_model.dart';
import '../models/danger_zones.dart';
import '../services/geocoding_service.dart';
import '../services/map_asset_service.dart';
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
    List<DangerZone> loadedZones =
        await _mapAssetService.loadDangerZonesFromAsset();
    if (mounted) {
      setState(() {
        _mapPolygons = loadedZones.map((zone) => zone.toPolygon()).toList();
      });
    }
  }

  Future<void> _handleAddressSearch(String query) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for: $query...')),
    );

    final AddressModel? result =
        await _geocodingService.searchAddress(query);

    if (!mounted) return;

    if (result != null) {
      final location = LatLng(result.latitude, result.longitude);
      final lookedLikeEircode = RegExp(
        r'^[A-Z]\d{2}\s?[A-Z0-9]{4}$',
        caseSensitive: false,
      ).hasMatch(query.replaceAll(RegExp(r'\s+'), ''));

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

      final targetZoom = lookedLikeEircode ? 16.5 : 14.5;
      _mapController.move(location, targetZoom);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found: ${result.formattedAddress}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Address or Eircode not found. Try a full street address, or an Eircode that appears on OpenStreetMap.',
          ),
        ),
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.search_around',
              ),
              PolygonLayer(
                polygons: _mapPolygons,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AddressInput(onSearch: _handleAddressSearch),
            ),
          ),
        ],
      ),
    );
  }
}
