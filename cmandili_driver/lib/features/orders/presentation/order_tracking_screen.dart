import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/services/route_service.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/customer_contact.dart';
import '../data/models/order.dart';
import '../providers/order_provider.dart';
import '../providers/driver_orders_provider.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final AppMapController _mapController = AppMapController();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _deliveryStream;
  double? _myLat;
  double? _myLng;
  // Heading in degrees, derived from the last two GPS fixes so the driver's
  // own marker visibly points the direction they're moving — same live cue
  // the client app now shows for the driver's marker on their side.
  double? _myBearing;
  String? _activeDeliveryId;
  bool _uploadingReceipt = false;
  final _supabase = Supabase.instance.client;

  // Restaurant/supermarket pickup coordinates — resolved once per order
  // (food/supermarket orders only; courier/facture already carry their own
  // pickupAddress on the order row). Without this the driver's map never
  // showed WHERE to pick the order up from, only the delivery address.
  double? _pickupLat;
  double? _pickupLng;
  String? _pickupName;
  String? _pickupFetchedForOrderId;
  /// The leg the camera is currently framed on. Null until the first fit.
  /// Compared against the live destination so the map reframes the moment
  /// the driver collects the order and the target becomes the customer.
  ({double lat, double lng})? _fittedForLeg;

  /// The street-following route currently drawn, from the driver to whichever
  /// leg they are on (pickup first, then the drop-off). Carries the ETA,
  /// remaining distance and the road names to follow.
  AppRoute? _route;
  /// Destination the drawn route was computed for. When the driver collects
  /// the order the destination flips from pickup to delivery, which makes the
  /// old line wrong outright rather than merely stale.
  ({double lat, double lng})? _lastRouteDestination;
  bool _routeFetchInFlight = false;
  DateTime? _lastRouteFetchAt;

  /// True once the navigation-grade stream has delivered a fix; from then on
  /// the one-shot seed in [_seedInitialPosition] must not overwrite it.
  bool _gotStreamFix = false;

  /// Route the camera was last fitted to, so a freshly fetched route is framed
  /// once (like the client app) instead of on every GPS tick.
  AppRoute? _fittedRoute;
  ({double lat, double lng})? _lastFittedDestination;

  @override
  void initState() {
    super.initState();
    // Subscribe first to resolve _activeDeliveryId, THEN start GPS.
    // This prevents the race condition where early GPS updates are discarded
    // because _activeDeliveryId is still null.
    _subscribeToDelivery().then((_) => _startLocationTracking());
    // Independent of the delivery lookup above: the map, pins and route only
    // need *a* fix, and the continuous stream can take many seconds (or never
    // fire indoors) before its first navigation-grade reading. Without this
    // the screen sat with no driver pin and no route at all.
    _seedInitialPosition();
  }

  /// Gets a first position fast — last known, then a one-shot current fix —
  /// so the route is fetched immediately instead of waiting on the stream.
  Future<void> _seedInitialPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _applyPosition(last.latitude, last.longitude);
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      _applyPosition(current.latitude, current.longitude);
    } catch (e) {
      debugPrint('Initial position failed: $e');
    }
  }

  /// Seeds the driver position only if the live stream has not already
  /// provided a (better) one.
  void _applyPosition(double lat, double lng) {
    if (!mounted || _gotStreamFix) return;
    setState(() {
      _myLat = lat;
      _myLng = lng;
    });
  }

  /// Resolves the restaurant/supermarket's lat/lng + name once per order, so
  /// the map can show a pickup marker for standard food/supermarket
  /// deliveries (previously only courier/facture orders — which carry their
  /// own pickupAddress — ever showed a pickup pin at all).
  Future<void> _fetchPickupLocation(Order order) async {
    if (_pickupFetchedForOrderId == order.id) return;
    _pickupFetchedForOrderId = order.id;
    // Both ids point at the same `vendors` table, so one lookup covers every
    // category. Querying the legacy restaurants/supermarkets views instead
    // would silently return nothing for a florist, pet shop or bakery order
    // — those views filter on their own category — and the driver would get
    // no pickup pin at all.
    final vendorId = order.restaurantId.isNotEmpty
        ? order.restaurantId
        : order.supermarketId;
    if (vendorId.isEmpty) return;
    try {
      final row = await _supabase
          .from('vendors')
          .select('name, latitude, longitude')
          .eq('id', vendorId)
          .maybeSingle();
      if (row == null || !mounted) return;
      setState(() {
        _pickupLat = (row['latitude'] as num?)?.toDouble();
        _pickupLng = (row['longitude'] as num?)?.toDouble();
        _pickupName = row['name'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to fetch pickup location: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      // bestForNavigation while a delivery is on screen: `high` is a
      // city-block-grade fix, which is what made the pin sit on the wrong
      // side of the street and the customer's ETA jump around. Navigation
      // accuracy keeps the GPS chip in continuous mode, so the position the
      // customer watches is the driver's real one.
      //
      // The 5 m filter matters as much as the accuracy: at 10 m the marker
      // only moved after the driver had already passed the turn.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      // Prefer the device's own GPS-derived heading (more accurate, updates
      // even between distanceFilter-gated position changes); fall back to a
      // bearing computed from the last two fixes when the device reports an
      // invalid heading (some devices report 0 while stationary, which
      // Geolocator can't distinguish from "genuinely facing north").
      double? bearing = (pos.heading >= 0 && pos.heading <= 360 && pos.headingAccuracy >= 0)
          ? pos.heading
          : null;
      if (bearing == null && _myLat != null && _myLng != null) {
        bearing = bearingBetween(
          (lat: _myLat!, lng: _myLng!),
          (lat: pos.latitude, lng: pos.longitude),
        );
      }
      _gotStreamFix = true;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _myBearing = bearing ?? _myBearing;
      });
      // No per-tick camera recenter: it zoomed back onto the driver on every
      // fix and hid the route. The camera is framed on the route when one
      // arrives (see _fetchRoute) and the recenter button is always there.

      // Update driver record
      try {
        final driverId = await ref.read(currentDriverIdProvider.future);
        if (driverId != null) {
          await _supabase.from('drivers').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          }).eq('id', driverId);
        }
      } catch (e) {
        debugPrint('Failed to update driver location: $e');
      }

      // Update delivery row
      try {
        if (_activeDeliveryId != null) {
          await _supabase.from('deliveries').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', _activeDeliveryId!);
        }
      } catch (e) {
        debugPrint('Failed to update delivery location: $e');
      }
    });
  }

  Future<void> _subscribeToDelivery() async {
    // Eagerly fetch the delivery ID so it's available before the first GPS update
    try {
      final row = await _supabase
          .from('deliveries')
          .select('id')
          .eq('order_id', widget.orderId)
          .maybeSingle();
      if (row != null && mounted) {
        _activeDeliveryId = row['id'] as String?;
      }
    } catch (e) {
      debugPrint('Failed to fetch delivery row: $e');
    }

    // Keep a live subscription to catch the row if it doesn't exist yet
    _deliveryStream = _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          _activeDeliveryId ??= rows.first['id'] as String?;
        });
  }

  /// Fetches the street-following route for the leg the driver is currently
  /// on and redraws it. Called from build() whenever the line has gone stale
  /// — see the caller for the off-route rule that decides that.
  Future<void> _fetchRoute({
    required ({double lat, double lng}) origin,
    required ({double lat, double lng}) destination,
  }) async {
    if (_routeFetchInFlight) return;
    _routeFetchInFlight = true;
    _lastRouteDestination = destination;
    _lastRouteFetchAt = DateTime.now();
    try {
      final route = await RouteService.fetchDrivingRoute(
        origin: origin,
        destination: destination,
      );
      if (route == null || !mounted) return;
      setState(() => _route = route);
      // Frame the whole route once per new leg, the way the client app does,
      // so the driver sees the full line to the destination.
      if (_fittedRoute == null || destination != _lastFittedDestination) {
        _fittedRoute = route;
        _lastFittedDestination = destination;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.fitBounds(route.points);
        });
      }
    } finally {
      _routeFetchInFlight = false;
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _deliveryStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Shows a bottom sheet to let the driver choose between camera and gallery,
  /// then uploads the chosen image as the payment receipt.
  Future<void> _uploadReceipt() async {
    final source = await _pickImageSource();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingReceipt = true);
    try {
      final driverId = await ref.read(currentDriverIdProvider.future);
      final path = '${driverId ?? 'driver'}/${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(picked.path).readAsBytes();
      await _supabase.storage.from('receipts').uploadBinary(path, bytes);
      final url = _supabase.storage.from('receipts').getPublicUrl(path);
      // bill_receipt_url is the column added by migration 20260624_facture_columns
      await _supabase
          .from('orders')
          .update({'bill_receipt_url': url})
          .eq('id', widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reçu uploadé avec succès ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.orange),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.orange),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _markPickedUp() async {
    await _supabase
        .from('orders')
        .update({'status': 'pickedUp'}).eq('id', widget.orderId);

    if (_activeDeliveryId != null) {
      await _supabase
          .from('deliveries')
          .update({'status': 'pickedUp'}).eq('id', _activeDeliveryId!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderMarkedPickedUp),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  static const _releaseReasons = [
    'Panne / accident',
    'Problème de véhicule',
    'Urgence personnelle',
    'Trop loin / je ne peux pas livrer',
    'Autre',
  ];

  /// Hand the order back so another driver can take it.
  ///
  /// This is deliberately NOT a cancellation: the customer still wants their
  /// order, so it returns to the pool rather than dying. A driver who breaks
  /// down mid-delivery must be able to let go without the order being lost.
  ///
  /// Two cases, and the difference matters for money:
  ///  * **Before pickup** — the goods are still at the shop. Clearing
  ///    `driver_id` puts the order back in the available list and the next
  ///    driver collects from the shop as normal. Nothing is owed.
  ///  * **After pickup** — the goods are with *this* driver. The order still
  ///    returns to the pool (status rolls back so the next driver sees a
  ///    collectable job), but the first driver already burned fuel and time,
  ///    so a `driver_relay` settlement is recorded for the admin to credit to
  ///    his wallet. The customer is never charged twice — the relay is paid
  ///    by the platform, not re-billed.
  ///
  /// The driver's id is appended to `passed_driver_ids` either way, so the
  /// dispatcher does not immediately offer the same order straight back to
  /// the driver who just gave it up.
  Future<void> _releaseOrder(Order order) async {
    final afterPickup = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.onTheWay;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Je ne peux pas livrer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                afterPickup
                    ? 'La commande sera proposée à un autre livreur. '
                      'Vous serez payé pour le trajet déjà effectué — '
                      'le montant sera crédité sur votre solde par l\'admin.'
                    : 'La commande retournera à la liste des livraisons '
                      'disponibles. Aucune pénalité.',
                style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),
              ..._releaseReasons.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.pop(ctx, r),
                  )),
            ],
          ),
        ),
      ),
    );

    if (reason == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final driverId = await ref.read(currentDriverIdProvider.future);

      // Re-read the passed list so we append rather than clobber the drivers
      // who already declined this order.
      final row = await _supabase
          .from('orders')
          .select('passed_driver_ids')
          .eq('id', widget.orderId)
          .single();
      final passed = <String>{
        ...((row['passed_driver_ids'] as List?)?.cast<String>() ?? const []),
        if (driverId != null) driverId,
      }.toList();

      // Roll the order back to a collectable state and release the claim.
      // Guarded on driver_id so a stale screen cannot yank an order that has
      // already been reassigned to somebody else.
      final released = await _supabase
          .from('orders')
          .update({
            'driver_id': null,
            'assigned_driver_id': null,
            'status': 'ready',
            'passed_driver_ids': passed,
          })
          .eq('id', widget.orderId)
          .eq('driver_id', driverId as Object)
          .select('id');

      if ((released as List).isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Cette commande ne vous est plus assignée.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      // Close out this driver's delivery row so it stops tracking.
      if (_activeDeliveryId != null) {
        await _supabase
            .from('deliveries')
            .update({'status': 'cancelled'}).eq('id', _activeDeliveryId!);
      }

      // Owed for work already done: the admin settles this to the wallet.
      // Left `pending` on purpose — it is a claim for review, not a payment
      // the driver can grant himself.
      if (afterPickup && driverId != null) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('settlements').insert({
            'user_id': userId,
            'entity_type': 'driver',
            'amount': order.deliveryFee,
            'type': 'driver_relay',
            'status': 'pending',
            'description':
                'Trajet partiel #${widget.orderId.substring(0, 8).toUpperCase()} — $reason',
            'related_order_id': widget.orderId,
          });
        }
      }

      await BackgroundLocationService.stopTracking();

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(afterPickup
            ? 'Commande relayée. Votre trajet sera crédité par l\'admin.'
            : 'Commande remise en liste.'),
        backgroundColor: Colors.orange,
      ));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _startDelivery() async {
    await _supabase
        .from('orders')
        .update({'status': 'onTheWay'}).eq('id', widget.orderId);

    if (_activeDeliveryId != null) {
      await _supabase
          .from('deliveries')
          .update({'status': 'onTheWay'}).eq('id', _activeDeliveryId!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.deliveryStarted),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _confirmDelivery() async {
    await _supabase
        .from('orders')
        .update({'status': 'delivered'}).eq('id', widget.orderId);

    if (_activeDeliveryId != null) {
      await _supabase
          .from('deliveries')
          .update({'status': 'delivered'}).eq('id', _activeDeliveryId!);
    }

    // Mark cash-on-delivery payments as paid now that money was collected.
    try {
      await _supabase
          .from('payments')
          .update({'status': 'paid'})
          .eq('order_id', widget.orderId)
          .eq('method', 'cash');
    } catch (_) {}

    // Stop background location tracking — delivery is complete.
    await BackgroundLocationService.stopTracking();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.deliveryConfirmed),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderStreamProvider(widget.orderId));

    return orderAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.delivery)),
        body: Center(child: Text('Error: $e')),
      ),
      data: (order) => _buildScreen(order),
    );
  }

  /// The number to reach the customer on. Courier and facture orders carry
  /// the sender's own number; standard orders carry the account holder's.
  /// Falling back between them means the button is never missing just
  /// because one field happens to be empty for that order type.
  String? _customerPhone(Order order) {
    for (final p in [order.customerPhone, order.senderPhone, order.recipientPhone]) {
      if (p != null && p.trim().isNotEmpty) return p.trim();
    }
    return null;
  }

  bool _isFacture(Order order) =>
      order.type == OrderType.facture || order.type == OrderType.billPayment;

  Widget _buildScreen(Order order) {
    final l = AppLocalizations.of(context)!;
    final isFacture = _isFacture(order);
    final hasLocation = _myLat != null && _myLng != null;
    final deliveryLat = order.deliveryAddress.latitude;
    final deliveryLng = order.deliveryAddress.longitude;

    // Facture orders carry their own pickupAddress (the customer's place,
    // where cash is collected) directly on the order row. Standard food/
    // supermarket orders don't — their pickup point is the restaurant/
    // supermarket, resolved separately via _fetchPickupLocation since the
    // order row only has the id, not coordinates.
    final double? pickupLat = isFacture ? order.pickupAddress?.latitude : _pickupLat;
    final double? pickupLng = isFacture ? order.pickupAddress?.longitude : _pickupLng;
    final String pickupTitle = isFacture ? 'Chez le client' : (_pickupName ?? 'Point de retrait');
    final hasPickup = pickupLat != null && pickupLng != null;

    if (!isFacture) {
      // Fire-and-forget; the setState inside repaints once resolved.
      _fetchPickupLocation(order);
    }

    // Frame pickup + delivery + driver (whichever are known) once, on first
    // paint with a real driver fix, so the driver immediately sees both the
    // restaurant/client positions relative to themself instead of a map
    // centered arbitrarily. Mirrors the client app's own tracking screen.
    // Which leg is the driver on? Before collection the route runs to the
    // pickup point; once the order is picked up / on the way it runs to the
    // customer. Routing to the wrong leg would send them across town.
    final beforePickup = order.status != OrderStatus.pickedUp &&
        order.status != OrderStatus.onTheWay;
    final routeDestination = (beforePickup && hasPickup)
        ? (lat: pickupLat, lng: pickupLng)
        : (lat: deliveryLat, lng: deliveryLng);

    // Re-route on deviation rather than on distance covered: a driver
    // following the drawn line stays within GPS noise of it however far they
    // drive, while one who takes a different street is off it within a block
    // and gets a fresh line (and fresh street names) straight away.
    if (hasLocation) {
      final destinationChanged = _lastRouteDestination != routeDestination;
      final wentAnotherWay = RouteFreshness.isOffRoute(
        _route?.points,
        (lat: _myLat!, lng: _myLng!),
      );
      final rateLimitPassed = _lastRouteFetchAt == null ||
          DateTime.now().difference(_lastRouteFetchAt!) >
              RouteFreshness.kMinRefetchInterval;
      if (!_routeFetchInFlight &&
          (destinationChanged || (wentAnotherWay && rateLimitPassed))) {
        _fetchRoute(
          origin: (lat: _myLat!, lng: _myLng!),
          destination: routeDestination,
        );
      }
    }

    // Frame only the leg being driven, and reframe when the leg changes.
    //
    // Two problems with fitting all three points once: the driver heading to
    // the restaurant had the customer's address in frame too, which zooms the
    // map out far enough that the street they actually need is unreadable;
    // and because it ran once ever, collecting the order left the camera
    // still framed on the restaurant they had just left.
    //
    // Keying the guard on the destination makes it re-fit exactly when the
    // leg flips from pickup to drop-off, and not on every GPS tick.
    if (hasLocation && _fittedForLeg != routeDestination) {
      _fittedForLeg = routeDestination;
      final points = <({double lat, double lng})>[
        (lat: _myLat!, lng: _myLng!),
        routeDestination,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitBounds(points);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map — shows the driver's live position, the delivery/client
          // address, and (once resolved) the restaurant/supermarket pickup
          // point for standard orders or the customer's place for factures.
          AppMap(
            controller: _mapController,
            initialLatitude: hasLocation ? _myLat! : deliveryLat,
            initialLongitude: hasLocation ? _myLng! : deliveryLng,
            initialZoom: 14,
            // The amber driver badge already marks "you"; Google's blue dot on
            // top of it looked like a second, different position.
            showUserLocationPuck: false,
            polyline: _route?.points,
            // The details sheet covers the lower ~40% of the screen; telling
            // the map about it keeps Google's own controls (including the
            // my-location button) clear of the sheet and centres fitted
            // routes in the part still visible.
            contentPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.4,
            ),
            markers: {
              AppMapMarker(
                id: 'delivery',
                latitude: deliveryLat,
                longitude: deliveryLng,
                kind: AppMapMarkerKind.delivery,
                title: isFacture ? 'Bureau de paiement' : l.deliveryLocation,
              ),
              if (hasPickup)
                AppMapMarker(
                  id: 'pickup',
                  latitude: pickupLat,
                  longitude: pickupLng,
                  kind: AppMapMarkerKind.pickup,
                  title: pickupTitle,
                ),
              if (hasLocation)
                AppMapMarker(
                  id: 'driver',
                  latitude: _myLat!,
                  longitude: _myLng!,
                  kind: AppMapMarkerKind.driver,
                  title: l.you,
                  bearing: _myBearing,
                ),
            },
          ),

          // Recenter button — frames pickup + delivery + driver again, same
          // set of points as the initial auto-fit above.
          if (hasLocation)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.4 + 16,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  // Recenter on the CURRENT leg, matching what the auto-fit
                  // frames. Including the other end would zoom back out to
                  // the whole journey, which is what the driver pressed this
                  // button to get away from.
                  onTap: () => _mapController.fitBounds([
                    (lat: _myLat!, lng: _myLng!),
                    routeDestination,
                  ]),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
                  ),
                ),
              ),
            ),

          // Top back button, with the live navigation banner beside it so the
          // road to take and the ETA are readable without opening the sheet.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (_route != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NavBanner(
                        route: _route!,
                        toPickup: beforePickup && hasPickup,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom info sheet
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textLight.withValues(alpha:0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      isFacture ? 'Paiement de facture' : l.deliveringOrder,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // ── Facture details panel ──────────────────────────────
                    if (isFacture) ...[
                      _FactureDetailsPanel(order: order),
                      const SizedBox(height: 12),
                    ],

                    // ── Standard delivery address (bill office for facture) ─
                    _AddressCard(
                      icon: isFacture ? Icons.business_outlined : Icons.location_on,
                      iconColor: isFacture ? Colors.orange : AppColors.primary,
                      label: isFacture ? 'Bureau de paiement' : l.deliveryAddress,
                      address: order.deliveryAddress.fullAddress.isNotEmpty
                          ? order.deliveryAddress.fullAddress
                          : order.deliveryAddress.label,
                    ),
                    const SizedBox(height: 12),

                    // ── Customer contact ───────────────────────────────────
                    // Always visible while a delivery is live: a driver at a
                    // closed gate or a wrong building needs to reach the
                    // customer immediately, and hunting for the number in
                    // another screen costs minutes. WhatsApp sits beside the
                    // call button because it works when the customer has no
                    // credit or is on data only.
                    if (_customerPhone(order) != null) ...[
                      CustomerContact(
                        phone: _customerPhone(order)!,
                        label: order.customerName?.isNotEmpty == true
                            ? 'Client — ${order.customerName}'
                            : 'Client',
                        whatsappMessage:
                            'Bonjour, je suis votre livreur Amana pour la '
                            'commande #${order.id.substring(0, 6).toUpperCase()}.',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Payment info row
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 18, color: AppColors.textLight),
                        const SizedBox(width: 8),
                        Text(order.paymentMethod, style: const TextStyle(color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.formatPrice(order.total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                      ],
                    ),

                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.note_outlined, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(order.notes!, style: const TextStyle(color: Colors.orange))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Action buttons ────────────────────────────────────

                    // "Cash collected" / "Picked up" button
                    if (order.status != OrderStatus.pickedUp &&
                        order.status != OrderStatus.onTheWay &&
                        order.status != OrderStatus.delivered)
                      _ActionButton(
                        label: isFacture ? 'Espèces collectées' : l.markPickedUp,
                        icon: isFacture ? Icons.payments_rounded : Icons.shopping_bag_outlined,
                        color: Colors.orange,
                        onPressed: _markPickedUp,
                      ),

                    // "Head to bill office" / "Start delivery" button
                    if (order.status == OrderStatus.pickedUp) ...[
                      // For facture: show receipt upload here too (driver is at office)
                      if (isFacture) ...[
                        _ReceiptUploadSection(
                          receiptUrl: order.receiptPhotoUrl,
                          uploading: _uploadingReceipt,
                          onUpload: _uploadReceipt,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ActionButton(
                        label: isFacture ? 'En route vers le bureau' : l.startDelivery,
                        icon: isFacture ? Icons.directions_car_rounded : Icons.directions_car_rounded,
                        color: Colors.blue,
                        onPressed: _startDelivery,
                      ),
                    ],

                    // Receipt upload + confirm for facture (onTheWay = at the office)
                    if (isFacture && order.status == OrderStatus.onTheWay) ...[
                      _ReceiptUploadSection(
                        receiptUrl: order.receiptPhotoUrl,
                        uploading: _uploadingReceipt,
                        onUpload: _uploadReceipt,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Non-facture: standard confirm delivery button
                    if (!isFacture && order.status == OrderStatus.onTheWay)
                      _ActionButton(
                        label: l.confirmDelivery,
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        onPressed: _confirmDelivery,
                      ),

                    // Facture: confirm only after receipt uploaded
                    if (isFacture && order.status == OrderStatus.onTheWay) ...[
                      _ActionButton(
                        label: 'Facture payée — Terminer',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        onPressed: _confirmDelivery,
                      ),
                    ],

                    // Escape hatch for a driver who cannot finish: breakdown,
                    // accident, emergency. Available right up to delivery,
                    // because that is exactly when things go wrong.
                    if (order.status != OrderStatus.delivered &&
                        order.status != OrderStatus.cancelled) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _releaseOrder(order),
                          icon: const Icon(Icons.report_problem_outlined, size: 20),
                          label: const Text('Je ne peux pas livrer',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],

                    if (order.status == OrderStatus.delivered)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Text(
                              isFacture ? 'Facture payée avec succès !' : l.deliveryCompleted,
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Helper sub-widgets ────────────────────────────────────────────────────────

/// Orange-bordered info card showing a labelled address with an icon.
/// Compact navigation banner pinned to the top of the driver's map: the road
/// to take next, plus the traffic-aware ETA and remaining distance for the
/// leg they are on. Redrawn whenever the route is re-fetched, so taking a
/// different street updates this immediately.
class _NavBanner extends StatelessWidget {
  final AppRoute route;

  /// True while the driver is still heading to the collection point, which
  /// changes what the banner says they are driving towards.
  final bool toPickup;

  const _NavBanner({required this.route, required this.toPickup});

  @override
  Widget build(BuildContext context) {
    final street = route.currentStreet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                toPickup ? Icons.storefront_rounded : Icons.home_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${route.etaLabel} • ${route.distanceLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (street != null) ...[
            const SizedBox(height: 2),
            Text(
              street,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _AddressCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(address, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full facture details panel: bill type, reference, amount, addresses,
/// customer phone (with call button), and bill photo if uploaded.
class _FactureDetailsPanel extends StatelessWidget {
  final Order order;
  const _FactureDetailsPanel({required this.order});

  String _billTypeLabel(String? type) => switch (type?.toLowerCase()) {
        'topnet' => '🌐 Topnet',
        'steg'   => '⚡ STEG',
        'sonede' => '💧 SONEDE',
        _        => '🧾 Autre',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill type header
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                _billTypeLabel(order.billType),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
              ),
            ],
          ),

          if (order.billReference != null) ...[
            const SizedBox(height: 8),
            _Row(icon: Icons.tag_rounded, label: 'Référence', value: order.billReference!),
          ],

          if (order.billAmount != null) ...[
            const SizedBox(height: 6),
            _Row(
              icon: Icons.payments_outlined,
              label: 'Montant à collecter',
              value: '${order.billAmount!.toStringAsFixed(3)} TND',
              valueStyle: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],

          // Customer address (where driver collects cash)
          if (order.pickupAddress != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.home_outlined,
              label: '1. Chez le client',
              value: order.pickupAddress!.fullAddress.isNotEmpty
                  ? order.pickupAddress!.fullAddress
                  : order.pickupAddress!.label,
            ),
          ],

          // Customer phone
          if (order.senderPhone != null && order.senderPhone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                const Text('Client: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                _TapToCallButton(phone: order.senderPhone!),
              ],
            ),
          ],

          // Bill photo (customer-uploaded reference photo of their bill)
          if (order.billPhotoUrl != null && order.billPhotoUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Photo de la facture (référence)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                order.billPhotoUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 140,
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  height: 60,
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Receipt upload section: shows an upload button or the uploaded receipt image.
class _ReceiptUploadSection extends StatelessWidget {
  final String? receiptUrl;
  final bool uploading;
  final VoidCallback onUpload;

  const _ReceiptUploadSection({
    required this.receiptUrl,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (receiptUrl != null && receiptUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text('Reçu uploadé', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              receiptUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: uploading ? null : onUpload,
        icon: uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
            : const Icon(Icons.upload_rounded, color: Colors.orange),
        label: Text(
          uploading ? 'Upload en cours…' : 'Uploader le reçu de paiement',
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orange, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Reusable action button (picked-up / start delivery / confirm).
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

/// Tap-to-call phone number chip (green, compact).
class _TapToCallButton extends StatelessWidget {
  final String phone;
  const _TapToCallButton({required this.phone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(phone, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _Row({required this.icon, required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textLight),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
