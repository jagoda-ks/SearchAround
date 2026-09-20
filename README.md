# SearchAround

Flutter map app for exploring Dublin with **Eircode / Irish address search** and **danger-zone overlays**.

The UI title is **Eircode Danger Map**. You can search by Eircode (for example `D02 EW93`) or by a casual Irish address (for example `Trinity Halls on Dartry Road 6` or `Grafton Street, Dublin`), then drop a pin on the map.

## Features

- Interactive map centred on Dublin (OpenStreetMap tiles via [flutter_map](https://pub.dev/packages/flutter_map))
- Coloured danger-zone polygons loaded from local GeoJSON-style assets
- Address search that supports:
  - **Eircodes** (exact match when present in OpenStreetMap; otherwise approximate district fallback)
  - **Irish place / street queries**, including casual phrasing (`Halls` → `Hall`, trailing `6` → `Dublin 6`)
- Works Ireland-wide for street search (not Dublin-only)

## Project layout

```text
SearchAround/
└── search_around/          # Flutter application
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart
    │   ├── models/         # Address + danger zone models
    │   ├── screens/        # Map UI + address input
    │   └── services/       # Geocoding + asset loading
    ├── assets/
    │   ├── danger_regions.json
    │   └── map_style.json
    └── pubspec.yaml
```

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.5+ (Dart SDK `>=3.5.0 <4.0.0`)
- Chrome (for web), or a configured Android / iOS / desktop target

## Getting started

```bash
cd search_around
flutter pub get
flutter run -d chrome
```

Other useful targets:

```bash
flutter devices
flutter run -d windows   # or macos / linux / an emulator id
```

## How search works

Geocoding uses free public APIs:

1. **Nominatim** (OpenStreetMap) — primary lookup, restricted with `countrycodes=ie`
2. **Photon** — fallback when Nominatim misses

Notes:

- There is **no free official Eircode API**. Exact Eircode pins only work when that code exists in OpenStreetMap.
- Place names often need normalisation (for example OSM lists **Trinity Hall**, not “Trinity Halls”).
- Please respect Nominatim’s [usage policy](https://operations.osmfoundation.org/policies/nominatim/) (including ~1 request/second).

### Example searches

| Query | Expected behaviour |
| --- | --- |
| `D02 EW93` | Pin near Grafton Street / Dublin 2 (if mapped in OSM) |
| `Grafton Street, Dublin` | Street-level pin in Dublin |
| `Trinity Halls on Dartry Road 6` | Trinity Hall campus on Dartry Road (not a random nearby street) |
| `Shop Street, Galway` | Galway result (not forced to Dublin) |

## Danger zones

Polygons come from `search_around/assets/danger_regions.json` and are rendered with risk colours:

- **Yellow** — lower risk
- **Red** — higher risk
- **Black** — highest risk

Edit that asset to change or add regions; restart/hot-restart the app to reload.

## Stack

| Piece | Choice |
| --- | --- |
| UI | Flutter / Material 3 |
| Map | `flutter_map` + OSM tiles |
| Coordinates | `latlong2` |
| HTTP | `http` |
| Geocoders | Nominatim + Photon |

## Development tips

```bash
cd search_around
flutter analyze
flutter test
```

Hot restart in a running session with `R` in the Flutter terminal.

## Disclaimer

Danger-zone data and map pins are for **demo / educational** use. Locations depend on OpenStreetMap coverage and may be approximate. Do not treat this as an official safety or addressing service.
