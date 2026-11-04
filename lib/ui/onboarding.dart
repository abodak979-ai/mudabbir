import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'obligations_screen.dart';
import 'plan_editor.dart';
import 'widgets.dart';

/// First-run setup (≤ 5 screens): salary & payday → obligations → template → first goal → plan.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int _step = 0;
  final _salary = TextEditingController();
  final _name = TextEditingController();
  int _payday = 27;
  final _obligations = <Obligation>[];
  final _plan = BudgetPlan();
  bool _emergency = true;
  int _emergencyMonths = 3;
  final _goalName = TextEditingController();
  final _goalAmount = TextEditingController();
  DateTime? _goalDate;
  bool _saving = false;

  double get salary => parseAmount(_salary.text);
  double get obligationsTotal => _obligations.fold(0, (s, o) => s + o.amount);
  PlanBreakdown get breakdown => computePlan(
        netSalary: salary,
        obligationsTotal: obligationsTotal,
        savingsMode: _plan.savingsMode,
        savingsValue: _plan.savingsValue,
        investmentMode: _plan.investmentMode,
        investmentValue: _plan.investmentValue,
      );

  bool get _canNext => switch (_step) {
        0 => salary > 0,
        2 => breakdown.isValid,
        _ => true,
      };

  Future<void> _finish() async {
    setState(() => _saving = true);
    final app = context.app;
    if (_name.text.trim().isNotEmpty) app.profile!.displayName = _name.text.trim();
    final goalAmount = parseAmount(_goalAmount.text);
    await app.completeOnboarding(
      salary: salary,
      paydayDay: _payday,
      newPlan: _plan,
      newObligations: _obligations,
      emergencyMonths: _emergency ? _emergencyMonths : null,
      firstGoal: _goalName.text.trim().isEmpty || goalAmount <= 0
          ? null
          : SavingsGoal(name: _goalName.text.trim(), targetAmount: goalAmount, targetDate: _goalDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.t('راتبك', 'Your salary'),
      context.t('التزاماتك الثابتة', 'Fixed obligations'),
      context.t('طريقة التوزيع', 'Allocation'),
      context.t('هدف ادخار', 'Savings goal'),
      context.t('خطتك جاهزة', 'Your plan'),
    ];
    final body = switch (_step) {
      0 => _salaryStep(context),
      1 => _obligationsStep(context),
      2 => PlanEditor(plan: _plan, salary: salary, obligationsTotal: obligationsTotal, onChanged: () => setState(() {})),
      3 => _goalStep(context),
      _ => _summaryStep(context),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_step]),
        leading: _step == 0 ? null : BackButton(onPressed: () => setState(() => _step--)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / titles.length),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [body]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (_step == 1 || _step == 3)
              TextButton(onPressed: () => setState(() => _step++), child: Text(context.t('تخطي', 'Skip'))),
            const Spacer(),
            FilledButton(
              onPressed: !_canNext || _saving
                  ? null
                  : () => _step == titles.length - 1 ? _finish() : setState(() => _step++),
              child: Text(_step == titles.length - 1 ? context.t('ابدأ', 'Start') : context.t('التالي', 'Next')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _salaryStep(BuildContext context) {
    final f = context.app.fmt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _name, decoration: InputDecoration(labelText: context.t('اسمك (اختياري)', 'Your name (optional)'), border: const OutlineInputBorder())),
      const SizedBox(height: 16),
      AmountField(
        controller: _salary,
        autofocus: true,
        label: context.t('الراتب الصافي الشهري', 'Monthly net salary'),
        suffix: f.currency,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        initialValue: _payday,
        decoration: InputDecoration(labelText: context.t('يوم نزول الراتب', 'Payday (day of month)'), border: const OutlineInputBorder()),
        items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text(f.n(d)))],
        onChanged: (v) => setState(() => _payday = v ?? _payday),
      ),
      const SizedBox(height: 12),
      Text(
        context.t('دورتك المالية تبدأ يوم الراتب وتنتهي قبل الراتب التالي، وليس من ١ إلى ٣٠.',
            'Your cycle runs from payday to the day before the next payday, not the 1st to the 30th.'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }

  Widget _obligationsStep(BuildContext context) {
    final f = context.app.fmt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.t('إيجار، أقساط، فواتير، اشتراكات — تُخصم من الراتب قبل أي شيء.',
          'Rent, installments, bills, subscriptions — deducted before anything else.')),
      const SizedBox(height: 12),
      for (final o in _obligations)
        Card(
          child: ListTile(
            leading: Icon(obligationIcon(o.kind)),
            title: Text(o.name),
            subtitle: Text('${f.money(o.amount)} · ${context.t('يوم', 'day')} ${f.n(o.dueDay)}'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _obligations.remove(o))),
          ),
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(context.t('إضافة التزام', 'Add obligation')),
        onPressed: () async {
          final o = await editObligation(context);
          if (o != null) setState(() => _obligations.add(o));
        },
      ),
      if (_obligations.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          context.t('المجموع ${f.money(obligationsTotal)} (${f.pct(breakdown.obligationsRatio)} من الراتب)',
              'Total ${f.money(obligationsTotal)} (${f.pct(breakdown.obligationsRatio)} of salary)'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ]);
  }

  Widget _goalStep(BuildContext context) {
    final f = context.app.fmt;
    final amount = parseAmount(_goalAmount.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.t('صندوق الطوارئ', 'Emergency fund')),
        subtitle: Text(context.t('هدف = عدد أشهر من مصاريفك الأساسية', 'Target = months of essential expenses')),
        value: _emergency,
        onChanged: (v) => setState(() => _emergency = v),
      ),
      if (_emergency)
        SegmentedButton<int>(
          segments: [for (final m in [3, 6]) ButtonSegment(value: m, label: Text(context.t('${f.n(m)} أشهر', '${f.n(m)} months')))],
          selected: {_emergencyMonths},
          onSelectionChanged: (s) => setState(() => _emergencyMonths = s.first),
        ),
      const Divider(height: 32),
      Text(context.t('هدف ادخار أول (سيارة، زواج، سفر…)', 'A first goal (car, wedding, travel…)'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      TextField(controller: _goalName, decoration: InputDecoration(labelText: context.t('اسم الهدف', 'Goal name'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      AmountField(controller: _goalAmount, label: context.t('المبلغ المستهدف', 'Target amount'), suffix: f.currency, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.event),
        label: Text(_goalDate == null ? context.t('التاريخ المستهدف', 'Target date') : f.date(_goalDate!, pattern: 'd MMMM yyyy')),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime.now().add(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
            initialDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) setState(() => _goalDate = d);
        },
      ),
      if (amount > 0 && _goalDate != null) ...[
        const SizedBox(height: 12),
        Text(
          context.t(
            'لتصل لـ ${f.money(amount)} تحتاج ${f.money(monthlyNeeded(target: amount, current: 0, today: DateTime.now(), targetDate: _goalDate!))} شهرياً',
            'To reach ${f.money(amount)} you need ${f.money(monthlyNeeded(target: amount, current: 0, today: DateTime.now(), targetDate: _goalDate!))} per month',
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ]);
  }

  Widget _summaryStep(BuildContext context) {
    final f = context.app.fmt;
    final b = breakdown;
    final cycle = cycleFor(DateTime.now(), _payday);
    final daily = dailyAllowance(spendingBudget: b.spending, spentBeforeToday: 0, daysLeft: cycle.daysLeft(DateTime.now()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        context.t(
          'من راتبك ${f.money(b.salary)}: التزامات ${f.money(b.obligations)} · ادخار ${f.money(b.savings)} · استثمار ${f.money(b.investment)} · صرف ${f.money(b.spending)}',
          'From your ${f.money(b.salary)}: obligations ${f.money(b.obligations)} · savings ${f.money(b.savings)} · investment ${f.money(b.investment)} · spending ${f.money(b.spending)}',
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      PlanSummary(breakdown: b),
      const SizedBox(height: 16),
      Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text(context.t('تقدر تصرف اليوم', 'You can spend today')),
            Text(f.money(daily), style: Theme.of(context).textTheme.displaySmall),
            Text(context.t('${f.n(cycle.daysLeft(DateTime.now()))} يوم حتى الراتب', '${f.n(cycle.daysLeft(DateTime.now()))} days until payday')),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text(context.t('تقدر تعدّل كل شيء لاحقاً من الإعدادات.', 'You can change everything later in Settings.'),
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
