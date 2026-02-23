import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:grpc/grpc.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:geolocator/geolocator.dart';
import 'generated/geo/geo.pbgrpc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-time Location Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Map<String, Location> _userLocations = {};

  // gRPC Client
  late GeoServiceClient _client;
  late ClientChannel _channel;

  // Stream controller for client-streaming to server
  final StreamController<Location> _locationStreamController =
      StreamController<Location>();

  // Device location subscription
  StreamSubscription<Position>? _positionSubscription;

  final String _currentUserId = "1";

  @override
  void initState() {
    super.initState();
    _initGrpc();
    _initLocation();
  }

  void _initGrpc() {
    _channel = ClientChannel(
      'pandadevteam.net',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _client = GeoServiceClient(_channel);
    _startUploadStream();
  }

  void _startUploadStream() {
    _client.uploadLocations(_locationStreamController.stream).then(
      (summary) {
        debugPrint(
            "Upload stream completed. Server received: ${summary.received} locations.");
      },
    ).catchError((error) {
      debugPrint("Upload stream error: $error");
    });
    debugPrint("Upload stream started to pandadevteam.net:50051");
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return;
    }

    // Get initial position
    final position = await Geolocator.getCurrentPosition();
    _onLocationChanged(position);
    _mapController.move(LatLng(position.latitude, position.longitude), 15.0);

    // Listen to location changes
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _onLocationChanged(position);
    });
  }

  void _onLocationChanged(Position position) {
    final location = Location()
      ..userId = _currentUserId
      ..lat = position.latitude
      ..lng = position.longitude
      ..timestamp = $fixnum.Int64(DateTime.now().millisecondsSinceEpoch);

    _updateUserLocation(location);

    // Send to server via the open stream
    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(location);
      debugPrint(
          "Streamed to server: User: ${location.userId}, Lat: ${location.lat}, Lng: ${location.lng}");
    }
  }

  void _updateUserLocation(Location location) {
    setState(() {
      _userLocations[location.userId] = location;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _locationStreamController.close();
    _channel.shutdown();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Tracker'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_userLocations.containsKey(_currentUserId)) {
                final loc = _userLocations[_currentUserId]!;
                _mapController.move(LatLng(loc.lat, loc.lng), 15.0);
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(37.9601, 58.3263),
          initialZoom: 12.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.example.flutter_grps',
          ),
          MarkerLayer(
            markers: _userLocations.values.map((loc) {
              final isMe = loc.userId == _currentUserId;
              return Marker(
                point: LatLng(loc.lat, loc.lng),
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(blurRadius: 2, color: Colors.black26)
                        ],
                      ),
                      child: Text(
                        isMe ? "Me" : loc.userId,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : Colors.black),
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      color: isMe ? Colors.blue : Colors.red,
                      size: 30,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
