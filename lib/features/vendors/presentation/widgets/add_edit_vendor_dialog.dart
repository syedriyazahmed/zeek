import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../data/models/vendor_model.dart';
import '../../providers/vendor_provider.dart';

class AddEditVendorDialog extends ConsumerStatefulWidget {
  final VendorModel? vendor;

  const AddEditVendorDialog({super.key, this.vendor});

  @override
  ConsumerState<AddEditVendorDialog> createState() => _AddEditVendorDialogState();
}

class _AddEditVendorDialogState extends ConsumerState<AddEditVendorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _nameController = TextEditingController(text: v?.vendorName ?? '');
    _companyController = TextEditingController(text: v?.companyName ?? '');
    _phoneController = TextEditingController(text: v?.phoneNumber ?? '');
    _addressController = TextEditingController(text: v?.address ?? '');
    _notesController = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(vendorRepositoryProvider);

      if (isEditing) {
        final updated = widget.vendor!.copyWith(
          vendorName: _nameController.text.trim(),
          companyName: _companyController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim(),
        );
        await repo.updateVendor(updated);
      } else {
        final newVendor = VendorModel(
          vendorId: 'v_${DateTime.now().millisecondsSinceEpoch}',
          vendorName: _nameController.text.trim(),
          companyName: _companyController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim(),
          createdDate: DateTime.now(),
          isActive: true,
        );
        await repo.addVendor(newVendor);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.business_rounded, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEditing ? 'Edit Vendor' : 'Add New Vendor',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withAlpha(76)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _nameController,
                    validator: (v) => AppValidators.requiredField(v, 'Vendor Contact Name is required'),
                    decoration: const InputDecoration(
                      labelText: 'Vendor / Contact Name *',
                      hintText: 'e.g. Ajmal Fragrances UAE',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Company / Business Name',
                            hintText: 'e.g. Ajmal Perfumes LLC',
                            prefixIcon: Icon(Icons.business_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+971 4 ...',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address / Location',
                      hintText: 'e.g. Deira Perfume Souq, Dubai',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Specialities',
                      hintText: 'e.g. Natural Oud distillation, Taifi Rose oils',
                      prefixIcon: Icon(Icons.notes, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveVendor,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Save Changes' : 'Create Vendor'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
