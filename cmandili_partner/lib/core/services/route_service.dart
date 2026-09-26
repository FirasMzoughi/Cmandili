import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Re-exported so callers importing route_service.dart also get RouteFreshness.
// The freshness math lives in its own plugin-free file so it can be unit
// tested without dotenv/http being initialised.
export 'route_freshness.dart';

/// One driving route along real streets, as returned by the Google Directions
/// API and used to draw the line the driver is actually expected to follow.
@immutable
class AppRoute {
  /// Full street-following geometry. This is stitched from the per-step
  /// polylines rather than taken from `overview_polyline`, because the
  /// overview is simplified for display at low zoom: it cuts corners and
  /// visibly drifts off the roadway once the customer zooms in on the driver.
  final List<({double lat, double lng})> points;

  /// Total driving distance in meters.
  final int distanceMeters;

  /// Live-traffic driving time in seconds where Google provides it, falling
  /// back to the traffic-free estimate.
  final int durationSeconds;

  /// Human-readable road names along the route, in order, deduplicated —
  /// "Avenue Habib Bourguiba", "Rue de Marseille", ... This is what lets the
  /// customer see *which streets* the driver is taking, not just a line.
  final List<String> streetNames;

  /// The name of the road the driver is on for the next step, or null when
  /// the route has no named roads (rare, but possible on unnamed service
  /// roads).
  String? get currentStreet => streetNames.isEmpty ? null : streetNames.first;

  const AppRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.streetNames,
  });

  /// Formatted ETA, e.g. "12 min" or "1 h 05".
  String get etaLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h h ${m.toString().padLeft(2, '0')}';
  }

  /// Formatted remaining distance, e.g. "850 m" or "3,4 km".
  String get distanceLabel {
    if (distanceMeters < 1000) return '$distanceMeters m';
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

/// Fetches driving routes from the Google Directions API.
///
/// Shared by the client, driver and partner apps so all three draw the *same*
/// line for the same delivery — previously only the client fetched a route at
/// all, and it used the simplified overview geometry.
class RouteService {
  /// Returns the driving route from [origin] to [destination], or null if the
  /// request fails or no route exists. Never throws: a missing route degrades
  /// to "no line drawn", which is what every caller wants.
  ///
  /// [departureTime] defaults to `now`, which is what makes Google return
  /// `duration_in_traffic` — without it the ETA ignores live conditions.
  static Future<AppRoute?> fetchDrivingRoute({
    required ({double lat, double lng}) origin,
    required ({double lat, double lng}) destination,
    http.Client? client,
  }) async {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('RouteService: GOOGLE_MAPS_API_KEY missing');
      return null;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.lat},${origin.lng}'
      '&destination=${destination.lat},${destination.lng}'
      '&mode=driving'
      // Live traffic, so the ETA reflects the jam the driver is sitting in.
      '&departure_time=now'
      '&key=$key',
    );

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(url);
      if (response.statusCode != 200) {
        debugPrint('RouteService: HTTP ${response.statusCode}');
        return null;
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      // Google answers 200 even for REQUEST_DENIED / ZERO_RESULTS, so the
      // payload status is what actually says whether a route came back.
      if (data['status'] != 'OK') {
        debugPrint('RouteService: rejected ${data['status']} '
            '${data['error_message'] ?? ''}');
        return null;
      }
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final legs = (routes.first as Map<String, dynamic>)['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;
      final leg = legs.first as Map<String, dynamic>;

      final steps = (leg['steps'] as List?) ?? const [];
      final points = <({double lat, double lng})>[];
      final streets = <String>[];

      for (final raw in steps) {
        final step = raw as Map<String, dynamic>;
        final encoded = step['polyline']?['points'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          final decoded = decodePolyline(encoded);
          // Consecutive steps share their boundary vertex; dropping the
          // duplicate keeps the joint from double-drawing its round cap.
          if (points.isNotEmpty &&
              decoded.isNotEmpty &&
              points.last == decoded.first) {
            points.addAll(decoded.skip(1));
          } else {
            points.addAll(decoded);
          }
        }
        final name = _streetNameOf(step);
        // Consecutive steps on one road (a turn that keeps the street name)
        // would otherwise repeat it in the list the customer reads.
        if (name != null && (streets.isEmpty || streets.last != name)) {
          streets.add(name);
        }
      }

      if (points.length < 2) return null;

      // duration_in_traffic is only present when departure_time was accepted;
      // fall back to the static estimate so the ETA is never blank.
      final durationSeconds =
          ((leg['duration_in_traffic']?['value'] ?? leg['duration']?['value'])
                  as num?)
              ?.toInt() ??
              0;

      return AppRoute(
        points: points,
        distanceMeters: ((leg['distance']?['value']) as num?)?.toInt() ?? 0,
        durationSeconds: durationSeconds,
        streetNames: streets,
      );
    } catch (e) {
      debugPrint('RouteService: fetch failed $e');
      return null;
    } finally {
      // Only close a client we created; a caller-supplied one is theirs.
      if (client == null) httpClient.close();
    }
  }

  /// Pulls the road name out of a Directions step.
  ///
  /// Google does not return a plain street name field. `html_instructions`
  /// carries it inside markup ("Turn right onto <b>Rue de Marseille</b>"), so
  /// the bold run is the most reliable source; when a step has no bold run we
  /// fall back to the stripped instruction text.
  static String? _streetNameOf(Map<String, dynamic> step) {
    final html = step['html_instructions'] as String?;
    if (html == null || html.isEmpty) return null;

    final bold = RegExp(r'<b>(.*?)</b>', dotAll: true).allMatches(html);
    for (final m in bold) {
      final candidate = _stripHtml(m.group(1) ?? '');
      // Skip the bold runs that are directions or highway shields rather than
      // a street ("north", "Exit 4"), which would read as nonsense in a list
      // of streets.
      if (candidate.isEmpty) continue;
      if (_kDirectionWords.contains(candidate.toLowerCase())) continue;
      return candidate;
    }
    final plain = _stripHtml(html);
    return plain.isEmpty ? null : plain;
  }

  static const Set<String> _kDirectionWords = {
    'north', 'south', 'east', 'west',
    'northeast', 'northwest', 'southeast', 'southwest',
    'nord', 'sud', 'est', 'ouest',
  };

  static String _stripHtml(String input) => input
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Decodes Google's encoded-polyline format into lat/lng pairs.
  ///
  /// The format stores each coordinate as a delta from the previous one, in
  /// units of 1e-5 degrees, chunked into 5-bit groups with a continuation bit
  /// and zig-zag encoded so negatives pack small.
  static List<({double lat, double lng})> decodePolyline(String encoded) {
    final points = <({double lat, double lng})>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      // Each coordinate is two varints: the latitude delta then the longitude.
      var result = 0;
      var shift = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add((lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }
}
