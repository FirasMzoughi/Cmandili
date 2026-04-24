import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/providers/driver_orders_provider.dart';

// Tracks driver online state so the toggle can reflect it in real time.
final _driverOnlineProvider = StateNotifierProvider<_OnlineNotifier, bool>((ref) {
  return _OnlineNotifier(ref);
});

class _OnlineNotifier extends StateNotifier<bool> {
  final Ref _ref;
  _OnlineNotifier(this._ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    final driverId = await _ref.read(currentDriverIdProvider.future);
    if (driverId == null) return;
    final row = await Supabase.instance.client
        .from('drivers')
        .select('is_online')
        .eq('id', driverId)
        .maybeSingle();
    if (mounted) state = row?['is_online'] as bool? ?? false;
  }

  Future<void> toggle() async {
    final driverId = await _ref.read(currentDriverIdProvider.future);
    if (driverId == null) return;
    final next = !state;
    state = next;
    await Supabase.instance.client
        .from('drivers')
        .update({'is_online': next})
        .eq('id', driverId);
  }
}

class DriverPayoutScreen extends ConsumerStatefulWidget {
  const DriverPayoutScreen({super.key});

  @override
  ConsumerState<DriverPayoutScreen> createState() => _DriverPayoutScreenState();
}

class _DriverPayoutScreenState extends ConsumerState<DriverPayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) { setState(() => _loading = false); return; }
    try {
      final row = await Supabase.instance.client
          .from('driver_payout_info')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        _bankNameCtrl.text = row['bank_name'] as String? ?? '';
        _ibanCtrl.text = row['iban'] as String? ?? '';
        _accountHolderCtrl.text = row['account_holder'] as String? ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _ibanCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';
      await Supabase.instance.client.from('driver_payout_info').upsert({
        'user_id': userId,
        'bank_name': _bankNameCtrl.text.trim(),
        'iban': _ibanCtrl.text.trim(),
        'account_holder': _accountHolderCtrl.text.trim(),
      }, onConflict: 'user_id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout info saved'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(_driverOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Status', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Online/Offline toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOnline ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOnline ? 'You are Online' : 'You are Offline',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                isOnline ? 'You can receive new orders' : 'Turn on to receive orders',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isOnline,
                          activeColor: Colors.green,
                          onChanged: (_) => ref.read(_driverOnlineProvider.notifier).toggle(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text('Bank Payout Info',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Payouts are sent weekly to your bank account.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(controller: _accountHolderCtrl, label: 'Account Holder Name',
                            icon: Icons.person_outline, validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                        _field(controller: _bankNameCtrl, label: 'Bank Name',
                            icon: Icons.account_balance_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                        _field(controller: _ibanCtrl, label: 'IBAN / RIB',
                            icon: Icons.credit_card_outlined,
                            validator: (v) => v!.length < 10 ? 'Enter a valid IBAN/RIB' : null),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _saving
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Payout Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
