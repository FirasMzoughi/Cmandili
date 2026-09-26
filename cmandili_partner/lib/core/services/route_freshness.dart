import 'dart:math' as math;

/// Decides when a drawn route has gone stale and must be re-fetched.
///
/// The naive rule — "re-fetch once the driver has moved N meters from where we
/// last asked" — is what the client app used, and it is the wrong question. A
/// driver following the route perfectly for 300 m triggers a pointless
/// re-fetch, while a driver who turns off the route 50 m after the last fetch
/// keeps a visibly wrong line until they have covered the full 300 m.
///
/// This asks the right question instead: **how far is the driver from the line
/// we drew?** A driver on the route stays within GPS noise of it no matter how
/// far they travel; a driver who takes a different street diverges immediately.
/// That is precisely the "if he goes another way the route changes" behaviour.
class RouteFreshness {
  /// Distance from the drawn line beyond which the driver is considered to
  /// have taken a different street. Wide enough to absorb urban GPS error and
  /// dual-carriageway offsets, tight enough to catch a real wrong turn within
  /// a block.
  static const double kOffRouteThresholdMeters = 55;

  /// Hard floor between two Directions calls for the *same* destination, so a
  /// driver weaving along a noisy GPS track cannot spam the API (and the
  /// billing) with a request per tick.
  static const Duration kMinRefetchInterval = Duration(seconds: 12);

  /// True when [driver] has strayed further than [kOffRouteThresholdMeters]
  /// from [route] — i.e. they are driving a street the drawn line does not
  /// cover. Returns true for an empty/short route so the first fetch happens.
  static bool isOffRoute(
    List<({double lat, double lng})>? route,
    ({double lat, double lng}) driver,
  ) {
    if (route == null || route.length < 2) return true;
    return distanceToRouteMeters(route, driver) > kOffRouteThresholdMeters;
  }

  /// Shortest distance in meters from [p] to the polyline [route], measured
  /// against each segment rather than only the vertices — a vertex-only check
  /// reports a driver mid-way along a long straight segment as far off route
  /// when they are exactly on it.
  static double distanceToRouteMeters(
    List<({double lat, double lng})> route,
    ({double lat, double lng}) p,
  ) {
    var best = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final d = _pointToSegmentMeters(p, route[i], route[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  /// Distance from point to line segment, computed in a local meters-based
  /// frame. At delivery scale the equirectangular projection error is far
  /// below GPS noise, and it avoids a trig-heavy geodesic solve per segment on
  /// every GPS tick.
  static double _pointToSegmentMeters(
    ({double lat, double lng}) p,
    ({double lat, double lng}) a,
    ({double lat, double lng}) b,
  ) {
    const metersPerDegree = 111320.0;
    final latScale = math.cos(p.lat * math.pi / 180);

    final px = p.lng * metersPerDegree * latScale;
    final py = p.lat * metersPerDegree;
    final ax = a.lng * metersPerDegree * latScale;
    final ay = a.lat * metersPerDegree;
    final bx = b.lng * metersPerDegree * latScale;
    final by = b.lat * metersPerDegree;

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;

    // Degenerate segment (duplicate vertices): fall back to point distance.
    if (lengthSquared == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }

    // Project p onto the segment, clamped to its endpoints.
    var t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}
