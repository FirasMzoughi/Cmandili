import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

/// Role/color of a marker on [AppMap]. Maps onto the `BitmapDescriptor.hue*`
/// constants Google Maps provides for its default pins.
enum AppMapMarkerKind { delivery, pickup, driver }

/// A single marker to draw on [AppMap]. Equality is by value so the parent can
/// rebuild with a new set and only the changed markers are re-rendered.
class AppMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final AppMapMarkerKind kind;
  final String? title;

  /// Optional compass heading in degrees (0 = north, clockwise), used to
  /// rotate the marker so a moving driver visibly points the way they're
  /// heading instead of always facing the same fixed direction. Ignored for
  /// non-driver marker kinds. Null means "no rotation" (renders upright).
  final double? bearing;

  const AppMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.title,
    this.bearing,
  });

  @override
  bool operator ==(Object other) =>
      other is AppMapMarker &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.kind == kind &&
      other.title == title &&
      other.bearing == bearing;

  @override
  int get hashCode =>
      Object.hash(id, latitude, longitude, kind, title, bearing);
}

/// Great-circle initial bearing from [from] to [to], in degrees (0-360,
/// 0 = north, clockwise) — the standard formula for "which way do I turn to
/// face the destination". Used to rotate the driver marker so it visibly
/// points in its direction of travel between consecutive GPS fixes.
double bearingBetween(
  ({double lat, double lng}) from,
  ({double lat, double lng}) to,
) {
  final lat1 = from.lat * (math.pi / 180);
  final lat2 = to.lat * (math.pi / 180);
  final dLng = (to.lng - from.lng) * (math.pi / 180);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final deg = math.atan2(y, x) * (180 / math.pi);
  return (deg + 360) % 360;
}

/// Imperative controls exposed to the parent of [AppMap]: animate the camera
/// to a point, or fit a bounding box around a set of points.
class AppMapController {
  _AppMapState? _state;

  void _attach(_AppMapState state) => _state = state;
  void _detach() => _state = null;

  Future<void> animateToPoint(
    double latitude,
    double longitude, {
    double? zoom,
  }) async {
    await _state?._animateToPoint(latitude, longitude, zoom: zoom);
  }

  Future<void> fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    await _state?._fitBounds(points, padding: padding);
  }

  void dispose() => _detach();
}

/// Declutters the basemap for delivery use: business/park/school points of
/// interest and transit lines are hidden, because their tappable labels compete
/// with our own pickup/delivery/driver markers for the same pixels and carry no
/// meaning in this app. Roads, road labels and place names are left intact --
/// those are what a courier actually navigates by.
const String _kMapStyle = """
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]
""";

