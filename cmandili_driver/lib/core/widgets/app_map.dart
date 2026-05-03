import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

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

  const AppMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.title,
  });

  @override
  bool operator ==(Object other) =>
      other is AppMapMarker &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.kind == kind &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, kind, title);
}

/// Imperative controls exposed to the parent of [AppMap]. Mirrors the subset
/// of the old `GoogleMapController` we used: animate camera to a point, or
/// fit a bounding box.
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

/// Mapbox-backed map widget that accepts declarative markers and a single
/// optional polyline. Drop-in replacement for the previous `GoogleMap` usage:
/// the parent passes a fresh [markers] set and optional [polyline] on each
/// build, we diff against what's currently rendered, and update the
/// annotation managers accordingly.
class AppMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Set<AppMapMarker> markers;
  final List<({double lat, double lng})>? polyline;
  final bool showUserLocationPuck;
  final AppMapController? controller;
  final VoidCallback? onMapReady;

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
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _markerManager;
  mb.PolylineAnnotationManager? _polylineManager;

  final Map<String, mb.PointAnnotation> _renderedMarkers = {};
  mb.PolylineAnnotation? _renderedPolyline;

  final Map<AppMapMarkerKind, Uint8List> _iconCache = {};

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
    if (_map != null) {
      if (widget.markers != oldWidget.markers) {
        _syncMarkers();
      }
      if (widget.polyline != oldWidget.polyline) {
        _syncPolyline();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return mb.MapWidget(
      key: const ValueKey('app_map'),
      cameraOptions: mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(
            widget.initialLongitude,
            widget.initialLatitude,
          ),
        ),
        zoom: widget.initialZoom,
      ),
      styleUri: mb.MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;
    if (widget.showUserLocationPuck) {
      await map.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
        ),
      );
    }
    _markerManager = await map.annotations.createPointAnnotationManager();
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    await _syncMarkers();
    await _syncPolyline();
    if (mounted) widget.onMapReady?.call();
  }

  Future<void> _syncMarkers() async {
    final manager = _markerManager;
    if (manager == null) return;

    final incoming = {for (final m in widget.markers) m.id: m};

    final toRemove = <String>[];
    for (final id in _renderedMarkers.keys) {
      if (!incoming.containsKey(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      final ann = _renderedMarkers.remove(id);
      if (ann != null) await manager.delete(ann);
    }

    for (final marker in incoming.values) {
      final existing = _renderedMarkers[marker.id];
      final icon = await _iconFor(marker.kind);
      final point = mb.Point(
        coordinates: mb.Position(marker.longitude, marker.latitude),
      );
      if (existing == null) {
        final ann = await manager.create(
          mb.PointAnnotationOptions(
            geometry: point,
            image: icon,
            iconSize: 1.0,
            textField: marker.title,
            textOffset: [0, 1.6],
            textSize: 12,
          ),
        );
        _renderedMarkers[marker.id] = ann;
      } else {
        existing.geometry = point;
        existing.textField = marker.title;
        await manager.update(existing);
      }
    }
  }

  Future<void> _syncPolyline() async {
    final manager = _polylineManager;
    if (manager == null) return;

    final line = widget.polyline;
    if (line == null || line.length < 2) {
      final existing = _renderedPolyline;
      if (existing != null) {
        await manager.delete(existing);
        _renderedPolyline = null;
      }
      return;
    }

    final geometry = mb.LineString(
      coordinates: [
        for (final p in line) mb.Position(p.lng, p.lat),
      ],
    );

    final existing = _renderedPolyline;
    if (existing == null) {
      _renderedPolyline = await manager.create(
        mb.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: 0xFFF2703F, // primary accent, ARGB int
          lineWidth: 4.0,
        ),
      );
    } else {
      existing.geometry = geometry;
      await manager.update(existing);
    }
  }

  Future<Uint8List> _iconFor(AppMapMarkerKind kind) async {
    final cached = _iconCache[kind];
    if (cached != null) return cached;
    final bytes = await _renderPinBytes(_colorFor(kind));
    _iconCache[kind] = bytes;
    return bytes;
  }

  Color _colorFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return const Color(0xFF2E7D32); // green
      case AppMapMarkerKind.pickup:
        return const Color(0xFF6A1B9A); // violet
      case AppMapMarkerKind.driver:
        return const Color(0xFFEF6C00); // orange
    }
  }

  // Mapbox's PointAnnotation needs raw PNG bytes; rasterize a small colored
  // pin at runtime so we don't have to ship asset PNGs.
  Future<Uint8List> _renderPinBytes(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 72;
    const double radius = 22;
    final paintFill = Paint()..color = color;
    final paintStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), radius, paintFill);
    canvas.drawCircle(const Offset(size / 2, size / 2), radius, paintStroke);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _animateToPoint(
    double lat,
    double lng, {
    double? zoom,
  }) async {
    await _map?.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: zoom,
      ),
      mb.MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    final map = _map;
    if (map == null || points.isEmpty) return;
    final coords = [
      for (final p in points) mb.Point(coordinates: mb.Position(p.lng, p.lat)),
    ];
    final cam = await map.cameraForCoordinatesPadding(
      coords,
      mb.CameraOptions(),
      mb.MbxEdgeInsets(
        top: padding.top,
        left: padding.left,
        bottom: padding.bottom,
        right: padding.right,
      ),
      null,
      null,
    );
    await map.flyTo(cam, mb.MapAnimationOptions(duration: 600));
  }
}
