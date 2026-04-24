import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/address_provider.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _showAddAddressDialog(context, ref),
          ),
        ],
      ),
      body: addresses.isEmpty
          ? const Center(child: Text('No addresses saved'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Dismissible(
                  key: Key(address.id),
                  direction: DismissDirection.endToStart,
                  background: _buildDeleteBackground(),
                  onDismissed: (direction) {
                    ref.read(addressProvider.notifier).deleteAddress(address.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address removed')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(
                        address.isDefault ? Icons.home_filled : Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(address.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(address.fullAddress),
                      trailing: address.isDefault
                          ? const Chip(
                              label: Text('Default', style: TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: AppColors.primary,
                            )
                          : TextButton(
                              onPressed: () {
                                ref.read(addressProvider.notifier).setDefault(address.id);
                              },
                              child: const Text('Set Default'),
                            ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  void _showAddAddressDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Label (e.g., Home, Work)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Full Address'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && addressController.text.isNotEmpty) {
                ref.read(addressProvider.notifier).addAddress(
                      nameController.text,
                      addressController.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
