import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/cashier/cash_denominations.dart';

/// What the cashier counted out.
class CashTendered {
  final int amountPaid;
  final int changeGiven;

  const CashTendered({required this.amountPaid, required this.changeGiven});
}

/// Asks how much cash was handed over. Returns null if cancelled.
///
/// Was ~240 lines inside a `showDialog` builder in the cashier screen, with the
/// denomination maths inlined in the closure.
class CashPaymentDialog extends StatefulWidget {
  const CashPaymentDialog({super.key, required this.total});

  final int total;

  static Future<CashTendered?> show(BuildContext context, int total) =>
      showDialog<CashTendered>(
        context: context,
        builder: (_) => CashPaymentDialog(total: total),
      );

  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  late final TextEditingController _amountController;
  late final List<int> _suggestions;
  late int _amountPaid;

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.total;
    _suggestions = CashDenominations.suggest(widget.total);
    _amountController = TextEditingController(text: '${widget.total}');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _change => _amountPaid - widget.total;
  bool get _isEnough => _amountPaid >= widget.total;

  void _select(int amount) {
    setState(() {
      _amountPaid = amount;
      _amountController.text = '$amount';
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return AlertDialog(
      title: const Text('Pembayaran Tunai'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Dimens.dp16),
                decoration: BoxDecoration(
                  color: surfaces.brandTint,
                  borderRadius: BorderRadius.circular(Dimens.rLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EyebrowText('Total Tagihan'),
                    const SizedBox(height: Dimens.dp4),
                    Text(
                      Currency.format(widget.total),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Dimens.dp24),
              const EyebrowText('Uang Diterima'),
              const SizedBox(height: Dimens.dp12),

              Wrap(
                spacing: Dimens.dp8,
                runSpacing: Dimens.dp8,
                children: [
                  for (final amount in _suggestions)
                    _SuggestionChip(
                      amount: amount,
                      selected: _amountPaid == amount,
                      onTap: () => _select(amount),
                    ),
                ],
              ),

              const SizedBox(height: Dimens.dp16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() {
                      _amountController.clear();
                      _amountPaid = 0;
                    }),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _amountPaid = Currency.parse(value) ?? 0),
              ),

              const SizedBox(height: Dimens.dp20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.dp16,
                  vertical: Dimens.dp12,
                ),
                decoration: BoxDecoration(
                  color: _isEnough ? surfaces.successTint : surfaces.dangerTint,
                  borderRadius: BorderRadius.circular(Dimens.rMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEnough ? 'Kembalian' : 'Uang kurang',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _isEnough
                            ? surfaces.onSuccessTint
                            : surfaces.onDangerTint,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        Currency.format(_change.abs()),
                        key: ValueKey(_change),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _isEnough
                              ? surfaces.onSuccessTint
                              : surfaces.onDangerTint,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          // Disabled while the cash is short.
          onPressed: !_isEnough
              ? null
              : () => Navigator.pop(
                  context,
                  CashTendered(amountPaid: _amountPaid, changeGiven: _change),
                ),
          child: const Text('BAYAR & CETAK'),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.dp16,
          vertical: Dimens.dp10,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : surfaces.surfaceAlt,
          borderRadius: BorderRadius.circular(Dimens.rFull),
        ),
        child: Text(
          Currency.format(amount),
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}
