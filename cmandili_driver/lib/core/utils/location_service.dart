import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Check and request location permissions
  static Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // Get current position
  static Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] GPS service is disabled');
      return null;
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('[LocationService] Location permission denied');
      return null;
    }

    // Try high-accuracy with a timeout. On Android, getCurrentPosition with
    // LocationAccuracy.high can block indefinitely — the timeout ensures we
    // fall back rather than hanging silently.
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
      debugPrint('[LocationService] Got position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition failed ($e), trying last known...');
    }

    // Fallback: last known position is instant and avoids a 0,0 write
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        debugPrint('[LocationService] Using last known: ${last.latitude}, ${last.longitude}');
        return last;
      }
    } catch (e) {
      debugPrint('[LocationService] getLastKnownPosition failed: $e');
    }

    debugPrint('[LocationService] ⚠️ Could not get any position');
    return null;
  }
  
  // Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }
  
  // Get coordinates from address
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Calculate distance between two points in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
