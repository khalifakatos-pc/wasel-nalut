import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

/// ============================================================================
/// PRODUCT MODIFIERS & CUSTOMIZATION MANAGEMENT SHEET (ADMIN APP)
/// ============================================================================
/// Enables Wasel admins and store managers in Nalut to flexibly manage:
/// - Harissa / Spice level scales (مستوى الهريسة والشطة)
/// - Exclusions (بدون كاتشب، بدون بصل، بدون مايونيز)
/// - Custom Add-ons with prices (كثر بطاطا، جبنة دبل، صوص ثومية)
/// - Out-of-stock toggle switches (إيقاف الهريسة أو الجبنة مؤقتاً بنقرة)
/// - 1-Click preset templates and category-wide inheritance
/// ============================================================================

class ProductModifiersSheet extends StatefulWidget {
  final String storeId;
  final String productId;
  final String productName;
  final String category;

  const ProductModifiersSheet({
    super.key,
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.category,
  });

  @override
  State<ProductModifiersSheet> createState() => _ProductModifiersSheetState();
}

class _ProductModifiersSheetState extends State<ProductModifiersSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    setState(() => _isLoading = true);
    final loaded = await AdminSupabaseService.fetchModifierGroupsForProduct(
      widget.productId,
      widget.category,
      widget.productName,
    );
    if (mounted) {
      setState(() {
        // Deep copy to allow local editing
        _groups = loaded.map((g) {
          final copy = Map<String, dynamic>.from(g);
          if (copy['options'] is List) {
            copy['options'] = (copy['options'] as List)
                .map((opt) => Map<String, dynamic>.from(opt as Map))
                .toList();
          }
          return copy;
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _applyPreset(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تطبيق ${preset['title']}؟',
          style: const TextStyle(color: AdminColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'سيتم استبدال الخيارات الحالية بقالب "${preset['title']}". هل تريد المتابعة؟',
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primaryGold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final List<dynamic> presetGroups = preset['groups'] as List;
              setState(() {
                _groups = presetGroups.map((g) {
                  final copy = Map<String, dynamic>.from(g as Map);
                  if (copy['options'] is List) {
                    copy['options'] = (copy['options'] as List)
                        .map((opt) => Map<String, dynamic>.from(opt as Map))
                        .toList();
                  }
                  return copy;
                }).toList();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✨ تم تحميل ${preset['title']} بنجاح'),
                  backgroundColor: AdminColors.emeraldGreen,
                ),
              );
            },
            child: const Text('تطبيق القالب', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addNewGroup() {
    final titleController = TextEditingController();
    String type = 'multiple'; // 'single' or 'multiple'
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'إضافة مجموعة خيارات جديدة ➕',
            style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('عنوان المجموعة:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'مثال: نوع الصوص، إضافات الجبن...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: AdminColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('نوع الاختيار:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('فردي (راديو)')),
                      selected: type == 'single',
                      onSelected: (val) {
                        if (val) setDlgState(() => type = 'single');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('متعدد (مربعات)')),
                      selected: type == 'multiple',
                      onSelected: (val) {
                        if (val) setDlgState(() => type = 'multiple');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('اختيار إجباري قبل الإضافة؟', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  Switch(
                    value: isRequired,
                    activeThumbColor: AdminColors.primaryGold,
                    onChanged: (val) => setDlgState(() => isRequired = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryGold, foregroundColor: Colors.black),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  _groups.add({
                    'id': 'grp_${DateTime.now().millisecondsSinceEpoch}',
                    'title': title,
                    'type': type,
                    'is_required': isRequired,
                    'options': [
                      {'name': 'خيار تجريبي 1', 'price': 0.0, 'is_default': false, 'is_available': true},
                    ],
                  });
                });
              },
              child: const Text('إضافة المجموعة'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewOptionToGroup(int groupIndex) {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إضافة خيار إلى "${_groups[groupIndex]['title']}"',
          style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اسم الخيار (مثال: زيادة هريسة، بدون كاتشب، جبنة شيدر)',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: AdminColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'السعر الإضافي (0.00 د.ل للاستثناءات أو المجاني)',
                labelStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 11),
                filled: true,
                fillColor: AdminColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emeraldGreen, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
              Navigator.pop(ctx);
              setState(() {
                final options = _groups[groupIndex]['options'] as List;
                options.add({
                  'name': name,
                  'price': price,
                  'is_default': false,
                  'is_available': true,
                });
              });
            },
            child: const Text('إضافة الخيار'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveModifiers({bool applyToCategory = false}) async {
    setState(() => _isSaving = true);
    bool ok = false;
    int count = 1;

    if (applyToCategory) {
      count = await AdminSupabaseService.applyModifierGroupsToCategory(
        storeId: widget.storeId,
        category: widget.category,
        groups: _groups,
      );
      ok = count > 0;
    } else {
      ok = await AdminSupabaseService.saveModifierGroupsForProduct(
        widget.productId,
        _groups,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (applyToCategory
                    ? '✅ تم تعميم الخيارات على $count وجبة في قسم "${widget.category}" بنجاح!'
                    : '✅ تم حفظ الخيارات والتخصيصات لهذه الوجبة بنجاح!')
                : '❌ تعذر الحفظ في السحابة',
          ),
          backgroundColor: ok ? AdminColors.emeraldGreen : AdminColors.alertRed,
        ),
      );
      if (ok) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = AdminSupabaseService.getPresetTemplates();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: AdminColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.primaryGold.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: AdminColors.primaryGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'تخصيص الخيارات والإضافات • قسم (${widget.category})',
                          style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: AdminColors.divider, height: 1),

            // Main Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 1. PRESET TEMPLATES BAR
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AdminColors.primaryGold, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'قوالب جاهزة بنقرة واحدة (Presets):',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: presets.map((preset) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ActionChip(
                                  backgroundColor: AdminColors.surfaceElevated,
                                  side: BorderSide(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
                                  label: Text(
                                    preset['title'] as String,
                                    style: const TextStyle(color: AdminColors.primaryGold, fontSize: 12),
                                  ),
                                  onPressed: () => _applyPreset(preset),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. GROUPS LIST
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'مجموعات التخصيص (${_groups.length} مجموعات)',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: _addNewGroup,
                              icon: const Icon(Icons.add, size: 16, color: AdminColors.primaryGold),
                              label: const Text('مجموعة جديدة', style: TextStyle(color: AdminColors.primaryGold, fontSize: 12)),
                            ),
                          ],
                        ),

                        if (_groups.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Text(
                              'لا توجد خيارات مضافة بعد. اختر قالباً جاهزاً من الأعلى أو أضف مجموعة جديدة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ),

                        ..._groups.asMap().entries.map((entry) {
                          final gIdx = entry.key;
                          final grp = entry.value;
                          final options = (grp['options'] as List?) ?? [];
                          final isSingle = grp['type'] == 'single';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AdminColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AdminColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Group Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isSingle ? Colors.amber : Colors.blue).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isSingle ? 'اختيار فردي (إجباري)' : 'اختيار متعدد (حر)',
                                        style: TextStyle(
                                          color: isSingle ? Colors.amber : Colors.lightBlueAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        grp['title']?.toString() ?? '',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                                      tooltip: 'حذف المجموعة',
                                      onPressed: () {
                                        setState(() => _groups.removeAt(gIdx));
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(color: AdminColors.divider, height: 16),

                                // Options List
                                ...options.asMap().entries.map((optEntry) {
                                  final optIdx = optEntry.key;
                                  final opt = Map<String, dynamic>.from(optEntry.value as Map);
                                  final bool isAvail = opt['is_available'] == true || opt['is_available'] == null;
                                  final double price = (opt['price'] is num) ? (opt['price'] as num).toDouble() : 0.0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AdminColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isAvail ? Colors.transparent : AdminColors.alertRed.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            opt['name']?.toString() ?? '',
                                            style: TextStyle(
                                              color: isAvail ? Colors.white : Colors.white38,
                                              fontSize: 13,
                                              decoration: isAvail ? null : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          price > 0 ? '+${price.toStringAsFixed(2)} د.ل' : 'مجاني',
                                          style: TextStyle(
                                            color: price > 0 ? AdminColors.primaryGold : AdminColors.emeraldGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Out-of-Stock Toggle
                                        Tooltip(
                                          message: isAvail ? 'متوفر حالياً بالمطبخ' : 'نفد من المطبخ مؤقتاً',
                                          child: Switch(
                                            value: isAvail,
                                            activeThumbColor: AdminColors.emeraldGreen,
                                            onChanged: (val) {
                                              setState(() {
                                                opt['is_available'] = val;
                                                options[optIdx] = opt;
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white24),
                                          onPressed: () {
                                            setState(() => options.removeAt(optIdx));
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 6),
                                // Add Option to this group
                                TextButton.icon(
                                  onPressed: () => _addNewOptionToGroup(gIdx),
                                  icon: const Icon(Icons.add_circle_outline, size: 15, color: AdminColors.emeraldGreen),
                                  label: const Text(
                                    'إضافة خيار لهذه المجموعة',
                                    style: TextStyle(color: AdminColors.emeraldGreen, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.surfaceElevated,
                border: const Border(top: BorderSide(color: AdminColors.divider)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Save for this product
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : () => _saveModifiers(applyToCategory: false),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'حفظ لهذه الوجبة 💾',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Apply to whole category
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.emeraldGreen,
                          side: const BorderSide(color: AdminColors.emeraldGreen, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : () => _saveModifiers(applyToCategory: true),
                        child: Text(
                          'تعميم على قسم (${widget.category}) ⚡',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
