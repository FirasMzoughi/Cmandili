import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/widgets/app_map.dart';
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
  String? _activeDeliveryId;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Subscribe first to resolve _activeDeliveryId, THEN start GPS.
    // This prevents the race condition where early GPS updates are discarded
    // because _activeDeliveryId is still null.
    _subscribeToDelivery().then((_) => _startLocationTracking());
  }

  Future<void> _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
      });
      _mapController.animateToPoint(pos.latitude, pos.longitude);

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

  @override
  void dispose() {
    _positionStream?.cancel();
    _deliveryStream?.cancel();
    _mapController.dispose();
    super.dispose();
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

  Widget _buildScreen(Order order) {
    final l = AppLocalizations.of(context)!;
    final hasLocation = _myLat != null && _myLng != null;
    final deliveryLat = order.deliveryAddress.latitude;
    final deliveryLng = order.deliveryAddress.longitude;

    return Scaffold(
      body: Stack(
        children: [
          // Map showing driver position and delivery destination
          AppMap(
            controller: _mapController,
            initialLatitude: hasLocation ? _myLat! : deliveryLat,
            initialLongitude: hasLocation ? _myLng! : deliveryLng,
            initialZoom: 14,
            showUserLocationPuck: true,
            markers: {
              AppMapMarker(
                id: 'delivery',
                latitude: deliveryLat,
                longitude: deliveryLng,
                kind: AppMapMarkerKind.delivery,
                title: l.deliveryLocation,
              ),
              if (hasLocation)
                AppMapMarker(
                  id: 'driver',
                  latitude: _myLat!,
                  longitude: _myLng!,
                  kind: AppMapMarkerKind.driver,
                  title: l.you,
                ),
            },
          ),

          // Top back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
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
                      l.deliveringOrder,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Delivery address
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.deliveryAddress,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  order.deliveryAddress.fullAddress.isNotEmpty
                                      ? order.deliveryAddress.fullAddress
                                      : order.deliveryAddress.label,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment info
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 18, color: AppColors.textLight),
                        const SizedBox(width: 8),
                        Text(order.paymentMethod,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.formatPrice(order.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary),
                        ),
                      ],
                    ),

                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha:0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.note_outlined,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(order.notes!,
                                  style: const TextStyle(
                                      color: Colors.orange)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Picked Up Button
                    if (order.status != OrderStatus.pickedUp && 
                        order.status != OrderStatus.onTheWay && 
                        order.status != OrderStatus.delivered)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _markPickedUp,
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            l.markPickedUp,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    
                    // Start Delivery Button
                    if (order.status == OrderStatus.pickedUp)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _startDelivery,
                          icon: const Icon(Icons.directions_car_rounded),
                          label: Text(
                            l.startDelivery,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    // Confirm delivery button
                    if (order.status == OrderStatus.onTheWay)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _confirmDelivery,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            l.confirmDelivery,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    if (order.status == OrderStatus.delivered)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Text(l.deliveryCompleted,
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
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
