import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/menu_provider.dart';

class HappyHourSetupScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final double originalPrice;
  final bool isGrocery;
  final double? currentDiscountPrice;
  final DateTime? currentEndTime;
  final int? currentQuantity;

  const HappyHourSetupScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.originalPrice,
    required this.isGrocery,
    this.currentDiscountPrice,
    this.currentEndTime,
    this.currentQuantity,
  });

  @override
  ConsumerState<HappyHourSetupScreen> createState() => _HappyHourSetupScreenState();
}

class _HappyHourSetupScreenState extends ConsumerState<HappyHourSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  DateTime? _selectedEndTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentDiscountPrice?.toStringAsFixed(2) ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.currentQuantity?.toString() ?? '',
    );
    _selectedEndTime = widget.currentEndTime;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  double get _discountPercent {
    final dp = double.tryParse(_priceController.text);
    if (dp == null || dp <= 0 || dp >= widget.originalPrice) return 0;
    return ((widget.originalPrice - dp) / widget.originalPrice * 100);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndTime ?? DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _selectedEndTime ?? DateTime.now().add(const Duration(hours: 2))),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedEndTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEndTime == null) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.selectEndDateTime),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(menuRepositoryProvider);
    final ok = await repo.setHappyHour(
      itemId: widget.itemId,
      isGrocery: widget.isGrocery,
      discountPrice: double.parse(_priceController.text),
      endTime: _selectedEndTime!,
      quantity: int.tryParse(_quantityController.text),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      final l = AppLocalizations.of(context)!;
      if (ok) {
        ref.invalidate(menuItemsProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.happyHourActivated),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.happyHourFailed),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clear() async {
    setState(() => _isLoading = true);
    final repo = ref.read(menuRepositoryProvider);
    final ok = await repo.clearHappyHour(widget.itemId, widget.isGrocery);
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        final l = AppLocalizations.of(context)!;
        ref.invalidate(menuItemsProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.happyHourCleared),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentDiscountPrice != null && widget.currentEndTime != null;
    final percent = _discountPercent;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.happyHourSetup),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, AppColors.secondaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.itemName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            'Original price: ${widget.originalPrice.toStringAsFixed(2)} DT',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (percent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${percent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(l.discountPriceDt,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration(
                    hint: 'e.g. 12.99', icon: Icons.price_change_rounded),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a discount price';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'Enter a valid price';
                  if (d >= widget.originalPrice) {
                    return 'Must be less than original price (${widget.originalPrice.toStringAsFixed(2)} DT)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              Text(l.endDateTime,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedEndTime != null
                          ? AppColors.secondary
                          : AppColors.textLight.withOpacity(0.2),
                      width: _selectedEndTime != null ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: _selectedEndTime != null
                              ? AppColors.secondary
                              : AppColors.textLight,
                          size: 22),
                      const SizedBox(width: 12),
                      Text(
                        _selectedEndTime != null
                            ? _formatDateTime(_selectedEndTime!)
                            : l.tapSelectEndDateTime,
                        style: TextStyle(
                          color: _selectedEndTime != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                          fontWeight: _selectedEndTime != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(l.availableUnitsOptional,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                    hint: l.leaveBlankUnlimited, icon: Icons.inventory_2_rounded),
              ),

              const SizedBox(height: 32),

              // Activate button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _activate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.local_fire_department_rounded),
                  label: Text(l.activateHappyHour,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: AppColors.secondary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              if (isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _clear,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(l.clearHappyHour,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Once activated, customers on Cmandili app will see this deal immediately.',
                        style: TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textLight),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.15), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $h:$m';
  }
}
