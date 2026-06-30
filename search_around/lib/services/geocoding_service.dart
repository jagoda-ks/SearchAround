import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  Future<LatLng?> getCoordinatesFromEircode(String input) async {
    String cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // Check if the input looks exactly like a raw 7-character Eircode with no spaces (e.g. D24A1B2)
    // If it is, slice it to the first 3 characters so OSM doesn't get confused by the hidden doorstep string
    String queryTerm = cleanInput.toUpperCase().replaceAll(' ', '');
    if (queryTerm.length == 7 && _isAlphanumeric(queryTerm)) {
      queryTerm = queryTerm.substring(0, 3);
    } else {
      // If they typed spaces or a full address (e.g. "Main St, Tallaght"), use the original input text
      queryTerm = cleanInput;
    }

    try {
      // We append ", Dublin, Ireland" to firmly restrict free search boundaries
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(queryTerm)}, Dublin, Ireland&'
        'format=json&'
        'limit=1'
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'DublinDangerZonesApp/1.0 (com.example.search_around)'
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print('Geocoding exception: $e');
    }
    return null;
  }

  // Simple helper to check if a string matches a compact Eircode shape style
  bool _isAlphanumeric(String str) {
    final regex = RegExp(r'^[A-Z0-9]+$');
    return regex.hasMatch(str);
  }
}