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
      return null;
    }
    
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      return null;
    }
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
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
