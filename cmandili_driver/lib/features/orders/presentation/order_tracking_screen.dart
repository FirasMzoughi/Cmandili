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
  bool _uploadingReceipt = false;
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

  String _billTypeLabel(String? type) {
    return switch (type?.toLowerCase()) {
      'topnet' => '🌐 Topnet',
      'steg'   => '⚡ STEG',
      'sonede' => '💧 SONEDE',
      _        => '🧾 Autre',
    };
  }

  bool _isFacture(Order order) =>
      order.type == OrderType.facture || order.type == OrderType.billPayment;

  Widget _buildScreen(Order order) {
    final l = AppLocalizations.of(context)!;
    final isFacture = _isFacture(order);
    final hasLocation = _myLat != null && _myLng != null;
    final deliveryLat = order.deliveryAddress.latitude;
    final deliveryLng = order.deliveryAddress.longitude;

    return Scaffold(
      body: Stack(
        children: [
          // Map — for facture orders show both customer address and bill office
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
                title: isFacture ? 'Bureau de paiement' : l.deliveryLocation,
              ),
              if (isFacture && order.pickupAddress != null)
                AppMapMarker(
                  id: 'pickup',
                  latitude: order.pickupAddress!.latitude,
                  longitude: order.pickupAddress!.longitude,
                  kind: AppMapMarkerKind.pickup,
                  title: 'Chez le client',
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
