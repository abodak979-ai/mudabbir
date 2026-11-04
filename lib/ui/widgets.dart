import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_state.dart';

const categoryIcons = <String, IconData>{
  'groceries': Icons.local_grocery_store_outlined,
  'restaurant': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'transport': Icons.directions_car_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'fun': Icons.movie_outlined,
  'health': Icons.favorite_outline,
  'bills': Icons.receipt_long_outlined,
  'education': Icons.school_outlined,
  'travel': Icons.flight_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'delivery': Icons.delivery_dining_outlined,
  'other': Icons.category_outlined,
};

const categoryColors = <int>[
  0xFF2E7D32, 0xFFEF6C00, 0xFF1565C0, 0xFF8E24AA, 0xFFD81B60, //
  0xFF00897B, 0xFF6D4C41, 0xFF607D8B, 0xFFF9A825, 0xFF3949AB,
];

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 40});
  final Category? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(category?.color ?? 0xFF607D8B);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(categoryIcons[category?.icon] ?? Icons.category_outlined, color: color, size: size * 0.55),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Progress ring for one of the four salary shares.
class ShareRing extends StatelessWidget {
  const ShareRing({super.key, required this.label, required this.value, required this.amount, required this.color});
  final String label;
  final double value;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final over = value > 1;
    return Semantics(
      label: '$label $amount',
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value.clamp(0, 1).toDouble(),
                    strokeWidth: 7,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: over ? Theme.of(context).colorScheme.error : color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text('${(value * 100).clamp(0, 999).round()}%', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(amount, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class LimitBar extends StatelessWidget {
  const LimitBar({super.key, required this.spent, required this.limit, this.color});
  final double spent;
  final double limit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = limit <= 0 ? 0.0 : spent / limit;
    final cs = Theme.of(context).colorScheme;
    final c = r >= 1 ? cs.error : (r >= 0.8 ? Colors.orange : (color ?? cs.primary));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(value: r.clamp(0, 1).toDouble(), minHeight: 8, color: c, backgroundColor: c.withValues(alpha: 0.15)),
    );
  }
}

/// Decimal amount field that accepts both Western and Arabic-Indic digits.
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, required this.label, this.suffix, this.onChanged, this.autofocus = false});
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫]'))],
      decoration: InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
  }
}

double parseAmount(String s) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = eastern.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (ch == '٫' || ch == ',') {
      b.write('.');
    } else {
      b.write(ch);
    }
  }
  return double.tryParse(b.toString()) ?? 0;
}

String amountText(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

Future<bool> confirmDialog(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.t('تأكيد', 'Confirm'))),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
