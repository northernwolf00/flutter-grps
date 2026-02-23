# Flutter gRPC Location Tracker

A Flutter application that streams real-time GPS location data to a backend server using **gRPC client-streaming**.

## Features

- 📍 **Live GPS Tracking** — Tracks device location with high accuracy
- 📡 **gRPC Streaming** — Streams location data to the server via `UploadLocations` client-streaming RPC
- 🗺️ **Google Maps Tiles** — Interactive map powered by `flutter_map`
- 📊 **Debug Logging** — Logs every streamed coordinate in the debug console

## Architecture

```
┌──────────────┐        gRPC (stream)        ┌──────────────────┐
│  Flutter App  │ ──────────────────────────▶ │  pandadevteam.net │
│  (Geolocator) │   UploadLocations(stream)   │     :50051        │
└──────────────┘                              └──────────────────┘
```

## Proto Definition

```protobuf
service GeoService {
  rpc UploadLocations(stream Location) returns (UploadSummary);
}

message Location {
  string user_id = 1;
  double lat     = 2;
  double lng     = 3;
  int64  timestamp = 4;
}

message UploadSummary {
  int32 received = 1;
}
```

## Tech Stack

| Layer         | Technology                        |
| ------------- | --------------------------------- |
| UI / Map      | `flutter_map` + Google Maps tiles |
| Location      | `geolocator`                      |
| Networking    | `grpc` (client-streaming)         |
| Serialization | `protobuf`                        |
| Language      | Dart 3.6 / Flutter 3.27           |

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.27.0
- Dart SDK ≥ 3.6.0
- `protoc` compiler with `protoc_plugin` for Dart
- Android device or emulator with GPS

### Installation

```bash
# Clone the repo
git clone https://github.com/northernwolf00/flutter-grps.git
cd flutter-grps

# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

### Regenerate gRPC Code

If you modify `proto/geo.proto`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
protoc --dart_out=grpc:lib/generated/geo -Iproto proto/geo.proto
```

## Project Structure

```
flutter_grps/
├── proto/
│   └── geo.proto                  # gRPC service definition
├── lib/
│   ├── main.dart                  # App entry point, map UI, gRPC client
│   └── generated/geo/            # Auto-generated Dart gRPC code
│       ├── geo.pb.dart
│       ├── geo.pbgrpc.dart
│       ├── geo.pbenum.dart
│       └── geo.pbjson.dart
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml    # Location permissions
└── pubspec.yaml                   # Dependencies
```

## How It Works

1. **App starts** → Opens a gRPC client-streaming connection to the server
2. **GPS activates** → Requests location permissions and starts tracking
3. **Position changes** → Each new GPS coordinate (≥5m movement) is:
   - Displayed on the map as a blue "Me" marker
   - Streamed to the server via `UploadLocations`
   - Logged to the debug console
4. **App closes** → Stream closes, server responds with `UploadSummary`

## Console Output

```
I/flutter: Upload stream started to pandadevteam.net:50051
I/flutter: Streamed to server: User: 1, Lat: 37.90167, Lng: 58.39963
I/flutter: Streamed to server: User: 1, Lat: 37.90192, Lng: 58.39887
I/flutter: Streamed to server: User: 1, Lat: 37.90196, Lng: 58.39760
...
```

## Android Permissions

The following permissions are configured in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

## License

This project is for development and testing purposes.
