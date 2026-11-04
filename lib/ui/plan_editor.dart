import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Template picker + savings/investment shares with a live breakdown and warnings.
class PlanEditor extends StatefulWidget {
  const PlanEditor({super.key, required this.plan, required this.salary, required this.obligationsTotal, required this.onChanged});
  final BudgetPlan plan;
  final double salary;
  final double obligationsTotal;
  final VoidCallback onChanged;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  late final _sav = TextEditingController(text: amountText(widget.plan.savingsValue));
  late final _inv = TextEditingController(text: amountText(widget.plan.investmentValue));

  BudgetPlan get p => widget.plan;

  void _applyTemplate(String id) {
    final t = templateById(id);
    setState(() {
      p.template = id;
      if (t != null) {
        p.savingsMode = 'percent';
        p.investmentMode = 'percent';
        p.savingsValue = t.savingsPct;
        p.investmentValue = t.investmentPct;
        _sav.text = amountText(t.savingsPct);
        _inv.text = amountText(t.investmentPct);
      }
    });
    widget.onChanged();
  }

  void _edited() {
    setState(() {
      p.template = 'custom';
      p.savingsValue = parseAmount(_sav.text);
      p.investmentValue = parseAmount(_inv.text);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final b = computePlan(
      netSalary: widget.salary,
      obligationsTotal: widget.obligationsTotal,
      savingsMode: p.savingsMode,
      savingsValue: p.savingsValue,
      investmentMode: p.investmentMode,
      investmentValue: p.investmentValue,
    );
    final cs = Theme.of(context).colorScheme;

    Widget modeToggle(String mode, ValueChanged<String> onChange) => SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 'percent', label: const Text('%')), ButtonSegment(value: 'amount', label: Text(f.currency))],
          selected: {mode},
          onSelectionChanged: (s) => onChange(s.first),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in planTemplates)
              ChoiceChip(
                label: Text('${f.n(t.needsPct)}/${f.n(t.wantsPct)}/${f.n(t.saveInvestPct)}'),
                selected: p.template == t.id,
                onSelected: (_) => _applyTemplate(t.id),
              ),
            ChoiceChip(
              label: Text(context.t('مخصص', 'Custom')),
              selected: p.template == 'custom',
              onSelected: (_) => setState(() => p.template = 'custom'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.t('احتياجات/رغبات/ادخار واستثمار. الالتزامات تُخصم دائماً بمبلغها الفعلي.',
              'Needs/wants/save & invest. Fixed obligations are always deducted at their real amount.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: AmountField(controller: _sav, label: context.t('الادخار', 'Savings'), onChanged: (_) => _edited())),
          const SizedBox(width: 8),
          modeToggle(p.savingsMode, (m) {
            setState(() => p.savingsMode = m);
            _edited();
          }),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: AmountField(controller: _inv, label: context.t('الاستثمار', 'Investment'), onChanged: (_) => _edited())),
          const SizedBox(width: 8),
          modeToggle(p.investmentMode, (m) {
            setState(() => p.investmentMode = m);
            _edited();
          }),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('صندوق الطوارئ أولاً', 'Emergency fund first')),
          subtitle: Text(context.t('اقترح تحويل جزء من الاستثمار للادخار حتى يكتمل صندوق الطوارئ',
              'Suggest moving part of investment to savings until the emergency fund is full')),
          value: p.emergencyFirst,
          onChanged: (v) {
            setState(() => p.emergencyFirst = v);
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        PlanSummary(breakdown: b),
        if (b.obligationsTooHigh)
          Card(
            color: cs.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(context.t('التزاماتك أكثر من نصف راتبك (${f.pct(b.obligationsRatio)})',
                  'Obligations exceed half your salary (${f.pct(b.obligationsRatio)})')),
              subtitle: Text(context.t('ننصح بقالب 70/20/10', 'We suggest the 70/20/10 template')),
              trailing: p.template == '70_20_10'
                  ? null
                  : TextButton(onPressed: () => _applyTemplate('70_20_10'), child: Text(context.t('طبّق', 'Apply'))),
            ),
          ),
        if (!b.isValid)
          Card(
            color: cs.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.t('المجموع أكبر من الراتب', 'Total exceeds your salary')),
              subtitle: Text(context.t('قلّل الادخار أو الاستثمار', 'Lower savings or investment')),
            ),
          ),
      ],
    );
  }
}

class PlanSummary extends StatelessWidget {
  const PlanSummary({super.key, required this.breakdown});
  final PlanBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final f = context.app.fmt;
    final b = breakdown;
    Widget row(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(f.money(v), style: const TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(width: 56, child: Text(f.pct(b.ratio(v)), textAlign: TextAlign.end)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          row(context.t('التزامات ثابتة', 'Fixed obligations'), b.obligations, shareColors[0]),
          row(context.t('ادخار', 'Savings'), b.savings, shareColors[1]),
          row(context.t('استثمار', 'Investment'), b.investment, shareColors[2]),
          row(context.t('ميزانية الصرف', 'Spending budget'), b.spending, shareColors[3]),
        ]),
      ),
    );
  }
}

const shareColors = [Color(0xFF78909C), Color(0xFF2E7D6B), Color(0xFF3F51B5), Color(0xFFEF8F00)];
