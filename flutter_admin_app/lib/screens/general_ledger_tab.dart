import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class GeneralLedgerTab extends StatefulWidget {
  const GeneralLedgerTab({super.key});

  @override
  State<GeneralLedgerTab> createState() => _GeneralLedgerTabState();
}

class _GeneralLedgerTabState extends State<GeneralLedgerTab> with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  bool _isLoading = true;

  Map<String, dynamic>? _trialBalance;
  List<Map<String, dynamic>> _journalEntries = [];
  List<Map<String, dynamic>> _chartOfAccounts = [];
  String? _selectedAccountFilter;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
    _loadLedgerData();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadLedgerData() async {
    setState(() => _isLoading = true);
    try {
      final tb = await AdminSupabaseService.fetchTrialBalance();
      final entries = await AdminSupabaseService.fetchJournalEntries(accountCode: _selectedAccountFilter);
      final coa = await AdminSupabaseService.fetchChartOfAccounts();

      if (mounted) {
        setState(() {
          _trialBalance = tb;
          _journalEntries = entries;
          _chartOfAccounts = coa;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.primaryGold),
      );
    }

    final tb = _trialBalance ?? {};
    final bool isBalanced = tb['is_balanced'] == true;
    final double totalDebit = (tb['grand_total_debit'] as num?)?.toDouble() ?? 0.0;
    final double totalCredit = (tb['grand_total_credit'] as num?)?.toDouble() ?? 0.0;
    final double discrepancy = (tb['discrepancy_lyd'] as num?)?.toDouble() ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadLedgerData,
      color: AdminColors.primaryGold,
      backgroundColor: AdminColors.surface,
      child: Column(
        children: [
          // Trial Balance Header Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBalanced
                    ? AdminColors.emeraldGreen.withValues(alpha: 0.5)
                    : AdminColors.alertRed.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBalanced ? Icons.verified : Icons.warning_amber_rounded,
                          color: isBalanced ? AdminColors.emeraldGreen : AdminColors.alertRed,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ميزان المراجعة العام (Trial Balance)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBalanced
                            ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
                            : AdminColors.alertRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBalanced ? 'متزن 100%' : 'فارق غير متزن!',
                        style: TextStyle(
                          color: isBalanced ? AdminColors.emeraldGreen : AdminColors.alertRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AdminColors.divider, height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricMiniCard(
                        title: 'إجمالي المدين (Debit)',
                        value: '${totalDebit.toStringAsFixed(2)} د.ل',
                        color: AdminColors.emeraldGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricMiniCard(
                        title: 'إجمالي الدائن (Credit)',
                        value: '${totalCredit.toStringAsFixed(2)} د.ل',
                        color: AdminColors.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricMiniCard(
                        title: 'فارق القيد (Discrepancy)',
                        value: '${discrepancy.toStringAsFixed(2)} د.ل',
                        color: isBalanced ? AdminColors.primaryGold : AdminColors.alertRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sub-Tab Switcher (دليل الحسابات vs القيود اليومية)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _subTabController,
              indicatorColor: AdminColors.primaryGold,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AdminColors.primaryGold,
              unselectedLabelColor: AdminColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.account_tree_outlined, size: 18),
                  text: 'دليل الحسابات (COA)',
                ),
                Tab(
                  icon: Icon(Icons.history_edu, size: 18),
                  text: 'سجل القيود المحاسبية',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sub-Tab Views
          Expanded(
            child: TabBarView(
              controller: _subTabController,
              children: [
                _buildChartOfAccountsView(),
                _buildJournalEntriesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AdminColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AdminColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SUB-TAB 1: CHART OF ACCOUNTS (دليل الحسابات)
  // --------------------------------------------------------------------------
  Widget _buildChartOfAccountsView() {
    if (_chartOfAccounts.isEmpty) {
      return const Center(
        child: Text('لا توجد حسابات مسجلة', style: TextStyle(color: AdminColors.textSecondary)),
      );
    }

    // Group accounts by class
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var acc in _chartOfAccounts) {
      final className = acc['class_name_ar'] ?? 'عام';
      grouped.putIfAbsent(className, () => []).add(acc);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: grouped.entries.map((group) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.folder_special, color: AdminColors.primaryGold),
            title: Text(
              group.key,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary),
            ),
            subtitle: Text(
              '${group.value.length} حسابات فرعية',
              style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
            ),
            children: group.value.map((acc) {
              final code = acc['code'] ?? '';
              final name = acc['name_ar'] ?? '';
              final normal = acc['normal_balance'] == 'debit' ? 'طبيعة مدينة' : 'طبيعة دائنة';
              final double balance = (acc['balance_lyd'] as num?)?.toDouble() ?? 0.0;

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AdminColors.primaryGold,
                    ),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
                subtitle: Text(normal, style: const TextStyle(fontSize: 10, color: AdminColors.textSecondary)),
                trailing: Text(
                  '${balance.toStringAsFixed(2)} د.ل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: balance != 0 ? AdminColors.emeraldGreen : AdminColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // SUB-TAB 2: JOURNAL ENTRIES (سجل القيود المحاسبية اليومية)
  // --------------------------------------------------------------------------
  Widget _buildJournalEntriesView() {
    if (_journalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 48, color: AdminColors.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'لا توجد قيود يومية مسجلة بعد',
              style: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadLedgerData,
              icon: const Icon(Icons.refresh, color: AdminColors.primaryGold),
              label: const Text('تحديث القيود', style: TextStyle(color: AdminColors.primaryGold)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _journalEntries.length,
      itemBuilder: (context, index) {
        final entry = _journalEntries[index];
        final entryNumber = entry['entry_number'] ?? 'JRN-UNKNOWN';
        final narration = entry['narration'] ?? 'قيد محاسبي';
        final double totalDebit = (entry['total_debit'] as num?)?.toDouble() ?? 0.0;
        final double totalCredit = (entry['total_credit'] as num?)?.toDouble() ?? 0.0;
        final bool isBalanced = entry['is_balanced'] == true;
        final lines = (entry['lines'] as List?) ?? [];
        final date = (entry['created_at'] ?? '').toString().split('T').first;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isBalanced ? AdminColors.emeraldGreen : AdminColors.alertRed).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isBalanced ? Icons.account_balance_wallet : Icons.error_outline,
                color: isBalanced ? AdminColors.emeraldGreen : AdminColors.alertRed,
                size: 18,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    narration,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${totalDebit.toStringAsFixed(2)} د.ل',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.primaryGold),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Text(
                  entryNumber,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AdminColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  '• $date',
                  style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBalanced ? AdminColors.emeraldGreen.withValues(alpha: 0.15) : AdminColors.alertRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBalanced ? 'متزن' : 'غير متزن',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isBalanced ? AdminColors.emeraldGreen : AdminColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Container(
                color: AdminColors.surfaceElevated.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الحساب / البيان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.textSecondary)),
                        Row(
                          children: [
                            Text('مدين (Debit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.emeraldGreen)),
                            SizedBox(width: 24),
                            Text('دائن (Credit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.skyBlue)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: AdminColors.divider, height: 16),
                    ...lines.map((ln) {
                      final lMap = Map<String, dynamic>.from(ln as Map);
                      final accCode = lMap['account_code'] ?? '';
                      final accName = lMap['account_name_ar'] ?? '';
                      final double deb = (lMap['debit'] as num?)?.toDouble() ?? 0.0;
                      final double crd = (lMap['credit'] as num?)?.toDouble() ?? 0.0;
                      final note = lMap['note'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AdminColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          accCode,
                                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          accName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (note.isNotEmpty)
                                    Text(
                                      note,
                                      style: const TextStyle(fontSize: 10, color: AdminColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    deb > 0 ? '${deb.toStringAsFixed(2)} د.ل' : '-',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: deb > 0 ? AdminColors.emeraldGreen : AdminColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    crd > 0 ? '${crd.toStringAsFixed(2)} د.ل' : '-',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: crd > 0 ? AdminColors.skyBlue : AdminColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: AdminColors.divider, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي المتوازن:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.textPrimary)),
                        Row(
                          children: [
                            Text(
                              '${totalDebit.toStringAsFixed(2)} د.ل',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.emeraldGreen),
                            ),
                            const SizedBox(width: 32),
                            Text(
                              '${totalCredit.toStringAsFixed(2)} د.ل',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminColors.skyBlue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
