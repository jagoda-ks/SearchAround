import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/address_model.dart';

class GeocodingService {
  static const _userAgent =
      'SearchAround/1.0 (com.example.search_around; student project)';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/search';

  /// Irish Eircode: routing key (A12) + unique identifier (AB12)
  static final _eircodePattern = RegExp(
    r'^[A-Z]\d{2}\s?[A-Z0-9]{4}$',
    caseSensitive: false,
  );

  Future<AddressModel?> searchAddress(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    if (_isEircode(cleanInput)) {
      final formatted = AddressModel.formatEircode(cleanInput)!;
      return await _searchEircode(formatted);
    }

    return await _searchStreetAddress(cleanInput);
  }

  bool _isEircode(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), '');
    return _eircodePattern.hasMatch(compact);
  }

  /// Look up a full Eircode. OSM coverage is best-effort; we only accept
  /// results whose postcode actually matches what the user typed.
  Future<AddressModel?> _searchEircode(String eircode) async {
    final compact = eircode.replaceAll(' ', '').toUpperCase();

    try {
      // 1. Structured postalcode search (most precise when OSM has the code)
      final structured = await _nominatimSearch({
        'postalcode': eircode,
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });
      final fromStructured = _firstMatchingEircode(structured, compact);
      if (fromStructured != null) return fromStructured;

      // 2. Free-form query restricted to Ireland
      final freeform = await _nominatimSearch({
        'q': '$eircode, Ireland',
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });
      final fromFreeform = _firstMatchingEircode(freeform, compact);
      if (fromFreeform != null) return fromFreeform;

      // 3. Photon fallback (often indexes Irish postcodes well)
      final fromPhoton = await _searchEircodeWithPhoton(eircode, compact);
      if (fromPhoton != null) return fromPhoton;

      // 4. Approximate: zoom to the routing-key area (e.g. D02) if known
      final routingKey = eircode.substring(0, 3).toUpperCase();
      final areaQueries = <Map<String, String>>[
        {
          'q': '$routingKey, Ireland',
          'countrycodes': 'ie',
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
        },
      ];

      // Dublin routing keys often map to "Dublin 2", "Dublin 14", etc.
      final dublinDistrict = _dublinDistrictFromRoutingKey(routingKey);
      if (dublinDistrict != null) {
        areaQueries.insert(0, {
          'q': dublinDistrict,
          'countrycodes': 'ie',
          'format': 'json',
          'addressdetails': '1',
          'limit': '3',
        });
      }

      for (final params in areaQueries) {
        final area = await _nominatimSearch(params);
        if (area.isEmpty) continue;

        final model = AddressModel.fromNominatim(area.first);
        return AddressModel(
          rawInput:
              'Approximate area for $eircode (exact code not in map data)',
          addressLine1: model.addressLine1 ?? 'Area $routingKey',
          addressLine2: model.addressLine2,
          district: model.district ?? dublinDistrict,
          county: model.county,
          eircode: eircode,
          country: model.country,
          latitude: model.latitude,
          longitude: model.longitude,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Eircode search exception: $e');
    }
    return null;
  }

  /// Map Dublin Eircode routing keys (D01–D24, D6W) to "Dublin N" labels.
  String? _dublinDistrictFromRoutingKey(String routingKey) {
    final key = routingKey.toUpperCase();
    if (key == 'D6W') return 'Dublin 6W';
    final match = RegExp(r'^D(\d{2})$').firstMatch(key);
    if (match == null) return null;
    final num = int.parse(match.group(1)!);
    if (num < 1 || num > 24) return null;
    return 'Dublin $num';
  }

  Future<AddressModel?> _searchEircodeWithPhoton(
    String eircode,
    String compact,
  ) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': eircode,
      'limit': '5',
      'lang': 'en',
      // Ireland bounding box: minLon, minLat, maxLon, maxLat
      'bbox': '-10.7,51.3,-5.3,55.5',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      final map = feature as Map<String, dynamic>;
      final props = map['properties'] as Map<String, dynamic>? ?? {};
      final coords = (map['geometry'] as Map<String, dynamic>?)?['coordinates']
          as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;

      final name = (props['name'] ?? props['postcode'] ?? '').toString();
      final nameCompact = name.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final country = (props['countrycode'] ?? '').toString().toUpperCase();
      if (country.isNotEmpty && country != 'IE') continue;
      if (nameCompact != compact && !nameCompact.contains(compact)) continue;

      return AddressModel(
        rawInput: name.isNotEmpty ? name : eircode,
        addressLine1: props['street']?.toString() ?? props['name']?.toString(),
        addressLine2: props['district']?.toString() ?? props['city']?.toString(),
        district: props['county']?.toString() ?? props['district']?.toString(),
        county: props['state']?.toString() ?? props['county']?.toString(),
        eircode: eircode,
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
    }
    return null;
  }

  /// Free-text Irish street / town / district search (whole island).
  Future<AddressModel?> _searchStreetAddress(String street) async {
    try {
      var query = street.trim();
      final lower = query.toLowerCase();
      if (!lower.contains('ireland') && !lower.contains('éire')) {
        query = '$query, Ireland';
      }

      final results = await _nominatimSearch({
        'q': query,
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });

      if (results.isNotEmpty) {
        return AddressModel.fromNominatim(results.first);
      }

      // Photon fallback for Irish places
      final photonUri = Uri.https('photon.komoot.io', '/api/', {
        'q': street,
        'limit': '5',
        'lang': 'en',
        'bbox': '-10.7,51.3,-5.3,55.5',
      });
      final photonResponse = await http.get(photonUri);
      if (photonResponse.statusCode == 200) {
        final data = json.decode(photonResponse.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        for (final feature in features) {
          final map = feature as Map<String, dynamic>;
          final props = map['properties'] as Map<String, dynamic>? ?? {};
          final country = (props['countrycode'] ?? '').toString().toUpperCase();
          if (country.isNotEmpty && country != 'IE') continue;

          final coords =
              (map['geometry'] as Map<String, dynamic>?)?['coordinates']
                  as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;

          final postcode = props['postcode']?.toString();
          return AddressModel(
            rawInput: props['name']?.toString() ?? street,
            addressLine1: [
              props['housenumber'],
              props['street'] ?? props['name'],
            ].where((p) => p != null && p.toString().isNotEmpty).join(' '),
            addressLine2:
                props['district']?.toString() ?? props['city']?.toString(),
            district: props['city']?.toString() ?? props['county']?.toString(),
            county: props['state']?.toString() ?? props['county']?.toString(),
            eircode: AddressModel.formatEircode(postcode),
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Street search exception: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _nominatimSearch(
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(_nominatimBase).replace(queryParameters: params);
    final response = await http.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept-Language': 'en',
    });

    if (response.statusCode != 200) return [];

    final decoded = json.decode(response.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  AddressModel? _firstMatchingEircode(
    List<Map<String, dynamic>> results,
    String compactTarget,
  ) {
    for (final item in results) {
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final postcode = (address['postcode'] ?? item['display_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();

      final display = (item['display_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();

      final matches = postcode == compactTarget ||
          display.startsWith(compactTarget) ||
          display.contains(compactTarget);

      if (!matches) continue;

      final model = AddressModel.fromNominatim(item);
      return AddressModel(
        rawInput: model.rawInput,
        addressLine1: model.addressLine1,
        addressLine2: model.addressLine2,
        district: model.district,
        county: model.county,
        eircode: AddressModel.formatEircode(compactTarget),
        country: model.country,
        latitude: model.latitude,
        longitude: model.longitude,
      );
    }
    return null;
  }
}
