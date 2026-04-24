import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/partner_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final partnerProfileProvider = FutureProvider<PartnerProfile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.read(authRepositoryProvider).fetchPartnerProfile();
});