/// Google Maps-backed map widget that accepts declarative markers and a single
/// optional polyline.
///
/// Google Maps takes markers/polylines as immutable Sets rebuilt on each frame,
/// so unlike the Mapbox annotation-manager approach this needs no imperative
/// diffing, no async create/update/delete calls, and therefore no sync-queue
/// guarding against overlapping updates -- the widget layer handles it. That
/// also removes the marker-sync race that previously froze the driver marker.
class AppMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Set<AppMapMarker> markers;
  final List<({double lat, double lng})>? polyline;
  final bool showUserLocationPuck;
  final AppMapController? controller;
  final VoidCallback? onMapReady;

  /// Area of the map obscured by the parent's own overlays (bottom sheets,
  /// floating cards). Google keeps its controls out of it and centres camera
  /// moves on what is left, so a fitted route is not hidden behind a sheet.
  final EdgeInsets contentPadding;

  /// Live traffic shading. Useful while a delivery is in progress; noise on a
  /// static "where is this address" map, so it is opt-in.
  final bool showTraffic;

  const AppMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialZoom = 14,
    this.markers = const {},
    this.polyline,
    this.showUserLocationPuck = false,
    this.controller,
    this.onMapReady,
    this.contentPadding = EdgeInsets.zero,
    this.showTraffic = false,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  gm.GoogleMapController? _map;

  /// Camera moves requested before the map finished creating. Google Maps
  /// throws if the controller is used too early, so the most recent request is
  /// held here and replayed from onMapCreated.
  Future<void> Function()? _pendingCameraMove;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _map?.dispose();
    super.dispose();
  }

  double _hueFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return gm.BitmapDescriptor.hueGreen;
      case AppMapMarkerKind.pickup:
        return gm.BitmapDescriptor.hueViolet;
      case AppMapMarkerKind.driver:
        return gm.BitmapDescriptor.hueOrange;
    }
  }

  Set<gm.Marker> get _markers => {
        for (final m in widget.markers)
          gm.Marker(
            markerId: gm.MarkerId(m.id),
            position: gm.LatLng(m.latitude, m.longitude),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(_hueFor(m.kind)),
            // Only the driver marker conveys heading; rotating a static pickup
            // or delivery pin would just look broken.
            rotation:
                m.kind == AppMapMarkerKind.driver ? (m.bearing ?? 0) : 0,
            // Rotate about the pin's centre rather than its default tip anchor,
            // so a heading change spins the marker in place instead of swinging
            // it around the point it is marking.
            anchor: m.kind == AppMapMarkerKind.driver
                ? const Offset(0.5, 0.5)
                : const Offset(0.5, 1.0),
            flat: m.kind == AppMapMarkerKind.driver,
            infoWindow: m.title == null
                ? gm.InfoWindow.noText
                : gm.InfoWindow(title: m.title),
          ),
      };

  Set<gm.Polyline> get _polylines {
    final line = widget.polyline;
    if (line == null || line.length < 2) return const {};
    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('route'),
        points: [for (final p in line) gm.LatLng(p.lat, p.lng)],
        color: const Color(0xFFF2703F), // primary accent
        width: 6,
        jointType: gm.JointType.round,
        // Rounded caps stop the line ending in a hard rectangle at the pins.
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      key: const ValueKey('app_map'),
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(widget.initialLatitude, widget.initialLongitude),
        zoom: widget.initialZoom,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: widget.showUserLocationPuck,
      myLocationButtonEnabled: widget.showUserLocationPuck,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // Keeps Google's own controls and the copyright notice clear of sheets
      // and cards the parent overlays on the map, and biases the camera so a
      // fitted route is centred in the *visible* area rather than behind them.
      padding: widget.contentPadding,
      trafficEnabled: widget.showTraffic,
      style: _kMapStyle,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(gm.GoogleMapController map) async {
    _map = map;
    // Replay a camera move requested while the map was still initialising.
    final pending = _pendingCameraMove;
    _pendingCameraMove = null;
    if (pending != null) await pending();
    if (mounted) widget.onMapReady?.call();
  }

  Future<void> _animateToPoint(
    double lat,
    double lng, {
    double? zoom,
  }) async {
    final map = _map;
    if (map == null) {
      _pendingCameraMove = () => _animateToPoint(lat, lng, zoom: zoom);
      return;
    }
    await map.animateCamera(
      gm.CameraUpdate.newCameraPosition(
        gm.CameraPosition(
          target: gm.LatLng(lat, lng),
          zoom: zoom ?? widget.initialZoom,
        ),
      ),
    );
  }

  Future<void> _fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    if (points.isEmpty) return;
    final map = _map;
    if (map == null) {
      _pendingCameraMove = () => _fitBounds(points, padding: padding);
      return;
    }

    // A single point has no extent: LatLngBounds requires sw <= ne on both
    // axes, and a zero-area box makes Google Maps zoom to maximum. Centre on
    // it instead.
    if (points.length == 1) {
      await _animateToPoint(points.first.lat, points.first.lng);
      return;
    }

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final bounds = gm.LatLngBounds(
      southwest: gm.LatLng(minLat, minLng),
      northeast: gm.LatLng(maxLat, maxLng),
    );

    // CameraUpdate.newLatLngBounds takes one padding value, so use the largest
    // side to guarantee nothing is clipped.
    final pad = [padding.top, padding.left, padding.bottom, padding.right]
        .reduce((a, b) => a > b ? a : b);

    await map.animateCamera(gm.CameraUpdate.newLatLngBounds(bounds, pad));
  }
}
