import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../authentication/providers/auth_provider.dart';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return FirebaseVendorRepository(firebaseService);
});

final vendorsStreamProvider = StreamProvider<List<VendorModel>>((ref) {
  final repository = ref.watch(vendorRepositoryProvider);
  return repository.watchVendors(includeArchived: false);
});

class VendorSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final vendorSearchQueryProvider =
    NotifierProvider<VendorSearchNotifier, String>(() {
  return VendorSearchNotifier();
});

final filteredVendorsProvider = Provider<List<VendorModel>>((ref) {
  final vendorsAsync = ref.watch(vendorsStreamProvider);
  final query = ref.watch(vendorSearchQueryProvider).trim().toLowerCase();

  return vendorsAsync.when(
    data: (vendors) {
      if (query.isEmpty) return vendors;
      return vendors.where((v) {
        return v.vendorName.toLowerCase().contains(query) ||
            v.companyName.toLowerCase().contains(query) ||
            v.phoneNumber.toLowerCase().contains(query) ||
            v.address.toLowerCase().contains(query);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
