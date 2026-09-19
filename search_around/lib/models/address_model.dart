class AddressModel {
  final String? rawInput;
  final String? addressLine1;
  final String? addressLine2;
  final String? district;
  final String? county;
  final String? eircode;
  final String country;
  final double latitude;
  final double longitude;

  AddressModel({
    this.rawInput,
    this.addressLine1,
    this.addressLine2,
    this.district,
    this.county,
    this.eircode,
    this.country = 'Ireland',
    required this.latitude,
    required this.longitude,
  });

  /// Formats raw input into standard 7-character Eircode format (XXX XXXX).
  static String? formatEircode(String? input) {
    if (input == null) return null;
    final cleaned = input.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (RegExp(r'^[A-Z]\d{2}[A-Z0-9]{4}$').hasMatch(cleaned)) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    }
    return null;
  }

  /// Parse a Nominatim JSON result into an AddressModel.
  factory AddressModel.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    final houseNumber = address['house_number']?.toString();
    final road = address['road']?.toString() ??
        address['pedestrian']?.toString() ??
        address['residential']?.toString();

    String? line1;
    if (houseNumber != null && road != null) {
      line1 = '$houseNumber $road';
    } else {
      line1 = road ??
          houseNumber ??
          address['amenity']?.toString() ??
          address['building']?.toString() ??
          json['name']?.toString();
    }

    final postcode = address['postcode']?.toString();
    final eircode = formatEircode(postcode);

    final district = address['city_district']?.toString() ??
        address['suburb']?.toString() ??
        address['neighbourhood']?.toString() ??
        address['city']?.toString() ??
        address['town']?.toString() ??
        address['village']?.toString();

    final county = address['county']?.toString() ??
        address['state_district']?.toString();

    return AddressModel(
      rawInput: json['display_name'] as String?,
      addressLine1: line1,
      addressLine2: address['suburb']?.toString() ??
          address['neighbourhood']?.toString(),
      district: district,
      county: county,
      eircode: eircode,
      country: 'Ireland',
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
    );
  }

  String get formattedAddress {
    final parts = [
      addressLine1,
      addressLine2,
      district,
      county,
      eircode,
      country,
    ].where((part) => part != null && part.isNotEmpty);

    return parts.join(', ');
  }
}
