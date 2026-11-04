import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'add_expense.dart';
import 'expenses_screen.dart';
import 'obligations_screen.dart';
import 'plan_editor.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.openReports});
  final void Function({bool previous}) openReports;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final cycle = app.cycle;
    final b = app.breakdown;
    final remaining = app.remainingToday;
    final over = remaining < 0;
    final dayOfCycle = cycle.totalDays - cycle.daysLeft(now) + 1;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            app.profile?.displayName?.isNotEmpty == true ? context.t('أهلاً ${app.profile!.displayName}', 'Hi ${app.profile!.displayName}') : context.t('مُدبِّر', 'Mudabbir'),
          ),
          Text('${f.date(now, pattern: 'EEEE d MMMM')} · ${f.hijri(now)}', style: theme.textTheme.bodySmall),
        ]),
        actions: [
          if (app.pending > 0 || app.syncing)
            IconButton(
              tooltip: context.t('بانتظار المزامنة', 'Waiting to sync'),
              onPressed: app.syncNow,
              icon: app.syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
            ),
          IconButton(
            tooltip: app.hideAmounts ? context.t('إظهار الأرقام', 'Show amounts') : context.t('إخفاء الأرقام', 'Hide amounts'),
            onPressed: () => app.setPref('hide', !app.hideAmounts),
            icon: Icon(app.hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: context.t('الإعدادات', 'Settings'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.syncNow,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Daily allowance — the core number of the app.
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              color: over ? cs.errorContainer : cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(over ? context.t('تجاوزت حد اليوم بـ', 'Over today\'s limit by') : context.t('تقدر تصرف اليوم', 'You can spend today'),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(f.money(remaining.abs()), style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  LimitBar(spent: app.spentToday, limit: app.todayAllowance),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(context.t('حد اليوم ${f.money(app.todayAllowance)}', 'Today\'s limit ${f.money(app.todayAllowance)}'))),
                    Text(context.t('${f.n(cycle.daysLeft(now))} يوم للراتب', '${f.n(cycle.daysLeft(now))} days to payday')),
                  ]),
                ]),
              ),
            ),

            if (dayOfCycle <= 3 && app.expensesIn(cycle.previous(app.payday)).isNotEmpty)
              SectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.summarize_outlined),
                  title: Text(context.t('ملخص الدورة الماضية جاهز', 'Last cycle summary is ready')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openReports(previous: true),
                ),
              ),

            for (final o in app.upcomingBills)
              SectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(obligationIcon(o.kind), color: cs.tertiary),
                  title: Text(o.name),
                  subtitle: Text('${f.money(o.amount)} · ${f.date(app.dueDateIn(o, cycle))}'),
                  trailing: FilledButton.tonal(onPressed: () => app.markPaid(o), child: Text(context.t('تم الدفع', 'Paid'))),
                ),
              ),

            SectionCard(
              title: context.t('حصص الراتب', 'Salary shares'),
              trailing: Text(f.money(b.salary), style: theme.textTheme.labelLarge),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ShareRing(
                    label: context.t('التزامات', 'Bills'),
                    value: b.obligations <= 0 ? 1 : app.obligationsPaidThisCycle / b.obligations,
                    amount: f.money(b.obligations, withCurrency: false),
                    color: shareColors[0],
                  ),
                  ShareRing(
                    label: context.t('ادخار', 'Savings'),
                    value: 1,
                    amount: f.money(b.savings, withCurrency: false),
                    color: shareColors[1],
                  ),
                  ShareRing(
                    label: context.t('استثمار', 'Invest'),
                    value: 1,
                    amount: f.money(b.investment, withCurrency: false),
                    color: shareColors[2],
                  ),
                  ShareRing(
                    label: context.t('صرف', 'Spending'),
                    value: b.spending <= 0 ? 1 : app.spentThisCycle / b.spending,
                    amount: f.money(b.spending, withCurrency: false),
                    color: shareColors[3],
                  ),
                ],
              ),
            ),

            if (b.investment > 0)
              SectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.trending_up, color: shareColors[2]),
                  title: Text(context.t('جاهز للاستثمار هذه الدورة', 'Ready to invest this cycle')),
                  trailing: Text(f.money(b.investment), style: theme.textTheme.titleMedium),
                ),
              ),

            if (app.categories.any((c) => c.monthlyLimit != null))
              SectionCard(
                title: context.t('ميزانيات الفئات', 'Category budgets'),
                child: Column(children: [
                  for (final c in app.categories.where((c) => c.monthlyLimit != null))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        CategoryAvatar(c, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(c.name)),
                              Text('${f.money(app.spentIn(cycle, categoryId: c.id), withCurrency: false)} / ${f.money(c.monthlyLimit!)}',
                                  style: theme.textTheme.bodySmall),
                            ]),
                            const SizedBox(height: 4),
                            LimitBar(spent: app.spentIn(cycle, categoryId: c.id), limit: c.monthlyLimit!, color: Color(c.color)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),

            SectionCard(
              title: context.t('آخر المصاريف', 'Recent expenses'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: app.expenses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text(context.t('ما سجلت شيء بعد', 'Nothing logged yet'), textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: () => showAddExpense(context),
                          icon: const Icon(Icons.add),
                          label: Text(context.t('سجّل أول مصروف', 'Log your first expense')),
                        ),
                      ]),
                    )
                  : Column(children: [for (final e in app.expenses.take(5)) ExpenseTile(e)]),
            ),
          ],
        ),
      ),
    );
  }
}
