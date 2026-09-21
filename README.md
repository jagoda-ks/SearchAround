# SearchAround

A Flutter map app that helps students looking for accommodation in Dublin quickly check **where a listing is** and **how that area relates to mapped safety guidance**.

Finding somewhere to live in Ireland is stressful, especially during the ongoing housing shortage. SearchAround is meant to cut down that back-and-forth: paste an address or Eircode, see it on the map, and judge the surroundings at a glance instead of opening endless tabs.

The on-screen title is **Eircode Danger Map**. Today the focus is Dublin; the longer-term plan is to cover more of Ireland and add richer local context (nearby facilities, distance to campuses and other everyday places, and similar checks).

## What it does today

- Search by **Eircode** or an **Irish street / place address**, then drop a pin on the map
- Show **danger-zone overlays** in three levels:
  - **Yellow** — lower concern
  - **Red** — higher concern
  - **Black** — highest concern
- Use the default [flutter_map](https://pub.dev/packages/flutter_map) stack with OpenStreetMap tiles

Zone shapes come from publicly shared “areas to avoid” style guidance for Dublin ([The Irish Road Trip](https://www.theirishroadtrip.com/dublin-areas-to-avoid/)), converted into `search_around/assets/danger_regions.json` for the app.

## Why it exists

Students often juggle many listings, maps, and safety articles while also worrying about commute to college. SearchAround aims to be a small guidance tool: not a substitute for local knowledge or official advice, but a faster way to orient yourself when comparing places.

## Getting started

```bash
cd search_around
flutter pub get
flutter run -d chrome
```

Other targets:

```bash
flutter devices
flutter run -d windows   # or macos / linux / an emulator id
```

Requires Flutter 3.5+ (Dart SDK `>=3.5.0 <4.0.0`).

## How search works

1. Enter a valid Irish address or Eircode in the search box
2. The app geocodes the query and places a pointer on the map
3. Danger zones stay visible underneath so you can compare pin location against the coloured areas

Geocoding uses free public APIs:

1. **Nominatim** (OpenStreetMap), limited to Ireland (`countrycodes=ie`)
2. **Photon** as a fallback when Nominatim misses

Notes:

- There is **no free official Eircode API**. Exact Eircode pins only work when that code exists in OpenStreetMap; otherwise the app may fall back to a nearby district.
- Casual phrasing is normalised before lookup (for example plural place names, or a trailing `8` treated as Dublin 8).
- Please respect Nominatim’s [usage policy](https://operations.osmfoundation.org/policies/nominatim/) (including about one request per second).

### Example searches

| Query | Expected behaviour |
| --- | --- |
| `D02 EW93` | Pin near Grafton Street / Dublin 2 (if mapped in OSM) |
| `Grafton Street, Dublin` | Street-level pin in Dublin |
| `Guinness Storehouse, Dublin 8` | Pin on the Storehouse area in Dublin 8 |
| `Shop Street, Galway` | Galway result (not forced to Dublin) |

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

## Stack

| Piece | Choice |
| --- | --- |
| UI | Flutter / Material 3 |
| Map | `flutter_map` + OSM tiles |
| Coordinates | `latlong2` |
| HTTP | `http` |
| Geocoders | Nominatim + Photon |
| Zone data | Local JSON derived from [The Irish Road Trip](https://www.theirishroadtrip.com/dublin-areas-to-avoid/) |

## Roadmap

Ideas for later iterations:

- Expand coverage beyond Dublin
- Distance checks to universities and other destinations
- Filters for nearby facilities and amenities
- Clearer on-map legend and guidance copy for the zone colours

## Development tips

```bash
cd search_around
flutter analyze
flutter test
```

Hot restart in a running session with `R` in the Flutter terminal.

Edit `search_around/assets/danger_regions.json` to change zones, then restart/hot-restart the app.

## Disclaimer

Danger-zone data and map pins are for **guidance and educational** use. They depend on third-party area summaries and OpenStreetMap coverage, and may be incomplete or out of date. This is not an official safety, policing, or addressing service—always cross-check listings and local advice yourself.
