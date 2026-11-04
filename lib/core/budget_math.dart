// Pure salary-plan math (no Flutter imports) so it can be unit-tested.
import 'dart:math' as math;

/// Built-in allocation templates: share of net salary for savings and investment.
/// The "needs" share of each template is guidance only; actual fixed obligations
/// are always deducted at their real amount.
class PlanTemplate {
  final String id;
  final int needsPct;
  final int wantsPct;
  final double savingsPct;
  final double investmentPct;
  const PlanTemplate(this.id, this.needsPct, this.wantsPct, this.savingsPct, this.investmentPct);

  int get saveInvestPct => (savingsPct + investmentPct).round();
}

const planTemplates = <PlanTemplate>[
  PlanTemplate('50_30_20', 50, 30, 12, 8),
  PlanTemplate('70_20_10', 70, 20, 6, 4),
  PlanTemplate('40_30_30', 40, 30, 18, 12),
];

PlanTemplate? templateById(String id) {
  for (final t in planTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// Converts a percent-or-amount share into an amount of [salary].
double shareAmount(String mode, double value, double salary) =>
    mode == 'percent' ? salary * value / 100 : value;

class PlanBreakdown {
  final double salary;
  final double obligations;
  final double savings;
  final double investment;
  final double spending;

  const PlanBreakdown({
    required this.salary,
    required this.obligations,
    required this.savings,
    required this.investment,
    required this.spending,
  });

  /// Spending budget must not be negative: obligations + savings + investment ≤ salary.
  bool get isValid => spending >= 0;

  double get obligationsRatio => salary <= 0 ? 0 : obligations / salary;

  /// PRD rule: warn when fixed obligations exceed 50% of salary.
  bool get obligationsTooHigh => obligationsRatio > 0.5;

  double ratio(double part) => salary <= 0 ? 0 : part / salary;
}

/// Order of deduction: obligations → savings → investment → remaining is spending.
PlanBreakdown computePlan({
  required double netSalary,
  required double obligationsTotal,
  required String savingsMode,
  required double savingsValue,
  required String investmentMode,
  required double investmentValue,
}) {
  final savings = shareAmount(savingsMode, savingsValue, netSalary);
  final investment = shareAmount(investmentMode, investmentValue, netSalary);
  return PlanBreakdown(
    salary: netSalary,
    obligations: obligationsTotal,
    savings: savings,
    investment: investment,
    spending: netSalary - obligationsTotal - savings - investment,
  );
}

/// Extra income (bonus, side job) for the cycle, split per its allocation rule.
class ExtraIncome {
  final double amount;
  final String allocation; // same_ratios | savings | spending
  const ExtraIncome(this.amount, this.allocation);
}

PlanBreakdown addExtraIncome(PlanBreakdown base, List<ExtraIncome> extras) {
  var savings = base.savings, investment = base.investment, spending = base.spending;
  var salary = base.salary;
  final free = base.savings + base.investment + math.max(0, base.spending);
  for (final e in extras) {
    salary += e.amount;
    switch (e.allocation) {
      case 'savings':
        savings += e.amount;
      case 'spending':
        spending += e.amount;
      default:
        if (free <= 0) {
          spending += e.amount;
        } else {
          savings += e.amount * base.savings / free;
          investment += e.amount * base.investment / free;
          spending += e.amount * math.max(0, base.spending) / free;
        }
    }
  }
  return PlanBreakdown(
    salary: salary,
    obligations: base.obligations,
    savings: savings,
    investment: investment,
    spending: spending,
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Payday in a given month, clamped to the month's last day (e.g. 31 → 28 Feb).
DateTime paydayIn(int year, int month, int payday) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(payday, lastDay));
}

/// The financial cycle runs from payday up to the day before the next payday.
class Cycle {
  final DateTime start; // inclusive
  final DateTime nextPayday; // exclusive end
  const Cycle(this.start, this.nextPayday);

  DateTime get end => nextPayday.subtract(const Duration(days: 1));
  int get totalDays => _daysBetween(start, nextPayday);

  /// Days left including [today], so on the first day it equals [totalDays].
  int daysLeft(DateTime today) => math.max(1, _daysBetween(dateOnly(today), nextPayday));

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(nextPayday);

  Cycle previous(int payday) => cycleFor(start.subtract(const Duration(days: 1)), payday);

  @override
  bool operator ==(Object other) => other is Cycle && other.start == start && other.nextPayday == nextPayday;
  @override
  int get hashCode => Object.hash(start, nextPayday);
}

// Calendar-day difference that ignores DST shifts.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

Cycle cycleFor(DateTime today, int payday) {
  final d = dateOnly(today);
  final thisMonth = paydayIn(d.year, d.month, payday);
  if (!d.isBefore(thisMonth)) {
    return Cycle(thisMonth, paydayIn(d.year, d.month + 1, payday));
  }
  return Cycle(paydayIn(d.year, d.month - 1, payday), thisMonth);
}

/// Daily allowance = (spending budget − spent before today) ÷ days left until payday.
/// It is recomputed every day: spending less raises tomorrow's allowance and vice versa.
double dailyAllowance({
  required double spendingBudget,
  required double spentBeforeToday,
  required int daysLeft,
}) =>
    math.max(0, spendingBudget - spentBeforeToday) / math.max(1, daysLeft);

/// Returns the alert threshold (0.8 or 1.0) newly crossed by moving from [before] to [after]
/// of [limit], or null if none was crossed.
double? crossedThreshold(double before, double after, double limit) {
  if (limit <= 0) return null;
  for (final t in const [1.0, 0.8]) {
    if (before < limit * t && after >= limit * t) return t;
  }
  return null;
}

/// Monthly amount needed to reach a savings goal by its target date.
double monthlyNeeded({
  required double target,
  required double current,
  required DateTime today,
  required DateTime targetDate,
}) {
  final remaining = math.max(0.0, target - current);
  if (remaining == 0) return 0;
  final months = math.max(1, monthsBetween(today, targetDate));
  return remaining / months;
}

int monthsBetween(DateTime from, DateTime to) {
  var m = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day < from.day) m -= 1;
  return m;
}

/// A goal is off-track when saved amount is below 90% of the linear path from creation to target date.
bool goalOffTrack({
  required double target,
  required double current,
  required DateTime createdAt,
  required DateTime targetDate,
  required DateTime today,
}) {
  final total = targetDate.difference(createdAt).inDays;
  if (total <= 0 || current >= target) return false;
  final elapsed = today.difference(createdAt).inDays.clamp(0, total);
  final expected = target * elapsed / total;
  return current < expected * 0.9;
}

/// Emergency fund target: N months of essential spending (obligations + spending budget).
double emergencyTarget({required double monthlyExpenses, int months = 6}) => monthlyExpenses * months;
