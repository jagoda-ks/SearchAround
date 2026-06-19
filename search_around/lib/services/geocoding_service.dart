import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  // Replace with actual HTTP API call in production
  Future<LatLng?> getCoordinatesFromEircode(String eircode) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate API latency
    
    // Normalized format mock check
    final cleanEircode = eircode.replaceAll(' ', '').toUpperCase();
    
    if (cleanEircode.startsWith('D02')) {
      return const LatLng(53.3498, -6.2603); // Example: Dublin Centre
    } else if (cleanEircode.startsWith('T12')) {
      return const LatLng(51.8985, -8.4756); // Example: Cork Centre
    }
    
    // Default fallback (Ireland center approx) if code isn't recognized in mock
    return const LatLng(53.4129, -8.2439); 
  }
}