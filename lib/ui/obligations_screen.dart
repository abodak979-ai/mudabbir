import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

String obligationKindLabel(BuildContext context, String kind) => switch (kind) {
      'rent' => context.t('إيجار', 'Rent'),
      'installment' => context.t('قسط', 'Installment'),
      'subscription' => context.t('اشتراك', 'Subscription'),
      'other' => context.t('أخرى', 'Other'),
      _ => context.t('فاتورة', 'Bill'),
    };

IconData obligationIcon(String kind) => switch (kind) {
      'rent' => Icons.home_outlined,
      'installment' => Icons.directions_car_outlined,
      'subscription' => Icons.subscriptions_outlined,
      'other' => Icons.more_horiz,
      _ => Icons.bolt_outlined,
    };

Future<Obligation?> editObligation(BuildContext context, [Obligation? existing]) {
  final name = TextEditingController(text: existing?.name);
  final amount = TextEditingController(text: amountText(existing?.amount ?? 0));
  var kind = existing?.kind ?? 'rent';
  var due = existing?.dueDay ?? 1;
  var remind = existing?.remind ?? true;
  return showDialog<Obligation>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(existing == null ? context.t('التزام جديد', 'New obligation') : context.t('تعديل الالتزام', 'Edit obligation')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in ['rent', 'installment', 'bill', 'subscription', 'other'])
                ChoiceChip(
                  label: Text(obligationKindLabel(context, k)),
                  selected: kind == k,
                  onSelected: (_) => setState(() {
                    kind = k;
                    if (name.text.isEmpty || ['إيجار', 'قسط', 'فاتورة', 'اشتراك', 'Rent', 'Installment', 'Bill', 'Subscription'].contains(name.text)) {
                      name.text = k == 'other' ? '' : obligationKindLabel(context, k);
                    }
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: InputDecoration(labelText: context.t('الاسم', 'Name'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            AmountField(controller: amount, label: context.t('المبلغ الشهري', 'Monthly amount'), suffix: context.app.fmt.currency),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: due,
              decoration: InputDecoration(labelText: context.t('يوم الاستحقاق', 'Due day'), border: const OutlineInputBorder()),
              items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text(context.app.fmt.n(d)))],
              onChanged: (v) => due = v ?? due,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('ذكّرني قبل ٣ أيام ويوم الاستحقاق', 'Remind me 3 days before and on the due day')),
              value: remind,
              onChanged: (v) => setState(() => remind = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final a = parseAmount(amount.text);
              if (name.text.trim().isEmpty || a <= 0) return;
              final o = existing ?? Obligation(name: '', amount: 0, dueDay: due);
              o
                ..name = name.text.trim()
                ..amount = a
                ..dueDay = due
                ..kind = kind
                ..remind = remind;
              Navigator.pop(c, o);
            },
            child: Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
    ),
  );
}

class ObligationsScreen extends StatelessWidget {
  const ObligationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final cycle = app.cycle;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('الالتزامات الثابتة', 'Fixed obligations'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final o = await editObligation(context);
          if (o != null) await app.saveObligation(o);
        },
        icon: const Icon(Icons.add),
        label: Text(context.t('إضافة', 'Add')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ListTile(
            title: Text(context.t('المجموع الشهري', 'Monthly total')),
            trailing: Text(f.money(app.obligationsTotal), style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(context.t('${f.pct(app.breakdown.obligationsRatio)} من الراتب', '${f.pct(app.breakdown.obligationsRatio)} of salary')),
          ),
          if (app.obligations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.t('أضف الإيجار والأقساط والفواتير لتُخصم قبل أي شيء', 'Add rent, installments and bills so they are deducted first'),
                  textAlign: TextAlign.center),
            ),
          for (final o in app.obligations)
            ListTile(
              leading: CircleAvatar(child: Icon(obligationIcon(o.kind))),
              title: Text(o.name),
              subtitle: Text(
                '${f.money(o.amount)} · ${context.t('يوم', 'day')} ${f.n(o.dueDay)} · ${f.date(app.dueDateIn(o, cycle))}',
              ),
              trailing: app.isPaid(o, cycle)
                  ? Chip(label: Text(context.t('مدفوع', 'Paid')), avatar: const Icon(Icons.check, size: 16))
                  : TextButton(onPressed: () => app.markPaid(o), child: Text(context.t('تم الدفع', 'Mark paid'))),
              onTap: () async {
                final r = await editObligation(context, o);
                if (r != null) await app.saveObligation(r);
              },
              onLongPress: () async {
                if (await confirmDialog(context, context.t('حذف الالتزام؟', 'Delete obligation?'), o.name)) {
                  await app.deleteObligation(o);
                }
              },
            ),
        ],
      ),
    );
  }
}
