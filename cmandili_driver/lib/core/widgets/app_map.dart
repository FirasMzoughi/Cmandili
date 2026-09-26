import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

/// Role/color of a marker on [AppMap]. Pre-defined palette that replaces the
/// `BitmapDescriptor.hue*` constants used under Google Maps.
enum AppMapMarkerKind { delivery, pickup, driver }

/// A single marker to draw on [AppMap]. Equality is by id so the parent can
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

/// Imperative controls exposed to the parent of [AppMap]. Mirrors the subset
/// of the old `GoogleMapController` we used: animate camera to a point, or
/// fit a bounding box.
class AppMapController {
  _AppMapState? _state;

  void _attach(_AppMapState state) => _state = state;
  void _detach(_AppMapState state) {
    // Only clear if we are still pointing at this state. During a widget swap
    // Flutter can attach the new state before detaching the old one, and an
    // unconditional detach would leave the controller pointing at nothing.
    if (identical(_state, state)) _state = null;
  }

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

  void dispose() => _state = null;
}

/// On-screen size of a pin, in logical pixels. The bitmap behind it is drawn
/// at this size multiplied by the device pixel ratio, so it stays sharp.
const double _kPinLogicalSize = 48;

/// Brand palette used by both the rasterized pins and the route line, kept in
/// one place so a pin, its route and its shadow can never drift apart.
const Color _kDeliveryColor = Color(0xFF059669); // brand emerald, same as the client app
const Color _kPickupColor = Color(0xFF6C3DE1); // brand purple
const Color _kDriverColor = Color(0xFFF59E0B); // brand amber — the courier
// Route matches the client app so all three apps draw the same green line.
const Color _kRouteColor = _kDeliveryColor;

/// Declutters the basemap for delivery use: business/park/school points of
/// interest and transit lines are hidden, because their tappable labels compete
/// with our own pickup/delivery/driver markers for the same pixels and carry no
/// meaning in this app. Roads, road labels and place names are left intact --
/// those are what a courier actually navigates by.
///
/// Beyond hiding noise, the land/water/road fills are desaturated a step and
/// the arterial roads lightened, so the coloured markers and the route line are
/// the most saturated things on screen instead of competing with the basemap.
const String _kMapStyleLight = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"geometry","stylers":[{"color":"#f5f6f7"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":2}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#d8dce1"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#eef1ed"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#fdf3e3"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f0e2c8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe4ef"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#8aa9b8"}]}
]
''';

/// Dark counterpart of [_kMapStyleLight], applied when the app is in dark mode
/// so a full-bleed map does not blast a white rectangle at a night-time user.
/// The same hide/desaturate logic applies; only the value ramp is inverted.
const String _kMapStyleDark = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"geometry","stylers":[{"color":"#1f2430"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9aa4b2"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#151922"},{"weight":2}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#39404e"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#222835"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c3342"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#333b4b"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d4658"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#2a3140"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#151c29"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#54697d"}]}
]
''';

/// Google Maps-backed map widget that accepts declarative markers and a single
/// optional polyline. The parent passes a fresh [markers] set and optional
/// [polyline] on each build and Google reconciles them, so there is no
/// imperative annotation syncing to do here.
///
/// Positions are *tweened* rather than snapped: a GPS fix arrives every few
/// seconds, and jumping the driver pin between them reads as teleporting. The
/// widget interpolates position and bearing over [_kMarkerTweenDuration] so the
/// pin glides along its path the way a native navigation app does.
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

  /// Called when the user pans/zooms by hand. The parent uses this to stop
  /// auto-recentering and hand camera control to the user.
  final VoidCallback? onUserGesture;

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
    this.onUserGesture,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

/// How long a marker takes to glide from its previous position to the newly
/// reported one. Roughly matches the driver GPS tick, so the pin is still
/// moving when the next fix lands and the motion reads as continuous.
const Duration _kMarkerTweenDuration = Duration(milliseconds: 900);

/// One marker's animation state: where it is being drawn right now, and the
/// endpoints it is travelling between.
class _MarkerTween {
  double fromLat, fromLng, fromBearing;
  double toLat, toLng, toBearing;

  _MarkerTween({
    required this.fromLat,
    required this.fromLng,
    required this.fromBearing,
    required this.toLat,
    required this.toLng,
    required this.toBearing,
  });

  /// Interpolated position at progress [t] (0..1), eased.
  ({double lat, double lng, double bearing}) at(double t) {
    final e = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    return (
      lat: fromLat + (toLat - fromLat) * e,
      lng: fromLng + (toLng - fromLng) * e,
      bearing: _lerpBearing(fromBearing, toBearing, e),
    );
  }
}

/// Interpolates two compass headings the short way round, so a turn from 350°
/// to 10° sweeps 20° forward instead of spinning 340° backwards.
double _lerpBearing(double from, double to, double t) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (from + delta * t) % 360;
}

