import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  String _vehicleType = 'motorcycle';
  bool _saving = false;
  bool _loading = true;

  static const _types = ['motorcycle', 'car', 'bicycle', 'scooter'];

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
          .from('drivers')
          .select('vehicle_type, vehicle_make, vehicle_model, vehicle_plate, vehicle_color')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        _vehicleType = row['vehicle_type'] as String? ?? 'motorcycle';
        _makeCtrl.text = row['vehicle_make'] as String? ?? '';
        _modelCtrl.text = row['vehicle_model'] as String? ?? '';
        _plateCtrl.text = row['vehicle_plate'] as String? ?? '';
        _colorCtrl.text = row['vehicle_color'] as String? ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';
      await Supabase.instance.client.from('drivers').update({
        'vehicle_type': _vehicleType,
        'vehicle_make': _makeCtrl.text.trim(),
        'vehicle_model': _modelCtrl.text.trim(),
        'vehicle_plate': _plateCtrl.text.trim(),
        'vehicle_color': _colorCtrl.text.trim(),
      }).eq('user_id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle info updated'), backgroundColor: Colors.green),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Info', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vehicle type selector
                    const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: _types.map((t) {
                        final selected = t == _vehicleType;
                        return ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _vehicleType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _field(controller: _makeCtrl, label: 'Make (e.g. Yamaha)', icon: Icons.directions_car_outlined,
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                    const SizedBox(height: 16),
                    _field(controller: _modelCtrl, label: 'Model (e.g. NMAX)', icon: Icons.two_wheeler_rounded),
                    const SizedBox(height: 16),
                    _field(controller: _plateCtrl, label: 'License Plate', icon: Icons.credit_card_outlined,
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                    const SizedBox(height: 16),
                    _field(controller: _colorCtrl, label: 'Color', icon: Icons.palette_outlined),
                    const SizedBox(height: 32),
                    SizedBox(
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
                            : const Text('Save Vehicle Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
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
