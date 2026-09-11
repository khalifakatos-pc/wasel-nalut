import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// DRIVER WALLET & COD LEDGER MANAGEMENT SCREEN
/// ============================================================================
/// 1. Available Net Earnings & Cash-in-Hand COD Liability Tracker.
/// 2. Cash Deposit Request (Settling customer COD with Wasel platform).
/// 3. Payout Withdrawal to local Libyan payment rails (Sadad, Tadawul, Moamalat).
/// 4. Comprehensive Double-Entry Transaction Ledger with category filters.
/// ============================================================================

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _availableEarningsLyd = 348.50;
  double _cashInHandCodLyd = 215.00;
  final double _maxCodLimitLyd = 500.00;
  String _selectedFilter = 'All';

  late List<LedgerTransaction> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(DriverMockData.getSampleTransactions());
  }

  List<LedgerTransaction> get _filteredTransactions {
    if (_selectedFilter == 'Earnings') {
      return _transactions.where((t) => t.type == TransactionType.tripEarnings || t.type == TransactionType.surgeBonus || t.type == TransactionType.tipReceived).toList();
    } else if (_selectedFilter == 'COD') {
      return _transactions.where((t) => t.type == TransactionType.codCollected || t.type == TransactionType.platformSettlement).toList();
    } else if (_selectedFilter == 'Withdrawals') {
      return _transactions.where((t) => t.type == TransactionType.payoutWithdrawalSadad || t.type == TransactionType.payoutWithdrawalTadawul).toList();
    }
    return _transactions;
  }

  /// Cash Deposit Request (Settling COD with Platform via Sadad / Tadawul / Kiosks)
  void _openDepositSettleModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController(text: _cashInHandCodLyd.toStringAsFixed(0));
    final phoneController = TextEditingController(text: '0912345678');
    String selectedMethod = 'Sadad';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkSurface : Colors.white,
                  borderRadius: DriverRadius.topSheet,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                          borderRadius: DriverRadius.radiusFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DriverColors.sadadBlue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: DriverColors.sadadBlue, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settle Cash (COD Deposit)',
                              style: DriverTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Transfer collected cash to Wasel Platform',
                              style: DriverTypography.bodySmall.copyWith(
                                color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Deposit Method Selection (Sadad / Tadawul / Platform Hub)
                    Text('Select Deposit Channel', style: DriverTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Sadad Mobile')),
                            selected: selectedMethod == 'Sadad',
                            selectedColor: DriverColors.sadadBlue,
                            onSelected: (val) => setModalState(() => selectedMethod = 'Sadad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Tadawul Card')),
                            selected: selectedMethod == 'Tadawul',
                            selectedColor: DriverColors.tadawulTeal,
                            onSelected: (val) => setModalState(() => selectedMethod = 'Tadawul'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Cash Hub')),
                            selected: selectedMethod == 'Cash Hub',
                            selectedColor: DriverColors.primary,
                            onSelected: (val) => setModalState(() => selectedMethod = 'Cash Hub'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Deposit Amount (LYD)',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                        suffixText: 'LYD',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone or Reference Input
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: selectedMethod == 'Sadad' ? 'Sadad Mobile Number (091/092)' : 'Account / Reference ID',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Deposit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final depositAmt = double.tryParse(amountController.text) ?? 0.0;
                          if (depositAmt > 0) {
                            Navigator.of(context).pop();
                            setState(() {
                              _cashInHandCodLyd = (_cashInHandCodLyd - depositAmt).clamp(0.0, 9999.0);
                              _transactions.insert(
                                0,
                                LedgerTransaction(
                                  id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                  title: 'COD Settlement via $selectedMethod',
                                  description: 'Settled liability of ${DriverTheme.formatLyd(depositAmt)}',
                                  amountLyd: depositAmt,
                                  isCredit: true,
                                  type: TransactionType.platformSettlement,
                                  timestamp: DateTime.now(),
                                  referenceId: 'DEP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                  status: 'settled',
                                ),
                              );
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Deposit of ${DriverTheme.formatLyd(depositAmt)} submitted via $selectedMethod!'),
                                backgroundColor: DriverColors.onlineGreen,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DriverColors.sadadBlue,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                        ),
                        child: Text(
                          'Submit Deposit Request',
                          style: DriverTypography.labelLarge.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Payout Withdrawal Flow to Local Banks (Sadad, Tadawul, Bank Transfer)
  void _openPayoutWithdrawalModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController(text: (_availableEarningsLyd * 0.8).toStringAsFixed(0));
    final accountController = TextEditingController(text: '0912345678');
    String selectedRail = 'Sadad';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkSurface : Colors.white,
                  borderRadius: DriverRadius.topSheet,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                          borderRadius: DriverRadius.radiusFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.outbox_rounded, color: DriverColors.onlineGreen, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Withdraw Earnings Payout',
                              style: DriverTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Available: ${DriverTheme.formatLyd(_availableEarningsLyd)}',
                              style: DriverTypography.bodySmall.copyWith(
                                color: DriverColors.onlineGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Rail Selection
                    Text('Payout Channel', style: DriverTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Sadad Pay')),
                            selected: selectedRail == 'Sadad',
                            selectedColor: DriverColors.sadadBlue,
                            onSelected: (val) => setModalState(() => selectedRail = 'Sadad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Tadawul Card')),
                            selected: selectedRail == 'Tadawul',
                            selectedColor: DriverColors.tadawulTeal,
                            onSelected: (val) => setModalState(() => selectedRail = 'Tadawul'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Bank IBAN')),
                            selected: selectedRail == 'Bank IBAN',
                            selectedColor: DriverColors.accentPurple,
                            onSelected: (val) => setModalState(() => selectedRail = 'Bank IBAN'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Amount (LYD)',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        suffixText: 'LYD',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Account Number Input
                    TextField(
                      controller: accountController,
                      decoration: InputDecoration(
                        labelText: selectedRail == 'Sadad'
                            ? 'Sadad Mobile Number (091/092)'
                            : (selectedRail == 'Tadawul' ? 'Tadawul Card 16-Digits' : 'Libyan Bank IBAN (LY...)'),
                        prefixIcon: const Icon(Icons.credit_card_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Withdrawal CTA
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final withdrawAmt = double.tryParse(amountController.text) ?? 0.0;
                          if (withdrawAmt > 0 && withdrawAmt <= _availableEarningsLyd) {
                            Navigator.of(context).pop();
                            setState(() {
                              _availableEarningsLyd -= withdrawAmt;
                              _transactions.insert(
                                0,
                                LedgerTransaction(
                                  id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                  title: 'Payout Withdrawal ($selectedRail)',
                                  description: 'Transferred to ${accountController.text}',
                                  amountLyd: withdrawAmt,
                                  isCredit: false,
                                  type: selectedRail == 'Sadad'
                                      ? TransactionType.payoutWithdrawalSadad
                                      : TransactionType.payoutWithdrawalTadawul,
                                  timestamp: DateTime.now(),
                                  referenceId: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                ),
                              );
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Payout of ${DriverTheme.formatLyd(withdrawAmt)} sent via $selectedRail!'),
                                backgroundColor: DriverColors.onlineGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error: Insufficient available earnings balance'),
                                backgroundColor: DriverColors.urgentRed,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DriverColors.onlineGreen,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                        ),
                        child: Text(
                          'Confirm Cashout Payout',
                          style: DriverTypography.labelLarge.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codProgress = (_cashInHandCodLyd / _maxCodLimitLyd).clamp(0.0, 1.0);
    final isCodApproaching = _cashInHandCodLyd >= (_maxCodLimitLyd * 0.75);

    return Scaffold(
      backgroundColor: isDark ? DriverColors.darkBg : DriverColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Driver Wallet & COD Ledger',
          style: DriverTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : DriverColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ledger synced with Wasel Supabase double-entry server.'),
                  backgroundColor: DriverColors.darkCard,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dual Financial Balance Hero Card (Net Available vs Cash in Hand COD)
            _buildFinancialHeroCard(isDark, codProgress, isCodApproaching),
            const SizedBox(height: 20),

            // 2. Quick Action Buttons (Deposit / Settle COD & Cashout)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openDepositSettleModal,
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Settle COD Cash'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DriverColors.sadadBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openPayoutWithdrawalModal,
                    icon: const Icon(Icons.outbox_rounded, size: 18),
                    label: const Text('Withdraw Payout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DriverColors.onlineGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Transactions Ledger Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Transactions Ledger',
                  style: DriverTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
                Text(
                  '${_filteredTransactions.length} records',
                  style: DriverTypography.bodySmall.copyWith(
                    color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Earnings', 'COD', 'Withdrawals'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: DriverColors.primary,
                      backgroundColor: isDark ? DriverColors.darkCard : Colors.white,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : DriverColors.lightTextPrimary),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Itemized Ledger Transactions List
            if (_filteredTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Text(
                  'No transactions found in this category',
                  style: DriverTypography.bodyMedium.copyWith(color: DriverColors.darkTextMuted),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredTransactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tx = _filteredTransactions[index];
                  return _buildTransactionTile(tx, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Dual Balance Hero Card with COD Liability Alert
  Widget _buildFinancialHeroCard(bool isDark, double codProgress, bool isCodApproaching) {
    return Container(
      decoration: BoxDecoration(
        gradient: DriverColors.walletHeaderGradient,
        borderRadius: DriverRadius.radiusXl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Available Earnings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET AVAILABLE EARNINGS',
                    style: DriverTypography.labelSmall.copyWith(
                      color: const Color(0xFF6EE7B7),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        DriverTheme.formatLyd(_availableEarningsLyd),
                        style: DriverTypography.displayLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_rounded, color: DriverColors.onlineGreen, size: 28),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 28),

          // Cash-in-Hand COD Liability Tracker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'CASH IN HAND (COD HELD)',
                        style: DriverTypography.labelSmall.copyWith(
                          color: isCodApproaching ? DriverColors.codWarning : const Color(0xFFFDBA74),
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (isCodApproaching) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: DriverColors.urgentRed,
                            borderRadius: DriverRadius.radiusXs,
                          ),
                          child: const Text(
                            'Settle Soon',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DriverTheme.formatLyd(_cashInHandCodLyd),
                    style: DriverTypography.headlineLarge.copyWith(
                      color: isCodApproaching ? DriverColors.codWarning : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                'Limit: ${DriverTheme.formatLyd(_maxCodLimitLyd)}',
                style: DriverTypography.bodySmall.copyWith(color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // COD Progress Bar
          ClipRRect(
            borderRadius: DriverRadius.radiusFull,
            child: LinearProgressIndicator(
              value: codProgress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCodApproaching ? DriverColors.urgentRed : DriverColors.codWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual Transaction Item Tile
  Widget _buildTransactionTile(LedgerTransaction tx, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (tx.type) {
      case TransactionType.tripEarnings:
      case TransactionType.surgeBonus:
      case TransactionType.tipReceived:
        icon = Icons.arrow_downward_rounded;
        iconColor = DriverColors.onlineGreen;
        break;
      case TransactionType.codCollected:
        icon = Icons.payments_outlined;
        iconColor = DriverColors.codWarning;
        break;
      case TransactionType.platformSettlement:
        icon = Icons.check_circle_outline_rounded;
        iconColor = DriverColors.sadadBlue;
        break;
      case TransactionType.payoutWithdrawalSadad:
      case TransactionType.payoutWithdrawalTadawul:
        icon = Icons.arrow_upward_rounded;
        iconColor = DriverColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCard : Colors.white,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(
          color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: DriverTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description,
                  style: DriverTypography.bodySmall.copyWith(
                    color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.referenceId} • ${_formatTime(tx.timestamp)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isCredit ? '+' : '-'}${DriverTheme.formatLyd(tx.amountLyd)}',
                style: DriverTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: tx.isCredit ? DriverColors.onlineGreen : (isDark ? Colors.white70 : DriverColors.lightTextPrimary),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tx.status == 'settled'
                      ? DriverColors.sadadBlue.withValues(alpha: 0.15)
                      : DriverColors.onlineGreen.withValues(alpha: 0.15),
                  borderRadius: DriverRadius.radiusXs,
                ),
                child: Text(
                  tx.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: tx.status == 'settled' ? DriverColors.sadadBlue : DriverColors.onlineGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }
}
