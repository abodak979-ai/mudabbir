import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'plan_editor.dart';
import 'widgets.dart';

Future<void> editGoal(BuildContext context, [SavingsGoal? existing]) async {
  final app = context.app;
  final f = app.fmt;
  final name = TextEditingController(text: existing?.name);
  final target = TextEditingController(text: amountText(existing?.targetAmount ?? 0));
  final current = TextEditingController(text: amountText(existing?.currentAmount ?? 0));
  DateTime? date = existing?.targetDate;
  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(existing == null ? context.t('هدف جديد', 'New goal') : context.t('تعديل الهدف', 'Edit goal')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: context.t('الاسم', 'Name'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            AmountField(controller: target, label: context.t('المبلغ المستهدف', 'Target'), suffix: f.currency, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            AmountField(controller: current, label: context.t('المدّخر حالياً', 'Saved so far'), suffix: f.currency, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(date == null ? context.t('التاريخ المستهدف', 'Target date') : f.date(date!, pattern: 'd MMMM yyyy')),
              onPressed: () async {
                final d = await showDatePicker(
                  context: c,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                  initialDate: date ?? DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => date = d);
              },
            ),
            if (date != null && parseAmount(target.text) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(context.t(
                  'تحتاج ${f.money(monthlyNeeded(target: parseAmount(target.text), current: parseAmount(current.text), today: DateTime.now(), targetDate: date!))} شهرياً',
                  'You need ${f.money(monthlyNeeded(target: parseAmount(target.text), current: parseAmount(current.text), today: DateTime.now(), targetDate: date!))} per month',
                )),
              ),
          ]),
        ),
        actions: [
          if (existing != null && !existing.isEmergency)
            TextButton(
              onPressed: () async {
                Navigator.pop(c, false);
                await app.deleteGoal(existing);
              },
              child: Text(context.t('حذف', 'Delete')),
            ),
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty && parseAmount(target.text) > 0),
            child: Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
    ),
  );
  if (saved != true) return;
  final g = existing ?? SavingsGoal(name: '', targetAmount: 1);
  g
    ..name = name.text.trim()
    ..targetAmount = parseAmount(target.text)
    ..currentAmount = parseAmount(current.text)
    ..targetDate = date;
  await app.saveGoal(g);
}

Future<void> addContribution(BuildContext context, SavingsGoal g) async {
  final app = context.app;
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(context.t('إضافة إلى ${g.name}', 'Add to ${g.name}')),
      content: AmountField(controller: ctrl, autofocus: true, label: context.t('المبلغ', 'Amount'), suffix: app.fmt.currency),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.t('إضافة', 'Add'))),
      ],
    ),
  );
  final v = parseAmount(ctrl.text);
  if (ok == true && v > 0) {
    g.currentAmount += v;
    await app.saveGoal(g);
  }
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final b = app.breakdown;
    final theme = Theme.of(context);
    final emergency = app.emergencyGoal;
    final emergencyIncomplete = emergency != null && emergency.currentAmount < emergency.targetAmount;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('الأهداف', 'Goals'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goal',
        onPressed: () => editGoal(context),
        icon: const Icon(Icons.flag_outlined),
        label: Text(context.t('هدف جديد', 'New goal')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SectionCard(
            title: context.t('حصص هذه الدورة', 'This cycle\'s shares'),
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.savings_outlined, color: shareColors[1]),
                title: Text(context.t('للادخار', 'To savings')),
                trailing: Text(f.money(b.savings), style: theme.textTheme.titleMedium),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.trending_up, color: shareColors[2]),
                title: Text(context.t('جاهز للاستثمار', 'Ready to invest')),
                trailing: Text(f.money(b.investment), style: theme.textTheme.titleMedium),
              ),
              if (app.plan?.emergencyFirst == true && emergencyIncomplete && b.investment > 0)
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.lightbulb_outline),
                    title: Text(context.t('صندوق الطوارئ أولاً', 'Emergency fund first')),
                    subtitle: Text(context.t(
                      'اقتراح: حوّل ${f.money(b.investment / 2)} من حصة الاستثمار إلى صندوق الطوارئ حتى يكتمل',
                      'Suggestion: move ${f.money(b.investment / 2)} of investment into the emergency fund until it is full',
                    )),
                  ),
                ),
            ]),
          ),
          if (app.goals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.t('أضف هدفاً بمبلغ وتاريخ ونحسب لك المبلغ الشهري', 'Add a goal with an amount and date and we\'ll compute the monthly amount'),
                  textAlign: TextAlign.center),
            ),
          for (final g in app.goals) _GoalCard(g),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.t('محتوى الاستثمار في التطبيق تعليمي فقط وليس توصية مالية.', 'Investment content in this app is educational only, not financial advice.'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard(this.g);
  final SavingsGoal g;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthly = g.targetDate == null
        ? null
        : monthlyNeeded(target: g.targetAmount, current: g.currentAmount, today: now, targetDate: g.targetDate!);
    final offTrack = g.targetDate != null &&
        goalOffTrack(target: g.targetAmount, current: g.currentAmount, createdAt: g.created, targetDate: g.targetDate!, today: now);
    final done = g.currentAmount >= g.targetAmount;
    final emergencyTarget = g.isEmergency ? g.emergencyMonths : null;

    return SectionCard(
      title: g.name,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (done) Chip(label: Text(context.t('تحقق 🎉', 'Done 🎉'))),
        if (offTrack && !done)
          Chip(
            label: Text(context.t('متأخر عن المسار', 'Behind schedule')),
            backgroundColor: theme.colorScheme.errorContainer,
          ),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editGoal(context, g), tooltip: context.t('تعديل', 'Edit')),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LimitBar(spent: g.currentAmount, limit: g.targetAmount, color: shareColors[1]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${f.money(g.currentAmount)} / ${f.money(g.targetAmount)}')),
          Text(f.pct(g.progress)),
        ]),
        if (emergencyTarget != null)
          Text(context.t('${f.n(emergencyTarget)} أشهر من مصاريفك الأساسية', '${f.n(emergencyTarget)} months of essential expenses'),
              style: theme.textTheme.bodySmall),
        if (monthly != null && !done)
          Text(
            context.t(
              'تحتاج ${f.money(monthly)} شهرياً حتى ${f.date(g.targetDate!, pattern: 'MMMM yyyy')}',
              'You need ${f.money(monthly)}/month until ${f.date(g.targetDate!, pattern: 'MMMM yyyy')}',
            ),
            style: theme.textTheme.bodySmall,
          ),
        if (g.isEmergency && !done)
          TextButton(
            onPressed: () async {
              g.targetAmount = math.max(1, emergencyTargetFor(app, g.emergencyMonths ?? 3));
              await app.saveGoal(g);
            },
            child: Text(context.t('حدّث المبلغ حسب مصاريفك الحالية', 'Recalculate from current expenses')),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.tonalIcon(
            onPressed: () => addContribution(context, g),
            icon: const Icon(Icons.add),
            label: Text(context.t('أضف مبلغ', 'Add money')),
          ),
        ),
      ]),
    );
  }
}

double emergencyTargetFor(AppState app, int months) => emergencyTarget(monthlyExpenses: app.monthlyEssentials, months: months);
