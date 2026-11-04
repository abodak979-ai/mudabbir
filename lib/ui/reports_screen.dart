import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../state/app_state.dart';
import 'plan_editor.dart';
import 'widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialOffset = 0});
  final int initialOffset;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _offset = widget.initialOffset;

  @override
  void didUpdateWidget(ReportsScreen old) {
    super.didUpdateWidget(old);
    if (old.initialOffset != widget.initialOffset) _offset = widget.initialOffset;
  }

  Cycle _cycleAt(AppState app, int offset) {
    var c = app.cycle;
    for (var i = 0; i < offset; i++) {
      c = c.previous(app.payday);
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final theme = Theme.of(context);
    final cycle = _cycleAt(app, _offset);
    final b = app.breakdownFor(cycle);
    final spent = app.spentIn(cycle);
    final balance = b.spending - spent;
    final finished = _offset > 0;

    final byCategory = <String?, double>{};
    for (final e in app.expensesIn(cycle)) {
      byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: Text(context.t('التقارير', 'Reports'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Row(children: [
            IconButton(onPressed: () => setState(() => _offset++), icon: const Icon(Icons.chevron_left), tooltip: context.t('الدورة السابقة', 'Previous cycle')),
            Expanded(
              child: Column(children: [
                Text(_offset == 0 ? context.t('الدورة الحالية', 'Current cycle') : context.t('دورة سابقة', 'Past cycle'), style: theme.textTheme.labelMedium),
                Text('${f.date(cycle.start)} – ${f.date(cycle.end)}', style: theme.textTheme.titleMedium),
              ]),
            ),
            IconButton(
              onPressed: _offset == 0 ? null : () => setState(() => _offset--),
              icon: const Icon(Icons.chevron_right),
              tooltip: context.t('الدورة التالية', 'Next cycle'),
            ),
          ]),
          SectionCard(
            title: context.t('ملخص الدورة', 'Cycle summary'),
            child: Column(children: [
              _row(context, context.t('الدخل', 'Income'), f.money(b.salary)),
              _row(context, context.t('التزامات ثابتة', 'Fixed obligations'), f.money(b.obligations)),
              _row(context, context.t('ادخار مخصص', 'Savings set aside'), f.money(b.savings)),
              _row(context, context.t('استثمار مخصص', 'Investment set aside'), f.money(b.investment)),
              const Divider(),
              _row(context, context.t('ميزانية الصرف', 'Spending budget'), f.money(b.spending)),
              _row(context, context.t('المصروف الفعلي', 'Actually spent'), f.money(spent)),
              _row(
                context,
                balance >= 0
                    ? (finished ? context.t('فائض', 'Surplus') : context.t('متبقي', 'Remaining'))
                    : context.t('عجز', 'Deficit'),
                f.money(balance.abs()),
                color: balance >= 0 ? Colors.green : theme.colorScheme.error,
              ),
              if (finished && balance > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.t('أحسنت! وفّرت ${f.money(balance)} من ميزانية الصرف. فكّر تضيفها لأحد أهدافك.',
                        'Well done! You saved ${f.money(balance)} of your spending budget. Consider adding it to a goal.'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ]),
          ),
          if (sorted.isNotEmpty)
            SectionCard(
              title: context.t('توزيع المصاريف', 'Spending breakdown'),
              child: Column(children: [
                SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: [
                      for (final e in sorted)
                        PieChartSectionData(
                          value: e.value,
                          color: Color(app.categoryById(e.key)?.color ?? 0xFF9E9E9E),
                          radius: 44,
                          title: spent <= 0 ? '' : f.pct(e.value / spent),
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          showTitle: e.value / math.max(1, spent) > 0.06,
                        ),
                    ],
                  )),
                ),
                const SizedBox(height: 12),
                for (final e in sorted) _categoryRow(context, app, cycle, e.key, e.value),
              ]),
            ),
          SectionCard(
            title: context.t('الاتجاه عبر الدورات', 'Trend across cycles'),
            child: SizedBox(height: 200, child: _TrendChart(cycles: [for (var i = 5; i >= 0; i--) _cycleAt(app, _offset + i)])),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _categoryRow(BuildContext context, AppState app, Cycle cycle, String? id, double spent) {
    final f = app.fmt;
    final c = app.categoryById(id);
    final limit = c?.monthlyLimit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CategoryAvatar(c, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c?.name ?? context.t('بدون فئة', 'Uncategorized'))),
              Text(limit == null ? f.money(spent) : '${f.money(spent, withCurrency: false)} / ${f.money(limit)}'),
            ]),
            if (limit != null) ...[const SizedBox(height: 4), LimitBar(spent: spent, limit: limit, color: Color(c!.color))],
          ]),
        ),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.cycles});
  final List<Cycle> cycles;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final cs = Theme.of(context).colorScheme;
    final spent = [for (final c in cycles) app.spentIn(c)];
    final budget = [for (final c in cycles) math.max(0.0, app.breakdownFor(c).spending)];
    final maxY = math.max(1.0, [...spent, ...budget].reduce(math.max) * 1.15);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !app.hideAmounts,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(f.n(v), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= cycles.length) return const SizedBox();
                return Text(f.date(cycles[i].start, pattern: 'MMM'), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < cycles.length; i++) FlSpot(i.toDouble(), spent[i])],
            isCurved: true,
            color: shareColors[3],
            barWidth: 3,
            dotData: const FlDotData(),
          ),
          LineChartBarData(
            spots: [for (var i = 0; i < cycles.length; i++) FlSpot(i.toDouble(), budget[i])],
            color: cs.outline,
            barWidth: 2,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
      )),
    );
  }
}
