import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
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
  File? _pickedLogo;
  String? _existingLogoUrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _prefill();
    _loadExistingLogo();
  }

  void _prefill() {
    final profile = ref.read(partnerProfileProvider).value;
    if (profile == null) return;
    _nameCtrl.text = profile.businessName;
    _addressCtrl.text = profile.address;
    _phoneCtrl.text = profile.phone ?? '';
    _bioCtrl.text = profile.bio ?? '';
  }

  Future<void> _loadExistingLogo() async {
    final profile = ref.read(partnerProfileProvider).value;
    if (profile == null || profile.entityId.isEmpty) return;
    try {
      final table = profile.partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';
      final row = await Supabase.instance.client
          .from(table)
          .select('image_url')
          .eq('id', profile.entityId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _existingLogoUrl = (row?['image_url'] as String?)?.trim().isEmpty == false
            ? row!['image_url'] as String
            : null;
      });
    } catch (_) {}
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pickedLogo = File(picked.path));
  }

  /// Uploads the picked logo to the `items` bucket and returns the public URL.
  /// Reuses `items` (already public) instead of creating a new bucket.
  Future<String?> _uploadLogo(String entityId) async {
    if (_pickedLogo == null) return null;
    final supabase = Supabase.instance.client;
    final ext = _pickedLogo!.path.split('.').last.toLowerCase();
    final path = '$entityId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('items').upload(
          path,
          _pickedLogo!,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from('items').getPublicUrl(path);
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
      final profile = ref.read(partnerProfileProvider).value;

      await Supabase.instance.client.from('partners').update({
        'business_name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      }).eq('user_id', userId);

      // If a new logo was picked, upload it and patch the restaurants/supermarkets
      // row directly so the customer app's restaurant card can show it.
      if (_pickedLogo != null && profile != null && profile.entityId.isNotEmpty) {
        final logoUrl = await _uploadLogo(profile.entityId);
        if (logoUrl != null) {
          final table = profile.partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';
          await Supabase.instance.client
              .from(table)
              .update({'image_url': logoUrl})
              .eq('id', profile.entityId);
          if (mounted) {
            setState(() {
              _existingLogoUrl = logoUrl;
              _pickedLogo = null;
            });
          }
        }
      }

      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.businessInfoUpdated), backgroundColor: Colors.green),
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
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.businessInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Center(child: _buildLogoPicker()),
              const SizedBox(height: 24),
              _field(
                controller: _nameCtrl,
                label: AppLocalizations.of(context)!.businessName,
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
                      : Text(l.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: _pickLogo,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pickedLogo != null
                ? Image.file(_pickedLogo!, fit: BoxFit.cover)
                : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _existingLogoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.storefront_outlined,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                      )
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: AppColors.textLight,
                      )),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ],
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
