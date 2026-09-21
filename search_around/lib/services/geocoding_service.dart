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

  static final _fillerWords = RegExp(
    r'\b(on|at|near|in|the|around|beside|by|of|to)\b',
    caseSensitive: false,
  );

  static final _streetType = RegExp(
    r'\b(road|street|avenue|lane|drive|close|crescent|place|quay|terrace|park|grove|way|hill|square|row|court|gardens?)\b',
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
      final structured = await _nominatimSearch({
        'postalcode': eircode,
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });
      final fromStructured = _firstMatchingEircode(structured, compact);
      if (fromStructured != null) return fromStructured;

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final freeform = await _nominatimSearch({
        'q': '$eircode, Ireland',
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });
      final fromFreeform = _firstMatchingEircode(freeform, compact);
      if (fromFreeform != null) return fromFreeform;

      final fromPhoton = await _searchEircodeWithPhoton(eircode, compact);
      if (fromPhoton != null) return fromPhoton;

      final routingKey = eircode.substring(0, 3).toUpperCase();
      final areaQueries = <Map<String, String>>[];

      final dublinDistrict = _dublinDistrictFromRoutingKey(routingKey);
      if (dublinDistrict != null) {
        areaQueries.add({
          'q': dublinDistrict,
          'countrycodes': 'ie',
          'format': 'json',
          'addressdetails': '1',
          'limit': '3',
        });
      }
      areaQueries.add({
        'q': '$routingKey, Ireland',
        'countrycodes': 'ie',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      });

      for (final params in areaQueries) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
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
        addressLine2:
            props['district']?.toString() ?? props['city']?.toString(),
        district: props['county']?.toString() ?? props['district']?.toString(),
        county: props['state']?.toString() ?? props['county']?.toString(),
        eircode: eircode,
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
    }
    return null;
  }

  /// Free-text Irish street / place search with query cleanup + ranking.
  Future<AddressModel?> _searchStreetAddress(String street) async {
    try {
      final variants = _buildAddressQueryVariants(street);
      AddressModel? best;
      var bestScore = -1.0;

      for (var i = 0; i < variants.length; i++) {
        if (i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }

        final results = await _nominatimSearch({
          'q': variants[i],
          'countrycodes': 'ie',
          'format': 'json',
          'addressdetails': '1',
          'limit': '8',
        });

        for (final item in results) {
          final score = _scoreAddressResult(street, item);
          if (score > bestScore) {
            bestScore = score;
            best = AddressModel.fromNominatim(item);
          }
        }

        // Strong named-place match — stop early.
        if (bestScore >= 8) break;
      }

      if (best != null && bestScore >= 2) return best;

      // Photon fallback with cleaned variants
      for (final variant in variants.take(3)) {
        final photon = await _searchStreetWithPhoton(street, variant);
        if (photon != null) return photon;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Street search exception: $e');
    }
    return null;
  }

  /// Build several Nominatim-friendly phrasings from casual Irish input.
  ///
  /// Example: "Some Halls on Example Road 6"
  /// → "Some Hall, Example Road, Dublin 6, Ireland"
  /// → "Some Hall, Dublin 6, Ireland"
  /// → "Some Hall, Dublin, Ireland"
  List<String> _buildAddressQueryVariants(String input) {
    final variants = <String>[];
    final seen = <String>{};

    void add(String value) {
      var q = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      q = q.replaceAll(RegExp(r'\s*,\s*'), ', ');
      q = q.replaceAll(RegExp(r',+'), ',');
      q = q.replaceAll(RegExp(r'^,\s*'), '').replaceAll(RegExp(r',\s*$'), '');
      if (q.isEmpty) return;
      final lower = q.toLowerCase();
      if (!lower.contains('ireland') && !lower.contains('éire')) {
        q = '$q, Ireland';
      }
      final key = q.toLowerCase();
      if (seen.add(key)) variants.add(q);
    }

    final normalized = _normalizeAddressInput(input);
    final district = _extractDublinDistrict(input) ??
        _extractDublinDistrict(normalized);
    final streetName = _extractStreetName(normalized);
    final placeName = _extractPlaceName(normalized, streetName);

    // Prefer precise place + district first (e.g. "Place Name, Dublin 6").
    if (placeName != null && district != null) {
      add('$placeName, $district');
    }
    if (placeName != null && streetName != null) {
      add('$placeName, $streetName${district != null ? ', $district' : ''}');
    }
    if (placeName != null) {
      add('$placeName, Dublin');
      add(placeName);
    }

    add(normalized);

    if (streetName != null && district != null) {
      add('$streetName, $district');
    } else if (streetName != null) {
      add('$streetName, Dublin');
    }

    // Keep original (lightly cleaned) as a last resort.
    add(input.replaceAll(_fillerWords, ' '));

    return variants;
  }

  String _normalizeAddressInput(String input) {
    var q = input.trim();

    // Common spoken/plural forms that break OSM lookups.
    q = q.replaceAll(RegExp(r'\bHalls\b', caseSensitive: false), 'Hall');
    q = q.replaceAll(
      RegExp(r'\bApartments\b', caseSensitive: false),
      'Apartment',
    );
    q = q.replaceAll(RegExp(r'\bHouses\b', caseSensitive: false), 'House');

    // "Dublin6" / "D6" / bare trailing postal district → "Dublin 6"
    q = q.replaceAllMapped(
      RegExp(r'\b[Dd]ublin\s*(\d{1,2}W?)\b'),
      (m) => 'Dublin ${m[1]!.toUpperCase() == '6W' ? '6W' : m[1]}',
    );
    q = q.replaceAllMapped(
      RegExp(r'\bD\s*(\d{1,2}W?)\b', caseSensitive: false),
      (m) {
        final n = m[1]!;
        if (n.toUpperCase() == '6W') return 'Dublin 6W';
        final num = int.tryParse(n);
        if (num != null && num >= 1 && num <= 24) return 'Dublin $num';
        return m[0]!;
      },
    );
    q = q.replaceAllMapped(
      RegExp(
        r'(?:^|[\s,])(\d{1,2}|6W)\s*$',
        caseSensitive: false,
      ),
      (m) {
        final raw = m[1]!;
        if (raw.toUpperCase() == '6W') return ', Dublin 6W';
        final num = int.tryParse(raw);
        if (num != null && num >= 1 && num <= 24) return ', Dublin $num';
        return m[0]!;
      },
    );

    q = q.replaceAll(_fillerWords, ' ');
    q = q.replaceAll(RegExp(r'\s+'), ' ').trim();
    q = q.replaceAll(RegExp(r'\s*,\s*'), ', ');
    return q;
  }

  String? _extractDublinDistrict(String input) {
    final dublin = RegExp(
      r'\bDublin\s*(\d{1,2}W?)\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (dublin != null) {
      final n = dublin.group(1)!;
      return n.toUpperCase() == '6W' ? 'Dublin 6W' : 'Dublin $n';
    }

    final trailing = RegExp(
      r'(?:^|[\s,])(\d{1,2}|6W)\s*$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (trailing != null) {
      final raw = trailing.group(1)!;
      if (raw.toUpperCase() == '6W') return 'Dublin 6W';
      final num = int.tryParse(raw);
      if (num != null && num >= 1 && num <= 24) return 'Dublin $num';
    }
    return null;
  }

  String? _extractPlaceName(String normalized, String? streetName) {
    var head = normalized;
    if (streetName != null) {
      final idx = head.toLowerCase().indexOf(streetName.toLowerCase());
      if (idx >= 0) {
        head = head.substring(0, idx);
      }
    } else {
      head = head
          .replaceAll(
            RegExp(r',?\s*Dublin\s*\d{0,2}W?\b', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r',?\s*Ireland\b', caseSensitive: false), '')
          .replaceAll(RegExp(r',?\s*Éire\b', caseSensitive: false), '');
    }

    head = head
        .replaceAll(RegExp(r',?\s*Dublin\s*\d{0,2}W?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^,+|,+$'), '')
        .trim();
    if (head.isEmpty) return null;
    if (_streetType.hasMatch(head)) return null;
    return head;
  }

  String? _extractStreetName(String normalized) {
    // Take the street clause nearest the end (before district), e.g. "Example Road"
    // from "Place Name Example Road, Dublin 6".
    final matches = RegExp(
      r'((?:[A-Za-z0-9\-]+\s+){0,3}'
      r'(?:road|street|avenue|lane|drive|close|crescent|place|quay|terrace|'
      r'park|grove|way|hill|square|row|court|gardens?))'
      r'(?=\s*,|\s*Dublin\b|\s*Ireland\b|\s*$)',
      caseSensitive: false,
    ).allMatches(normalized);
    if (matches.isEmpty) return null;
    return matches.last.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _scoreAddressResult(String original, Map<String, dynamic> item) {
    final display =
        (item['display_name'] ?? '').toString().toLowerCase();
    final name = (item['name'] ?? '').toString().toLowerCase();
    final address = item['address'] as Map<String, dynamic>? ?? {};
    final road = (address['road'] ?? '').toString().toLowerCase();
    final suburb = (address['suburb'] ?? '').toString().toLowerCase();
    final clazz = (item['class'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final importance = (item['importance'] as num?)?.toDouble() ?? 0;

    final tokens = _significantTokens(original);
    var score = importance * 2;

    for (final token in tokens) {
      if (name == token || name.contains(token)) score += 4;
      if (road.contains(token)) score += 2;
      if (suburb.contains(token)) score += 2;
      if (display.contains(token)) score += 1;
    }

    // Multi-word place names: reward full phrase hits.
    final normalized = _normalizeAddressInput(original);
    final streetName = _extractStreetName(normalized);
    final place = _extractPlaceName(normalized, streetName);
    if (place != null) {
      final placeLower = place.toLowerCase();
      if (name.contains(placeLower) || display.contains(placeLower)) {
        score += 5;
      }
    }
    if (streetName != null && road.contains(streetName.toLowerCase())) {
      score += 2;
    }

    final district = _extractDublinDistrict(original);
    if (district != null && display.contains(district.toLowerCase())) {
      score += 2;
    }

    // Prefer named buildings / campuses over arbitrary highway midpoints
    // when the user typed a place + street.
    if (tokens.length >= 2 && clazz == 'highway' && name.isEmpty) {
      score -= 3;
    }
    if ({
      'residential',
      'apartments',
      'dormitory',
      'university',
      'college',
      'school',
      'building',
      'house',
      'yes',
    }.contains(type)) {
      score += 2;
    }
    if ({'amenity', 'building', 'landuse', 'tourism'}.contains(clazz)) {
      score += 1.5;
    }

    return score;
  }

  List<String> _significantTokens(String input) {
    final cleaned = _normalizeAddressInput(input)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final stop = {
      'ireland',
      'eire',
      'dublin',
      'county',
      'co',
      'road',
      'street',
      'avenue',
      'lane',
      'drive',
      'and',
    };
    return cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !stop.contains(t))
        .where((t) => int.tryParse(t) == null) // drop bare district numbers
        .toList();
  }

  Future<AddressModel?> _searchStreetWithPhoton(
    String original,
    String query,
  ) async {
    final photonUri = Uri.https('photon.komoot.io', '/api/', {
      'q': query.replaceAll(RegExp(r',?\s*Ireland$', caseSensitive: false), ''),
      'limit': '8',
      'lang': 'en',
      'bbox': '-10.7,51.3,-5.3,55.5',
    });
    final photonResponse = await http.get(photonUri);
    if (photonResponse.statusCode != 200) return null;

    final data = json.decode(photonResponse.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];

    AddressModel? best;
    var bestScore = -1.0;

    for (final feature in features) {
      final map = feature as Map<String, dynamic>;
      final props = map['properties'] as Map<String, dynamic>? ?? {};
      final country = (props['countrycode'] ?? '').toString().toUpperCase();
      if (country.isNotEmpty && country != 'IE') continue;

      final coords = (map['geometry'] as Map<String, dynamic>?)?['coordinates']
          as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;

      final name = (props['name'] ?? '').toString();
      final street = (props['street'] ?? '').toString();
      final synthetic = <String, dynamic>{
        'name': name,
        'display_name': [
          name,
          street,
          props['district'],
          props['city'],
          props['county'],
          'Ireland',
        ].where((p) => p != null && p.toString().isNotEmpty).join(', '),
        'class': props['osm_key'],
        'type': props['osm_value'],
        'importance': 0.2,
        'address': {
          'road': street,
          'suburb': props['district'],
          'city': props['city'],
          'county': props['county'] ?? props['state'],
          'postcode': props['postcode'],
        },
        'lat': coords[1].toString(),
        'lon': coords[0].toString(),
      };

      final score = _scoreAddressResult(original, synthetic);
      if (score > bestScore) {
        bestScore = score;
        final postcode = props['postcode']?.toString();
        best = AddressModel(
          rawInput: name.isNotEmpty ? name : original,
          addressLine1: [
            props['housenumber'],
            street.isNotEmpty ? street : name,
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

    if (best != null && bestScore >= 2) return best;
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
