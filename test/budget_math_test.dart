import 'package:flutter_test/flutter_test.dart';
import 'package:mudabbir/core/budget_math.dart';

void main() {
  group('computePlan (PRD example: 12,000 SAR)', () {
    final plan = computePlan(
      netSalary: 12000,
      obligationsTotal: 4000,
      savingsMode: 'percent',
      savingsValue: 15,
      investmentMode: 'percent',
      investmentValue: 10,
    );

    test('splits salary in deduction order', () {
      expect(plan.savings, 1800);
      expect(plan.investment, 1200);
      expect(plan.spending, 5000);
      expect(plan.isValid, isTrue);
      expect(plan.obligationsTooHigh, isFalse);
    });

    test('fixed amounts work like percents', () {
      final p = computePlan(
        netSalary: 12000,
        obligationsTotal: 4000,
        savingsMode: 'amount',
        savingsValue: 1800,
        investmentMode: 'amount',
        investmentValue: 1200,
      );
      expect(p.spending, 5000);
    });

    test('invalid when shares exceed salary', () {
      final p = computePlan(
        netSalary: 5000,
        obligationsTotal: 4000,
        savingsMode: 'amount',
        savingsValue: 1000,
        investmentMode: 'amount',
        investmentValue: 500,
      );
      expect(p.isValid, isFalse);
    });

    test('warns when obligations exceed 50%', () {
      final p = computePlan(
        netSalary: 9000,
        obligationsTotal: 5000,
        savingsMode: 'percent',
        savingsValue: 0,
        investmentMode: 'percent',
        investmentValue: 0,
      );
      expect(p.obligationsTooHigh, isTrue);
    });
  });

  group('daily allowance', () {
    test('first day of a 30-day cycle ≈ 166', () {
      final a = dailyAllowance(spendingBudget: 5000, spentBeforeToday: 0, daysLeft: 30);
      expect(a.floor(), 166);
    });

    test('after spending 600 in two days ≈ 157', () {
      final a = dailyAllowance(spendingBudget: 5000, spentBeforeToday: 600, daysLeft: 28);
      expect(a.floor(), 157);
    });

    test('never negative', () {
      expect(dailyAllowance(spendingBudget: 100, spentBeforeToday: 500, daysLeft: 5), 0);
    });
  });

  group('cycle', () {
    test('payday 27: Nov 4 belongs to Oct 27 – Nov 26', () {
      final c = cycleFor(DateTime(2026, 11, 4), 27);
      expect(c.start, DateTime(2026, 10, 27));
      expect(c.nextPayday, DateTime(2026, 11, 27));
      expect(c.totalDays, 31);
      expect(c.daysLeft(DateTime(2026, 11, 4)), 23);
    });

    test('on payday itself a new cycle starts', () {
      final c = cycleFor(DateTime(2026, 11, 27), 27);
      expect(c.start, DateTime(2026, 11, 27));
      expect(c.daysLeft(DateTime(2026, 11, 27)), c.totalDays);
    });

    test('payday 31 clamps to short months', () {
      final c = cycleFor(DateTime(2027, 2, 15), 31);
      expect(c.start, DateTime(2027, 1, 31));
      expect(c.nextPayday, DateTime(2027, 2, 28));
    });

    test('year boundary', () {
      final c = cycleFor(DateTime(2027, 1, 5), 25);
      expect(c.start, DateTime(2026, 12, 25));
      expect(c.previous(25).start, DateTime(2026, 11, 25));
    });
  });

  test('threshold crossing', () {
    expect(crossedThreshold(70, 85, 100), 0.8);
    expect(crossedThreshold(85, 100, 100), 1.0);
    expect(crossedThreshold(70, 120, 100), 1.0);
    expect(crossedThreshold(85, 90, 100), isNull);
    expect(crossedThreshold(0, 50, 0), isNull);
  });

  test('savings goal: 30,000 in 12 months → 2,500/month', () {
    final m = monthlyNeeded(
      target: 30000,
      current: 0,
      today: DateTime(2026, 11, 4),
      targetDate: DateTime(2027, 11, 4),
    );
    expect(m, 2500);
  });

  test('extra income split by same ratios', () {
    final base = computePlan(
      netSalary: 12000,
      obligationsTotal: 4000,
      savingsMode: 'percent',
      savingsValue: 15,
      investmentMode: 'percent',
      investmentValue: 10,
    );
    final p = addExtraIncome(base, const [ExtraIncome(800, 'same_ratios')]);
    expect(p.savings, closeTo(1800 + 180, 0.001));
    expect(p.investment, closeTo(1200 + 120, 0.001));
    expect(p.spending, closeTo(5000 + 500, 0.001));
    final s = addExtraIncome(base, const [ExtraIncome(800, 'savings')]);
    expect(s.savings, 2600);
  });
}