class _AppMapState extends State<AppMap> with SingleTickerProviderStateMixin {
  gm.GoogleMapController? _map;

  /// Rasterized pins, keyed by kind. Built once per kind and reused -- the
  /// drawing code below is unchanged from the Mapbox version, since Google
  /// Maps also takes raw PNG bytes (via BitmapDescriptor.bytes).
  final Map<AppMapMarkerKind, Uint8List> _iconCache = {};

  /// Icons resolve asynchronously but markers must be built synchronously in
  /// build(), so the decoded descriptors are cached here and a rebuild is
  /// triggered once they are ready.
  final Map<AppMapMarkerKind, gm.BitmapDescriptor> _descriptors = {};

  /// Device pixel ratio the cached descriptors were rasterized for.
  double? _descriptorRatio;

  /// Camera moves requested before the map finished creating. Google Maps
  /// throws if the controller is used too early, so the most recent request is
  /// held here and replayed from onMapCreated.
  Future<void> Function()? _pendingCameraMove;

  /// Drives marker position/bearing tweens. Runs only while at least one
  /// marker is actually in motion, so an idle map costs no frames.
  late final AnimationController _tweenController;

  /// Live tween state per marker id.
  final Map<String, _MarkerTween> _tweens = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _tweenController = AnimationController(
      vsync: this,
      duration: _kMarkerTweenDuration,
    )..addListener(() {
        // Repaint the marker layer on each tick; positions are read from the
        // tweens in build(). No setState payload needed.
        if (mounted) setState(() {});
      });
    _seedTweens();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: rasterizing needs the device pixel ratio from MediaQuery,
    // which is not available until dependencies resolve. This also re-fires if
    // the ratio changes, which is what re-cuts the bitmaps for the new density.
    _loadDescriptors();
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // Markers and polylines are rebuilt declaratively in build(); unlike the
    // Mapbox annotation managers there is nothing to diff or sync here, which
    // is what removes the marker-sync race the old implementation guarded
    // against with an in-flight/queued pair of flags.
    _loadDescriptors();
    _retargetTweens(oldWidget.markers);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _tweenController.dispose();
    _map?.dispose();
    super.dispose();
  }

  /// First frame: every marker starts already at its reported position, so
  /// nothing animates in from a bogus origin.
  void _seedTweens() {
    for (final m in widget.markers) {
      _tweens[m.id] = _MarkerTween(
        fromLat: m.latitude,
        fromLng: m.longitude,
        fromBearing: m.bearing ?? 0,
        toLat: m.latitude,
        toLng: m.longitude,
        toBearing: m.bearing ?? 0,
      );
    }
  }

  /// Points every tween at the freshly reported coordinates, starting from
  /// wherever the marker is *currently drawn* rather than from its last target
  /// — otherwise a fix arriving mid-flight would snap the pin backwards.
  void _retargetTweens(Set<AppMapMarker> oldMarkers) {
    final t = _tweenController.isAnimating ? _tweenController.value : 1.0;
    var moved = false;

    for (final m in widget.markers) {
      final existing = _tweens[m.id];
      final bearing = m.bearing ?? existing?.toBearing ?? 0;
      if (existing == null) {
        _tweens[m.id] = _MarkerTween(
          fromLat: m.latitude,
          fromLng: m.longitude,
          fromBearing: bearing,
          toLat: m.latitude,
          toLng: m.longitude,
          toBearing: bearing,
        );
        continue;
      }
      if (existing.toLat == m.latitude &&
          existing.toLng == m.longitude &&
          existing.toBearing == bearing) {
        continue;
      }
      // A jump larger than this is a re-anchor (order switched, first real GPS
      // fix after a placeholder), not travel. Tweening across a whole city
      // would send the pin sliding over the map for a second; snap instead.
      final current = existing.at(t);
      final jumped = _roughDistanceMeters(
            (lat: current.lat, lng: current.lng),
            (lat: m.latitude, lng: m.longitude),
          ) >
          _kTweenSnapThresholdMeters;

      _tweens[m.id] = _MarkerTween(
        fromLat: jumped ? m.latitude : current.lat,
        fromLng: jumped ? m.longitude : current.lng,
        fromBearing: jumped ? bearing : current.bearing,
        toLat: m.latitude,
        toLng: m.longitude,
        toBearing: bearing,
      );
      if (!jumped) moved = true;
    }

    // Drop tweens for markers the parent no longer draws.
    final live = {for (final m in widget.markers) m.id};
    _tweens.removeWhere((id, _) => !live.contains(id));

    if (moved) {
      _tweenController.forward(from: 0);
    } else if (!_tweenController.isAnimating) {
      _tweenController.value = 1;
    }
  }

  /// Rasterizes any pin kind currently in use that has not been built yet.
  ///
  /// Pins are drawn at the device pixel ratio and handed to Google with their
  /// LOGICAL size, so they stay crisp on high-density screens instead of being
  /// upscaled from a fixed 96px bitmap. The cache is keyed by kind *and* ratio
  /// so moving to a different-density display re-rasterizes rather than
  /// reusing a bitmap cut for the old one.
  Future<void> _loadDescriptors() async {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    if (ratio != _descriptorRatio) {
      _descriptors.clear();
      _iconCache.clear();
      _descriptorRatio = ratio;
    }
    final needed = {for (final m in widget.markers) m.kind};
    var added = false;
    for (final kind in needed) {
      if (_descriptors.containsKey(kind)) continue;
      final bytes = await _iconFor(kind, ratio);
      _descriptors[kind] = gm.BitmapDescriptor.bytes(
        bytes,
        width: _kPinLogicalSize,
        height: _kPinLogicalSize,
      );
      added = true;
    }
    if (added && mounted) setState(() {});
  }

  Set<gm.Marker> get _markers {
    final t = _tweenController.value;
    return {
      for (final m in widget.markers)
        () {
          final tween = _tweens[m.id];
          final pos = tween?.at(t) ??
              (lat: m.latitude, lng: m.longitude, bearing: m.bearing ?? 0);
          final isDriver = m.kind == AppMapMarkerKind.driver;
          return gm.Marker(
            markerId: gm.MarkerId(m.id),
            position: gm.LatLng(pos.lat, pos.lng),
            // Falls back to the default pin until the custom bitmap is ready,
            // so a marker is never missing from the map while it rasterizes.
            icon: _descriptors[m.kind] ?? gm.BitmapDescriptor.defaultMarker,
            // Only the driver marker conveys heading. The driver badge is drawn
            // radially symmetric precisely so it can be rotated about its centre
            // without the pin tip leaving the real coordinate.
            rotation: isDriver ? pos.bearing : 0,
            anchor: isDriver
                ? const Offset(0.5, 0.5)
                : const Offset(0.5, 1.0),
            flat: isDriver,
            // The live driver has to stay on top of the static pins; when they
            // overlap at the doorstep, the moving one is the informative one.
            zIndexInt: isDriver ? 2 : 1,
            infoWindow: m.title == null
                ? gm.InfoWindow.noText
                : gm.InfoWindow(title: m.title),
          );
        }(),
    };
  }

  /// White casing drawn under the brand-colored line so the route reads like a
  /// layered nav route rather than a flat stroke. Google draws polylines in
  /// zIndex order, which replaces Mapbox's implicit creation order.
  Set<gm.Polyline> get _polylines {
    final line = widget.polyline;
    if (line == null || line.length < 2) return const {};
    final points = [for (final p in line) gm.LatLng(p.lat, p.lng)];
    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('route_casing'),
        points: points,
        color: const Color(0xFFFFFFFF),
        width: 12,
        jointType: gm.JointType.round,
        // Rounded caps stop the casing ending in a hard rectangle at the pins.
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
        zIndex: 0,
      ),
      // A translucent wide stroke under the line reads as a soft shadow and
      // keeps the route legible over both pale streets and dark parkland.
      gm.Polyline(
        polylineId: const gm.PolylineId('route_glow'),
        points: points,
        color: _kRouteColor.withValues(alpha: 0.22),
        width: 18,
        jointType: gm.JointType.round,
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
        zIndex: 0,
      ),
      gm.Polyline(
        polylineId: const gm.PolylineId('route'),
        points: points,
        color: _kRouteColor,
        width: 6,
        jointType: gm.JointType.round,
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
        zIndex: 1,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
      compassEnabled: true,
      // Two-finger rotate/tilt add nothing to a flat delivery map and are an
      // easy way to end up looking at a sideways city with no way back.
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      // Keeps Google's own controls and the copyright notice clear of sheets
      // and cards the parent overlays on the map, and biases the camera so a
      // fitted route is centred in the *visible* area rather than behind them.
      padding: widget.contentPadding,
      trafficEnabled: widget.showTraffic,
      style: brightness == Brightness.dark ? _kMapStyleDark : _kMapStyleLight,
      // Lets the parent hand camera control to the user on first manual pan.
      onCameraMoveStarted: widget.onUserGesture,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(gm.GoogleMapController map) async {
    _map = map;
    final pending = _pendingCameraMove;
    _pendingCameraMove = null;
    if (pending != null) await pending();
    if (mounted) widget.onMapReady?.call();
  }

  Future<Uint8List> _iconFor(AppMapMarkerKind kind, double ratio) async {
    final cached = _iconCache[kind];
    if (cached != null) return cached;
    final bytes = await _renderPinBytes(kind, ratio);
    _iconCache[kind] = bytes;
    return bytes;
  }

  Color _colorFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return _kDeliveryColor;
      case AppMapMarkerKind.pickup:
        return _kPickupColor;
      case AppMapMarkerKind.driver:
        return _kDriverColor;
    }
  }

  IconData _glyphFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return Icons.home_rounded;
      case AppMapMarkerKind.pickup:
        return Icons.storefront_rounded;
      case AppMapMarkerKind.driver:
        return Icons.two_wheeler_rounded;
    }
  }

  // Rasterize a teardrop pin
  // with a glyph + soft drop shadow at runtime so we don't have to ship
  // per-density asset PNGs. Mirrors the pin style used by MapAddressPicker.
  //
  // The driver marker gets a separate, symmetric badge (see
  // _renderDriverBadgeBytes) instead of this teardrop shape: a teardrop's
  // off-center tail always has to point straight down at the exact
  // coordinate, so rotating the whole image to show heading (iconRotate)
  // would visibly swing the tail off the driver's real position. A
  // radially-symmetric badge has no such constraint.
  Future<Uint8List> _renderPinBytes(AppMapMarkerKind kind, double ratio) async {
    if (kind == AppMapMarkerKind.driver) {
      return _renderDriverBadgeBytes(ratio);
    }
    final color = _colorFor(kind);
    final glyph = _glyphFor(kind);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Everything below is laid out in a fixed 96-unit design space; scaling the
    // canvas up front renders that same artwork at device resolution without
    // touching a single coordinate.
    canvas.scale(ratio);
    const double size = 96;
    const double bubbleRadius = 26;
    const Offset bubbleCenter = Offset(size / 2, bubbleRadius + 6);

    // Soft drop shadow under the whole pin.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(size / 2, size - 10),
        width: 22,
        height: 8,
      ),
      shadowPaint,
    );

    // Teardrop tail.
    final tailPaint = Paint()..color = color;
    final tailPath = Path()
      ..moveTo(bubbleCenter.dx - 9, bubbleCenter.dy + bubbleRadius - 10)
      ..lineTo(bubbleCenter.dx, size - 16)
      ..lineTo(bubbleCenter.dx + 9, bubbleCenter.dy + bubbleRadius - 10)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // Round bubble with white ring.
    canvas.drawCircle(bubbleCenter, bubbleRadius + 3, Paint()..color = Colors.white);
    // A vertical gradient across the disc gives the flat fill a little
    // dimension, so the pin reads as a raised object rather than a sticker.
    canvas.drawCircle(
      bubbleCenter,
      bubbleRadius,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bubbleCenter.dx, bubbleCenter.dy - bubbleRadius),
          Offset(bubbleCenter.dx, bubbleCenter.dy + bubbleRadius),
          [_lighten(color, 0.12), color],
        ),
    );

    // Glyph, centered in the bubble.
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      bubbleCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * ratio).round(),
      (size * ratio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Radially-symmetric driver badge: white ring, amber disc, a two-wheeler
  // glyph, and a small chevron pointing "up" (north in image-space) at the
  // rim. Combined with the marker's rotation and flat: true, the whole badge —
  // chevron included — turns to face the driver's actual direction of travel
  // between consecutive GPS fixes, so the customer can see at a glance which
  // way the driver is heading, not just where they are.
  Future<Uint8List> _renderDriverBadgeBytes(double ratio) async {
    const color = _kDriverColor;
    final glyph = _glyphFor(AppMapMarkerKind.driver);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    const double size = 96;
    const Offset center = Offset(size / 2, size / 2);
    const double discRadius = 26;

    // Soft drop shadow, centered under the disc (no tail to offset it).
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawCircle(center, discRadius, shadowPaint);

    // Halo: a faint tinted ring around the badge, the same cue a native nav
    // app uses to say "this one is live". Purely decorative, drawn first so
    // everything else sits on top of it.
    canvas.drawCircle(
      center,
      discRadius + 12,
      Paint()..color = color.withValues(alpha: 0.16),
    );

    // Heading chevron: a small triangle just outside the white ring,
    // pointing toward image-space "up" — this is what visibly sweeps around
    // as the rotation changes, giving the live "which way are they walking/
    // driving" cue the plain glyph alone can't provide.
    final chevronPaint = Paint()..color = color;
    final chevronTipY = center.dy - discRadius - 13;
    final chevronPath = Path()
      ..moveTo(center.dx, chevronTipY)
      ..lineTo(center.dx - 8, chevronTipY + 12)
      ..lineTo(center.dx + 8, chevronTipY + 12)
      ..close();
    canvas.drawPath(chevronPath, chevronPaint);

    // White ring + gradient disc.
    canvas.drawCircle(center, discRadius + 4, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      discRadius,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - discRadius),
          Offset(center.dx, center.dy + discRadius),
          [_lighten(color, 0.12), color],
        ),
    );

    // Glyph, centered in the disc.
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * ratio).round(),
      (size * ratio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
      await _animateToPoint(points.first.lat, points.first.lng, zoom: 15);
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

    // Two points that are nearly coincident (driver parked at the door) make a
    // near-zero-area box, which Google resolves by zooming to the maximum
    // level. Grow the box to a minimum span so the result stays readable.
    const double minSpan = 0.0016; // ~180 m
    if (maxLat - minLat < minSpan) {
      final c = (maxLat + minLat) / 2;
      minLat = c - minSpan / 2;
      maxLat = c + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final c = (maxLng + minLng) / 2;
      minLng = c - minSpan / 2;
      maxLng = c + minSpan / 2;
    }

    final bounds = gm.LatLngBounds(
      southwest: gm.LatLng(minLat, minLng),
      northeast: gm.LatLng(maxLat, maxLng),
    );

    // CameraUpdate.newLatLngBounds takes one padding value, so use the largest
    // side to guarantee nothing is clipped. Asymmetric insets (a bottom sheet)
    // are handled by GoogleMap.padding instead, which shifts the whole viewport.
    final pad = [padding.top, padding.left, padding.bottom, padding.right]
        .reduce((a, b) => a > b ? a : b);

    await map.animateCamera(gm.CameraUpdate.newLatLngBounds(bounds, pad));
  }
}

/// Beyond this, a position change is treated as a re-anchor and snapped rather
/// than tweened — see [_AppMapState._retargetTweens].
const double _kTweenSnapThresholdMeters = 400;

/// Equirectangular approximation of the distance between two nearby points.
/// Accurate to well under a percent at delivery scale and far cheaper than a
/// full haversine, which matters because this runs on every marker rebuild.
double _roughDistanceMeters(
  ({double lat, double lng}) a,
  ({double lat, double lng}) b,
) {
  const metersPerDegree = 111320.0;
  final meanLat = ((a.lat + b.lat) / 2) * (math.pi / 180);
  final dx = (b.lng - a.lng) * metersPerDegree * math.cos(meanLat);
  final dy = (b.lat - a.lat) * metersPerDegree;
  return math.sqrt(dx * dx + dy * dy);
}

/// Mixes [color] toward white by [amount] (0..1) for the pin's top highlight.
Color _lighten(Color color, double amount) =>
    Color.lerp(color, Colors.white, amount) ?? color;
