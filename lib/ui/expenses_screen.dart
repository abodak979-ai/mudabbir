import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'add_expense.dart';
import 'widgets.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile(this.e, {super.key});
  final Expense e;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final c = app.categoryById(e.categoryId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CategoryAvatar(c),
      title: Text(e.note?.isNotEmpty == true ? e.note! : (c?.name ?? context.t('بدون فئة', 'Uncategorized'))),
      subtitle: Text('${c?.name ?? ''} · ${f.date(e.spentAt, pattern: 'd MMM · h:mm a')}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (e.receiptLocal != null || e.receiptPath != null) const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.receipt_outlined, size: 16)),
        Text(f.money(e.amount), style: Theme.of(context).textTheme.titleSmall),
      ]),
      onTap: () => showAddExpense(context, existing: e),
    );
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _query = '';
  String? _category;
  int _cycleOffset = 0; // 0 = current, 1 = previous, ...

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    var cycle = app.cycle;
    for (var i = 0; i < _cycleOffset; i++) {
      cycle = cycle.previous(app.payday);
    }
    final q = _query.trim().toLowerCase();
    final list = app.expensesIn(cycle).where((e) {
      if (_category != null && e.categoryId != _category) return false;
      if (q.isEmpty) return true;
      final c = app.categoryById(e.categoryId);
      return (e.note ?? '').toLowerCase().contains(q) || (c?.name ?? '').toLowerCase().contains(q) || e.amount.toString().contains(q);
    }).toList();
    final total = list.fold(0.0, (s, e) => s + e.amount);

    // Group by day.
    final groups = <DateTime, List<Expense>>{};
    for (final e in list) {
      groups.putIfAbsent(dateOnly(e.spentAt), () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('المصاريف', 'Expenses'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            hintText: context.t('ابحث بالملاحظة أو الفئة أو المبلغ', 'Search note, category or amount'),
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Row(children: [
          IconButton(onPressed: () => setState(() => _cycleOffset++), icon: const Icon(Icons.chevron_left), tooltip: context.t('الدورة السابقة', 'Previous cycle')),
          Expanded(
            child: Text(
              '${f.date(cycle.start)} – ${f.date(cycle.end)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            onPressed: _cycleOffset == 0 ? null : () => setState(() => _cycleOffset--),
            icon: const Icon(Icons.chevron_right),
            tooltip: context.t('الدورة التالية', 'Next cycle'),
          ),
        ]),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(label: Text(context.t('الكل', 'All')), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
            ),
            for (final c in app.categories)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(c.name),
                  selected: _category == c.id,
                  onSelected: (s) => setState(() => _category = s ? c.id : null),
                ),
              ),
          ]),
        ),
        ListTile(
          dense: true,
          title: Text(context.t('${f.n(list.length)} عملية', '${f.n(list.length)} transactions')),
          trailing: Text(f.money(total), style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(context.t('لا توجد مصاريف', 'No expenses')))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final day in groups.keys) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Row(children: [
                          Expanded(child: Text(f.date(day, pattern: 'EEEE d MMMM'), style: Theme.of(context).textTheme.labelLarge)),
                          Text(f.money(groups[day]!.fold<double>(0, (s, e) => s + e.amount)), style: Theme.of(context).textTheme.labelLarge),
                        ]),
                      ),
                      for (final e in groups[day]!)
                        Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Icon(Icons.delete_outline),
                          ),
                          confirmDismiss: (_) => confirmDialog(context, context.t('حذف المصروف؟', 'Delete expense?'), f.money(e.amount)),
                          onDismissed: (_) => app.deleteExpense(e),
                          child: ExpenseTile(e),
                        ),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}
