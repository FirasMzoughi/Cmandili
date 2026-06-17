import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import 'menu_provider.dart';

class MenuScannerState {
  final bool isLoading;
  final String? error;
  final int? itemsAddedCount;

  MenuScannerState({
    this.isLoading = false,
    this.error,
    this.itemsAddedCount,
  });

  MenuScannerState copyWith({
    bool? isLoading,
    String? error,
    int? itemsAddedCount,
  }) {
    return MenuScannerState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      itemsAddedCount: itemsAddedCount,
    );
  }
}

class MenuScannerNotifier extends StateNotifier<MenuScannerState> {
  final Ref _ref;

  MenuScannerNotifier(this._ref) : super(MenuScannerState());

  Future<void> scanPhysicalMenu({required ImageSource source}) async {
    final profile = _ref.read(partnerProfileProvider).value;
    if (profile == null) {
      state = state.copyWith(error: 'Partner profile not loaded', isLoading: false);
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75, // Smaller payload → fewer Gemini 400 errors
      );

      if (image == null) return; // User cancelled

      state = state.copyWith(isLoading: true, error: null);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final repo = _ref.read(menuRepositoryProvider);
      
      final count = await repo.scanMenu(
        base64Image: base64Image,
        partnerId: profile.entityId,
        partnerType: profile.partnerType,
      );

      state = state.copyWith(isLoading: false, itemsAddedCount: count);
      // Refresh the menu list
      _ref.invalidate(menuItemsProvider);
    } catch (e) {
      // e.toString() will contain the exception message we threw in the repository
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  void resetState() {
    state = MenuScannerState();
  }
}

final menuScannerProvider = StateNotifierProvider<MenuScannerNotifier, MenuScannerState>((ref) {
  return MenuScannerNotifier(ref);
});
