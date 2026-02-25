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
  StreamController<Location> _locationStreamController =
      StreamController<Location>();

  // Device location subscription
  StreamSubscription<Position>? _positionSubscription;

  final String _currentUserId = "1";

  // === UI Log state ===
  final List<_LogEntry> _logs = [];
  String _streamStatus = "⏳ Connecting...";
  bool _showLogs = true;

  void _addLog(String message, {_LogLevel level = _LogLevel.info}) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _logs.insert(0, _LogEntry(time: timeStr, message: message, level: level));
      // Keep max 50 logs
      if (_logs.length > 50) _logs.removeLast();
    });
    print("[$timeStr] ${level.name.toUpperCase()} $message");
  }

  @override
  void initState() {
    super.initState();
    _initGrpc();
    _initLocation();
  }

  int _retryCount = 0;
  static const int _maxRetries = 5;

  void _initGrpc() {
    _addLog("Connecting to pandadevteam.net:50051...");
    _channel = ClientChannel(
      'pandadevteam.net',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = GeoServiceClient(_channel);
    _startUploadStream();
  }

  void _startUploadStream() {
    // Create a fresh stream controller if the old one is closed
    if (_locationStreamController.isClosed) {
      _locationStreamController = StreamController<Location>();
    }

    _client.uploadLocations(_locationStreamController.stream).then(
      (summary) {
        setState(() =>
            _streamStatus = "✅ Completed (received: ${summary.received})");
        _addLog(
            "Stream completed. Server received: ${summary.received} locations.");
        _retryCount = 0;
      },
    ).catchError((error) {
      setState(() => _streamStatus = "❌ Error");
      _addLog("STREAM ERROR: $error", level: _LogLevel.error);
      _scheduleRetry();
    });
    setState(() => _streamStatus = "📡 Stream opened");
    _addLog("Upload stream started", level: _LogLevel.success);
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      _addLog("Max retries reached ($_maxRetries). Tap reconnect to try again.",
          level: _LogLevel.error);
      setState(() => _streamStatus = "🔴 Disconnected");
      return;
    }
    _retryCount++;
    final delay = Duration(seconds: 2 * _retryCount); // 2s, 4s, 6s, 8s, 10s
    _addLog(
        "Retrying in ${delay.inSeconds}s (attempt $_retryCount/$_maxRetries)...",
        level: _LogLevel.info);
    setState(() => _streamStatus = "🔄 Reconnecting in ${delay.inSeconds}s...");
    Future.delayed(delay, () {
      if (mounted) {
        _addLog("Reconnecting...");
        _startUploadStream();
      }
    });
  }

  void _reconnect() {
    _retryCount = 0;
    _channel.shutdown().then((_) {
      if (mounted) {
        _initGrpc();
      }
    });
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _addLog('Location services are disabled!', level: _LogLevel.error);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _addLog('Location permissions denied!', level: _LogLevel.error);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _addLog('Location permissions permanently denied!',
          level: _LogLevel.error);
      return;
    }

    _addLog('Location permission granted', level: _LogLevel.success);

    // Get initial position
    final position = await Geolocator.getCurrentPosition();
    _addLog(
        'Initial position: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
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
    _addLog('Location stream started (distanceFilter: 5m)',
        level: _LogLevel.success);
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
      _addLog(
          "→ Sent: Lat=${location.lat.toStringAsFixed(5)}, Lng=${location.lng.toStringAsFixed(5)}",
          level: _LogLevel.sent);
    } else {
      _addLog("Stream closed! Cannot send location.", level: _LogLevel.error);
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
          // Reconnect button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reconnect gRPC',
            onPressed: _reconnect,
          ),
          // Toggle log panel
          IconButton(
            icon: Icon(_showLogs ? Icons.visibility_off : Icons.visibility),
            tooltip: _showLogs ? 'Hide logs' : 'Show logs',
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),
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
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(37.9601, 58.3263),
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
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

          // Log panel overlay
          if (_showLogs)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Column(
                  children: [
                    // Status bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal,
                              color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 8),
                          const Text('gRPC Log',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _streamStatus,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ),
                          const Spacer(),
                          // Clear logs
                          GestureDetector(
                            onTap: () => setState(() => _logs.clear()),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white38, size: 18),
                          ),
                        ],
                      ),
                    ),
                    // Log list
                    Expanded(
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text('No logs yet...',
                                  style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 1),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${log.time} ',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontFamily: 'monospace'),
                                      ),
                                      Text(
                                        log.level.icon,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          log.message,
                                          style: TextStyle(
                                              color: log.level.color,
                                              fontSize: 11,
                                              fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// === Log helpers ===
enum _LogLevel { info, success, error, sent }

extension _LogLevelExt on _LogLevel {
  Color get color {
    switch (this) {
      case _LogLevel.info:
        return Colors.white70;
      case _LogLevel.success:
        return Colors.greenAccent;
      case _LogLevel.error:
        return Colors.redAccent;
      case _LogLevel.sent:
        return Colors.cyanAccent;
    }
  }

  String get icon {
    switch (this) {
      case _LogLevel.info:
        return 'ℹ️';
      case _LogLevel.success:
        return '✅';
      case _LogLevel.error:
        return '❌';
      case _LogLevel.sent:
        return '📤';
    }
  }
}

class _LogEntry {
  final String time;
  final String message;
  final _LogLevel level;

  _LogEntry({required this.time, required this.message, required this.level});
}
