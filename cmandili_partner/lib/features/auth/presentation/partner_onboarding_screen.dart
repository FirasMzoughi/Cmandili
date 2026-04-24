import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class PartnerOnboardingScreen extends ConsumerStatefulWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  ConsumerState<PartnerOnboardingScreen> createState() => _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends ConsumerState<PartnerOnboardingScreen> {
  final _nameController = TextEditingController();
  String _partnerType = 'restaurant';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).completeOnboarding(
        _nameController.text.trim(),
        _partnerType,
      );
      // Invalidate the profile provider so the home screen will transition to the dashboard
      ref.invalidate(partnerProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please provide your business details to continue.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Business Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _partnerType,
              items: const [
                DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
                DropdownMenuItem(value: 'supermarket', child: Text('Supermarket')),
              ],
              onChanged: (val) => setState(() => _partnerType = val ?? 'restaurant'),
              decoration: const InputDecoration(
                labelText: 'Business Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
