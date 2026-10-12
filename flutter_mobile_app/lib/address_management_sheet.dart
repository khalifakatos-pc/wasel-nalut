import 'package:flutter/material.dart';
import 'design_system.dart';
import 'satellite_location_picker.dart';
import 'services/api_service.dart';

/// Modal bottom sheet for managing, choosing, and adding delivery addresses.
class AddressManagementSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onAddressSelected;

  const AddressManagementSheet({
    super.key,
    this.onAddressSelected,
  });

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressManagementSheet(),
    );
  }

  @override
  State<AddressManagementSheet> createState() => _AddressManagementSheetState();
}

class _AddressManagementSheetState extends State<AddressManagementSheet> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final list = await ApiService.getUserAddresses();
    if (mounted) {
      setState(() {
        _addresses = list;
        _isLoading = false;
      });
    }
  }

  void _selectAddress(Map<String, dynamic> addr) {
    ApiService.activeAddress = addr;
    widget.onAddressSelected?.call(addr);
    Navigator.pop(context, addr);
  }

  Future<void> _deleteAddress(String addressId) async {
    await ApiService.deleteUserAddress(addressId);
    await _loadAddresses();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف العنوان بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SatelliteLocationPicker()),
    );
    if (result != null) {
      await _loadAddresses();
      if (mounted) {
        _selectAddress(result);
      }
    }
  }

  String _getTagEmoji(String? tag) {
    switch (tag) {
      case 'home':
        return '🏠';
      case 'work':
        return '💼';
      case 'chalet':
        return '🌴';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Handle Pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.waselPrimary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'عناويني وأماكن التوصيل',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Addresses List
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        if (_addresses.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text('📍', style: TextStyle(fontSize: 40)),
                                const SizedBox(height: 8),
                                Text(
                                  'لا توجد عناوين محفوظة بعد',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._addresses.map((addr) {
                            final isSelected = ApiService.activeAddress['id'] == addr['id'];
                            final title = addr['title'] ?? 'موقع';
                            final details = addr['details'] ?? 'نالوت';
                            final tag = addr['tag'] as String?;

                            return WaselBouncyPressable(
                              onTap: () => _selectAddress(addr),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary.withValues(alpha: 0.08)
                                      : colorScheme.surface,
                                  borderRadius: AppRadius.radiusLg,
                                  border: Border.all(
                                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colorScheme.primary.withValues(alpha: 0.15)
                                            : colorScheme.surfaceContainerHighest,
                                        borderRadius: AppRadius.radiusMd,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _getTagEmoji(tag),
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              if (addr['is_default'] == true) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.waselPrimary.withValues(alpha: 0.12),
                                                    borderRadius: AppRadius.radiusSm,
                                                  ),
                                                  child: const Text(
                                                    'الافتراضي',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.waselPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            details,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.check_circle_rounded, color: AppColors.waselPrimary, size: 22),
                                      )
                                    else if (_addresses.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.error),
                                        onPressed: () => _deleteAddress(addr['id'] as String),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
            ),

            // Add New Address Button
            SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: WaselButton(
                  text: 'إضافة موقع جديد بالقمر الصناعي 🛰️',
                  icon: const Icon(Icons.satellite_alt_rounded, size: 18),
                  type: WaselButtonType.primary,
                  isFullWidth: true,
                  onPressed: _addNewAddress,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
