import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class BusinessInfoScreen extends ConsumerStatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  ConsumerState<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends ConsumerState<BusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _prefill();
  }

  void _prefill() {
    final profile = ref.read(partnerProfileProvider).value;
    if (profile == null) return;
    _nameCtrl.text = profile.businessName;
    _addressCtrl.text = profile.address;
    _phoneCtrl.text = profile.phone ?? '';
    _bioCtrl.text = profile.bio ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';
      await Supabase.instance.client.from('partners').update({
        'business_name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      }).eq('user_id', userId);

      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business info updated'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Info', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _nameCtrl,
                label: 'Business Name',
                icon: Icons.store_rounded,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _addressCtrl,
                label: 'Business Address',
                icon: Icons.location_on_outlined,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _phoneCtrl,
                label: 'Contact Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _bioCtrl,
                label: 'Business Description',
                icon: Icons.info_outline,
                maxLines: 4,
              ),
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
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
