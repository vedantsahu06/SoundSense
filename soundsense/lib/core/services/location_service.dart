import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location Service for getting GPS coordinates
class LocationService {
  // Singleton
  static LocationService? _instance;
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }
  LocationService._();

  Position? _lastPosition;
  bool _isInitialized = false;

  /// Initialize location service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled');
        return false;
      }

      // Request permission
      final status = await Permission.location.request();
      if (status != PermissionStatus.granted) {
        print('⚠️ Location permission denied');
        return false;
      }

      _isInitialized = true;
      print('✅ Location service initialized');
      return true;
    } catch (e) {
      print('❌ Failed to initialize location service: $e');
      return false;
    }
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastPosition = position;
      print('📍 Location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Failed to get location: $e');
      return _lastPosition; // Return cached position if available
    }
  }

  /// Get location as formatted string
  Future<String> getLocationString() async {
    final position = await getCurrentPosition();
    if (position == null) {
      return 'Location unavailable';
    }

    // Return Google Maps link for easy access
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }

  /// Get location as readable address (approximate)
  Future<String> getReadableLocation() async {
    final position = await getCurrentPosition();
    if (position == null) {
      return 'Location unavailable';
    }

    // Return coordinates with Google Maps link
    return 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
           'Maps: https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }

  /// Check if location permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }

  /// Open location settings
  Future<void> openSettings() async {
    await Geolocator.openLocationSettings();
  }
}
