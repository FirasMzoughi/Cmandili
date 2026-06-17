import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/push/push_service.dart';
import '../../orders/presentation/available_orders_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../orders/presentation/widgets/order_offer_dialog.dart';
import '../../orders/providers/driver_online_provider.dart';
import '../../orders/providers/driver_orders_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../earnings/presentation/earnings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<OrderOffer>? _offerSub;
  bool _offerOpen = false; // guards against stacking dialogs on rapid pushes

  @override
  void initState() {
    super.initState();
    // Listen for 10s order offers pushed by the backend. Subscribed here in
    // the home screen because offers are app-wide — not specific to any tab —
    // and the home screen lives for the duration of the authenticated
    // session, matching the lifetime we want for the listener.
    _offerSub = PushService.instance.offerStream.listen(_onOffer);
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    super.dispose();
  }

  Future<void> _onOffer(OrderOffer offer) async {
    if (!mounted || _offerOpen) return;
    _offerOpen = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrderOfferDialog(orderId: offer.orderId),
      );
      // On accept, jump to the orders tab so the driver sees the offer card
      // in context and can tap "Accept Order" — the existing accept flow
      // (delivery row + driver_id) is unchanged.
      if (accepted == true && mounted) {
        setState(() => _selectedIndex = 1);
        // Force the available-orders list to refresh in case streaming hasn't
        // surfaced the assigned order yet.
        ref.invalidate(availableOrdersProvider);
      }
    } finally {
      _offerOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDeliveryAsync = ref.watch(activeDeliveryProvider);
    final l = AppLocalizations.of(context)!;

    final pages = [
      _DashboardTab(onGoToOrders: () => setState(() => _selectedIndex = 1)),
      const AvailableOrdersScreen(),
      // Active delivery tab: show tracking if active, else placeholder
      activeDeliveryAsync.when(
        data: (order) => order != null
            ? OrderTrackingScreen(orderId: order.id)
            : _NoActiveDelivery(onBrowse: () => setState(() => _selectedIndex = 1)),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => _NoActiveDelivery(onBrowse: () => setState(() => _selectedIndex = 1)),
      ),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(index: 0, icon: Icons.dashboard_rounded, label: l.home, selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
              _NavItem(index: 1, icon: Icons.delivery_dining_rounded, label: l.orders, selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
              _NavItem(index: 2, icon: Icons.navigation_rounded, label: l.active, selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              _NavItem(index: 3, icon: Icons.account_balance_wallet_rounded, label: l.earnings, selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
              _NavItem(index: 4, icon: Icons.person_rounded, label: l.profile, selected: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.index, required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onGoToOrders;
  const _DashboardTab({required this.onGoToOrders});

  @override
  ConsumerState<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<_DashboardTab> {
  final AppMapController _mapController = AppMapController();
  StreamSubscription<Position>? _positionStream;
  double? _myLat;
  double? _myLng;
  String? _locationError;
  bool _firstFixApplied = false;
  String? _placeName;
  String? _cityName;
  // Throttle reverse-geocoding: don't hit the platform geocoder on every GPS
  // tick — only when the user has moved >100m from the last reverse-lookup.
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    // Verify the OS-level location switch is on. If not, GPS will return
    // a useless fallback (or nothing) — surface that to the user.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _locationError = AppLocalizations.of(context)!.locationOff);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationError = AppLocalizations.of(context)!.locationDeniedSettings);
      return;
    }

    // Force a FRESH high-accuracy GPS fix (no cached/last-known fallback) so
    // we don't anchor the map on a stale location reported by the OS.
    try {
      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: false,
      );
      _applyFix(fresh);
    } catch (_) {
      // Fall through — the position stream below will deliver a fix soon.
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _applyFix(pos);
    });
  }

  void _applyFix(Position pos) {
    if (!mounted) return;
    setState(() {
      _myLat = pos.latitude;
      _myLng = pos.longitude;
      _locationError = null;
    });
    if (!_firstFixApplied) {
      _firstFixApplied = true;
      _mapController.animateToPoint(pos.latitude, pos.longitude, zoom: 16);
    }
    _maybeResolveAddress(pos.latitude, pos.longitude);
  }

  Future<void> _maybeResolveAddress(double lat, double lng) async {
    if (_lastGeocodedLat != null && _lastGeocodedLng != null) {
      final movedMeters = Geolocator.distanceBetween(
        _lastGeocodedLat!, _lastGeocodedLng!, lat, lng,
      );
      if (movedMeters < 100) return;
    }
    _lastGeocodedLat = lat;
    _lastGeocodedLng = lng;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final street = [p.street, p.subLocality]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      final city = p.locality?.isNotEmpty == true
          ? p.locality
          : (p.subAdministrativeArea?.isNotEmpty == true
              ? p.subAdministrativeArea
              : p.administrativeArea);
      setState(() {
        _placeName = street.isNotEmpty ? street : null;
        _cityName = city;
      });
    } catch (_) {
      // Reverse geocoding can fail offline / rate-limited — leave previous values.
    }
  }

  void _recenter() {
    if (_myLat != null && _myLng != null) {
      _mapController.animateToPoint(_myLat!, _myLng!, zoom: 16);
    }
  }

  void _openFullscreenMap() {
    if (_myLat == null || _myLng == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenMapScreen(
          initialLat: _myLat!,
          initialLng: _myLng!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final activeAsync = ref.watch(activeDeliveryProvider);
    final availableAsync = ref.watch(availableOrdersProvider);

    final isOnline = ref.watch(driverOnlineProvider);
    final availableCount = availableAsync.value?.length ?? 0;
    final hasActive = activeAsync.value != null;
    final hasLocation = _myLat != null && _myLng != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.driverDashboard,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            _OnlineStatusPill(isOnline: isOnline),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: isOnline,
                              activeColor: Colors.white,
                              activeTrackColor: Colors.green.shade400,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              onChanged: (next) =>
                                  ref.read(driverOnlineProvider.notifier).setOnline(next),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasActive
                              ? l.youHaveActiveDelivery
                              : (isOnline ? l.readyForOrders : l.youreOfflineFlip),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        if (_cityName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _cityName!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            _HeaderStat(label: l.available, value: '$availableCount'),
                            const SizedBox(width: 1),
                            Container(width: 1, height: 32, color: Colors.white24),
                            const SizedBox(width: 1),
                            _HeaderStat(label: l.active, value: hasActive ? '1' : '0'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasActive) ...[
                    Text(l.activeDelivery, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _ActiveDeliveryCard(order: activeAsync.value!),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: Text(l.yourLocation, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      if (hasLocation)
                        TextButton.icon(
                          onPressed: _openFullscreenMap,
                          icon: const Icon(Icons.open_in_full, size: 16),
                          label: Text(l.expand),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                  if (_placeName != null || _cityName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [_placeName, _cityName].where((s) => s != null && s.isNotEmpty).join(' • '),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 280,
                      child: hasLocation
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: AppMap(
                                    controller: _mapController,
                                    initialLatitude: _myLat!,
                                    initialLongitude: _myLng!,
                                    initialZoom: 15,
                                    showUserLocationPuck: true,
                                    markers: {
                                      AppMapMarker(
                                        id: 'driver',
                                        latitude: _myLat!,
                                        longitude: _myLng!,
                                        kind: AppMapMarkerKind.driver,
                                        title: l.you,
                                      ),
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: _MapMiniButton(
                                    icon: Icons.my_location,
                                    onTap: _recenter,
                                    tooltip: 'Recenter',
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: AppColors.background,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _locationError != null ? Icons.location_off : Icons.location_searching,
                                    color: AppColors.textLight,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _locationError ?? 'Locating you…',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Available Orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$availableCount order(s) waiting for a driver', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: widget.onGoToOrders,
                      icon: const Icon(Icons.delivery_dining_rounded),
                      label: const Text('View Available Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final dynamic order;
  const _ActiveDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.id.toString().substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryAddress?.fullAddress ?? order.deliveryAddress?.label ?? '',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(AppLocalizations.of(context)!.onTheWay, style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _NoActiveDelivery extends StatelessWidget {
  final VoidCallback onBrowse;
  const _NoActiveDelivery({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(l.noActiveDelivery, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(l.acceptOrderToStart, style: const TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onBrowse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.browseAvailableOrders),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapMiniButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _FullscreenMapScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  const _FullscreenMapScreen({required this.initialLat, required this.initialLng});

  @override
  State<_FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<_FullscreenMapScreen> {
  final AppMapController _controller = AppMapController();
  StreamSubscription<Position>? _positionStream;
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;

  @override
  void initState() {
    super.initState();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _recenter() => _controller.animateToPoint(_lat, _lng, zoom: 16);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _controller,
              initialLatitude: widget.initialLat,
              initialLongitude: widget.initialLng,
              initialZoom: 15,
              showUserLocationPuck: true,
              markers: {
                AppMapMarker(
                  id: 'driver',
                  latitude: _lat,
                  longitude: _lng,
                  kind: AppMapMarkerKind.driver,
                  title: AppLocalizations.of(context)!.you,
                ),
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _MapMiniButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _MapMiniButton(
              icon: Icons.my_location,
              onTap: _recenter,
              tooltip: 'Recenter',
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineStatusPill extends StatelessWidget {
  final bool isOnline;
  const _OnlineStatusPill({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.greenAccent : Colors.white60,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
