import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/budget_math.dart';
import '../core/format.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../data/sync.dart';
import '../services/notifications.dart';

class AppState extends ChangeNotifier {
  AppState(this.db, this.prefs) : sync = SyncService(db, Supabase.instance.client);

  final LocalDb db;
  final SharedPreferences prefs;
  final SyncService sync;
  SupabaseClient get sb => Supabase.instance.client;

  Profile? profile;
  BudgetPlan? plan;
  List<Category> categories = [];
  List<Obligation> obligations = [];
  List<Income> incomes = [];
  List<Expense> expenses = []; // newest first
  List<SavingsGoal> goals = [];
  bool syncing = false;
  int pending = 0;
  bool loaded = false;

  StreamSubscription? _authSub, _netSub;

  // ---------- preferences (device-only) ----------
  String get language => profile?.language ?? prefs.getString('lang') ?? 'ar';
  bool get ar => language == 'ar';
  bool get arabicDigits => (profile?.numerals ?? 'western') == 'arabic';
  bool get hideAmounts => prefs.getBool('hide') ?? false;
  bool get lockEnabled => prefs.getBool('lock') ?? false;
  bool get eveningReminder => prefs.getBool('evening') ?? true;
  Fmt get fmt => Fmt(ar: ar, arabicDigits: arabicDigits, hidden: hideAmounts);
  String t(String arText, String enText) => ar ? arText : enText;

  Future<void> setPref(String key, bool v) async {
    await prefs.setBool(key, v);
    notifyListeners();
    if (key == 'evening') await rescheduleReminders();
  }

  Future<void> setLanguage(String lang) async {
    await prefs.setString('lang', lang);
    if (profile != null) {
      profile!.language = lang;
      await saveProfile();
    } else {
      notifyListeners();
    }
  }

  bool get signedIn => sb.auth.currentSession != null;

  Future<void> init() async {
    _authSub = sb.auth.onAuthStateChange.listen((s) async {
      if (s.event == AuthChangeEvent.signedIn) await _afterSignIn();
      if (s.event == AuthChangeEvent.signedOut) notifyListeners();
    });
    _netSub = Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) syncNow();
    });
    if (signedIn) {
      await loadLocal();
      unawaited(syncNow());
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _afterSignIn() async {
    await loadLocal();
    await syncNow();
    if (profile == null) {
      profile = Profile(id: sb.auth.currentUser!.id, language: prefs.getString('lang') ?? 'ar');
      await db.put('profiles', profile!.toMap());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _netSub?.cancel();
    super.dispose();
  }

  Future<void> loadLocal() async {
    final uid = sb.auth.currentUser?.id;
    final profiles = await db.all('profiles');
    final p = profiles.where((m) => m['id'] == uid);
    profile = p.isEmpty ? null : Profile.fromMap(p.first);
    final plans = (await db.all('budget_plans')).map(BudgetPlan.fromMap).toList();
    plan = plans.isEmpty ? null : plans.first;
    categories = (await db.all('categories')).map(Category.fromMap).where((c) => !c.deleted).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    obligations = (await db.all('fixed_obligations')).map(Obligation.fromMap).where((o) => !o.deleted).toList()
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
    incomes = (await db.all('incomes')).map(Income.fromMap).where((i) => !i.deleted).toList();
    expenses = (await db.all('expenses')).map(Expense.fromMap).where((e) => !e.deleted).toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    goals = (await db.all('savings_goals')).map(SavingsGoal.fromMap).where((g) => !g.deleted).toList()
      ..sort((a, b) => (b.isEmergency ? 1 : 0).compareTo(a.isEmergency ? 1 : 0));
    pending = await db.pendingCount();
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!signedIn || syncing) return;
    syncing = true;
    notifyListeners();
    await sync.run();
    syncing = false;
    await loadLocal();
    await rescheduleReminders();
  }

  Future<void> _save(String tbl, Map<String, dynamic> row) async {
    await db.put(tbl, row);
    await loadLocal();
    unawaited(syncNow());
  }

  // ---------- derived numbers ----------
  DateTime get now => DateTime.now();
  int get payday => profile?.paydayDay ?? 27;
  Cycle get cycle => cycleFor(now, payday);
  double get obligationsTotal => obligations.fold(0, (s, o) => s + o.amount);

  PlanBreakdown breakdownFor(Cycle c) {
    final p = plan ?? BudgetPlan();
    final base = computePlan(
      netSalary: p.netSalary,
      obligationsTotal: obligationsTotal,
      savingsMode: p.savingsMode,
      savingsValue: p.savingsValue,
      investmentMode: p.investmentMode,
      investmentValue: p.investmentValue,
    );
    final extras = [
      for (final i in incomes)
        if (i.kind == 'extra' && c.contains(dateOnly(i.receivedOn))) ExtraIncome(i.amount, i.allocation),
    ];
    return addExtraIncome(base, extras);
  }

  PlanBreakdown get breakdown => breakdownFor(cycle);

  Iterable<Expense> expensesIn(Cycle c) => expenses.where((e) => c.contains(e.spentAt));

  double spentIn(Cycle c, {String? categoryId}) => expensesIn(c)
      .where((e) => categoryId == null || e.categoryId == categoryId)
      .fold(0.0, (s, e) => s + e.amount);

  double get spentToday {
    final today = dateOnly(now);
    return expenses.where((e) => dateOnly(e.spentAt) == today).fold(0.0, (s, e) => s + e.amount);
  }

  double get spentThisCycle => spentIn(cycle);

  /// Today's allowance is fixed at the start of the day; spending today reduces "remaining today".
  double get todayAllowance => dailyAllowance(
        spendingBudget: breakdown.spending,
        spentBeforeToday: spentThisCycle - spentToday,
        daysLeft: cycle.daysLeft(now),
      );

  double get remainingToday => todayAllowance - spentToday;

  Category? categoryById(String? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The due date of an obligation inside cycle [c].
  DateTime dueDateIn(Obligation o, Cycle c) {
    var d = paydayIn(c.start.year, c.start.month, o.dueDay);
    if (d.isBefore(c.start)) d = paydayIn(c.start.year, c.start.month + 1, o.dueDay);
    return d;
  }

  bool isPaid(Obligation o, Cycle c) => o.lastPaidOn != null && c.contains(dateOnly(o.lastPaidOn!));

  double get obligationsPaidThisCycle =>
      obligations.where((o) => isPaid(o, cycle)).fold(0.0, (s, o) => s + o.amount);

  List<Obligation> get upcomingBills {
    final today = dateOnly(now);
    return obligations.where((o) {
      if (isPaid(o, cycle)) return false;
      final due = dueDateIn(o, cycle);
      return due.difference(today).inDays <= 3;
    }).toList();
  }

  SavingsGoal? get emergencyGoal {
    for (final g in goals) {
      if (g.isEmergency) return g;
    }
    return null;
  }

  double get monthlyEssentials => obligationsTotal + math.max(0, breakdown.spending);

  // ---------- mutations ----------
  Future<void> saveProfile() async => _save('profiles', profile!.toMap());

  Future<void> savePlan(BudgetPlan p) async => _save('budget_plans', p.toMap());

  Future<void> saveObligation(Obligation o) async => _save('fixed_obligations', o.toMap());

  Future<void> deleteObligation(Obligation o) async {
    o.deleted = true;
    await saveObligation(o);
  }

  Future<void> markPaid(Obligation o) async {
    o.lastPaidOn = dateOnly(now);
    await saveObligation(o);
  }

  Future<void> saveCategory(Category c) async => _save('categories', c.toMap());

  Future<void> deleteCategory(Category c) async {
    c.deleted = true;
    await saveCategory(c);
  }

  Future<void> saveIncome(Income i) async => _save('incomes', i.toMap());

  Future<void> saveGoal(SavingsGoal g) async => _save('savings_goals', g.toMap());

  Future<void> deleteGoal(SavingsGoal g) async {
    g.deleted = true;
    await saveGoal(g);
  }

  Future<void> deleteExpense(Expense e) async {
    e.deleted = true;
    await _save('expenses', e.toMap());
  }

  /// Saves an expense and fires 80% / 100% alerts for its category and the daily allowance.
  Future<void> saveExpense(Expense e, {Expense? previous}) async {
    final c = cycle;
    final cat = categoryById(e.categoryId);
    final catBefore = cat == null ? 0.0 : spentIn(c, categoryId: cat.id);
    final allowance = todayAllowance;
    final todayBefore = spentToday;
    final isToday = dateOnly(e.spentAt) == dateOnly(now);

    await _save('expenses', e.toMap());

    if (previous != null) return; // edits don't re-trigger alerts
    if (cat != null && cat.alertsEnabled && cat.monthlyLimit != null && c.contains(e.spentAt)) {
      final th = crossedThreshold(catBefore, catBefore + e.amount, cat.monthlyLimit!);
      if (th != null) {
        await Notifications.show(
          cat.id.hashCode & 0x7fffffff,
          th >= 1 ? t('تجاوزت حد ${cat.name}', '${cat.name} limit exceeded') : t('اقتربت من حد ${cat.name}', 'Nearing ${cat.name} limit'),
          t('صرفت ${fmt.pct((catBefore + e.amount) / cat.monthlyLimit!)} من ميزانية ${cat.name} لهذه الدورة',
              'You used ${fmt.pct((catBefore + e.amount) / cat.monthlyLimit!)} of your ${cat.name} budget this cycle'),
        );
      }
    }
    if (isToday && prefs.getBool('dailyAlerts') != false) {
      final th = crossedThreshold(todayBefore, todayBefore + e.amount, allowance);
      if (th != null) {
        await Notifications.show(
          3,
          th >= 1 ? t('تجاوزت حدك اليومي', 'Daily limit exceeded') : t('اقتربت من حدك اليومي', 'Nearing your daily limit'),
          t('حدك اليوم ${fmt.money(allowance)} وصرفت ${fmt.money(todayBefore + e.amount)}',
              'Today\'s limit is ${fmt.money(allowance)}; you spent ${fmt.money(todayBefore + e.amount)}'),
        );
      }
    }
  }

  /// First-run setup: profile, plan, obligations, default categories, optional goals.
  Future<void> completeOnboarding({
    required double salary,
    required int paydayDay,
    required BudgetPlan newPlan,
    required List<Obligation> newObligations,
    SavingsGoal? firstGoal,
    int? emergencyMonths,
  }) async {
    profile!
      ..paydayDay = paydayDay
      ..onboarded = true;
    await db.put('profiles', profile!.toMap());
    newPlan.netSalary = salary;
    await db.put('budget_plans', newPlan.toMap());
    for (final o in newObligations) {
      await db.put('fixed_obligations', o.toMap());
    }
    if (categories.isEmpty) {
      for (final c in defaultCategories(ar)) {
        await db.put('categories', c.toMap());
      }
    }
    if (firstGoal != null) await db.put('savings_goals', firstGoal.toMap());
    if (emergencyMonths != null && emergencyGoal == null) {
      final b = computePlan(
        netSalary: salary,
        obligationsTotal: newObligations.fold(0.0, (s, o) => s + o.amount),
        savingsMode: newPlan.savingsMode,
        savingsValue: newPlan.savingsValue,
        investmentMode: newPlan.investmentMode,
        investmentValue: newPlan.investmentValue,
      );
      await db.put(
        'savings_goals',
        SavingsGoal(
          name: t('صندوق الطوارئ', 'Emergency fund'),
          targetAmount: math.max(1, emergencyTarget(monthlyExpenses: b.obligations + math.max(0, b.spending), months: emergencyMonths)),
          isEmergency: true,
          emergencyMonths: emergencyMonths,
        ).toMap(),
      );
    }
    await loadLocal();
    await Notifications.requestPermission();
    unawaited(syncNow());
  }

  Future<void> rescheduleReminders() async {
    if (profile == null) return;
    await Notifications.cancelScheduled();
    final c = cycle;
    var i = 0;
    for (final o in obligations.where((o) => o.remind)) {
      var due = dueDateIn(o, c);
      if (isPaid(o, c)) due = dueDateIn(o, cycleFor(c.nextPayday, payday));
      final at = DateTime(due.year, due.month, due.day, 10);
      await Notifications.scheduleAt(1000 + i * 2, at.subtract(const Duration(days: 3)),
          t('${o.name} بعد ٣ أيام', '${o.name} due in 3 days'), t('المبلغ ${fmt.money(o.amount)}', 'Amount ${fmt.money(o.amount)}'));
      await Notifications.scheduleAt(1001 + i * 2, at, t('اليوم موعد ${o.name}', '${o.name} is due today'),
          t('لا تنسَ تسجيل الدفع في مُدبِّر', 'Mark it as paid in Mudabbir'));
      i++;
    }
    final nextPay = c.nextPayday;
    await Notifications.scheduleAt(Notifications.paydayId, DateTime(nextPay.year, nextPay.month, nextPay.day, 9),
        t('نزل راتبك 🎉', 'Payday 🎉'), t('ادّخر واستثمر أولاً، وشوف ملخص الدورة الماضية', 'Pay yourself first and check last cycle\'s summary'));
    if (eveningReminder) {
      await Notifications.scheduleDaily(Notifications.eveningId, 21, t('سجّلت مصاريف اليوم؟', 'Logged today\'s spending?'),
          t('ثلاث ضغطات وتخلص', 'It takes three taps'));
    }
  }

  // ---------- account ----------
  Future<void> signOut() async {
    await Notifications.cancelScheduled();
    await db.clear();
    profile = null;
    plan = null;
    categories = [];
    obligations = [];
    incomes = [];
    expenses = [];
    goals = [];
    await sb.auth.signOut();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await sb.rpc('delete_my_account');
    await signOut();
  }
}

List<Category> defaultCategories(bool ar) {
  String n(String a, String e) => ar ? a : e;
  final list = [
    (n('أكل وبقالة', 'Groceries'), 'groceries', 0xFF2E7D32),
    (n('مطاعم وقهوة', 'Dining & coffee'), 'restaurant', 0xFFEF6C00),
    (n('مواصلات', 'Transport'), 'transport', 0xFF1565C0),
    (n('تسوق', 'Shopping'), 'shopping', 0xFF8E24AA),
    (n('ترفيه', 'Entertainment'), 'fun', 0xFFD81B60),
    (n('صحة', 'Health'), 'health', 0xFF00897B),
    (n('أخرى', 'Other'), 'other', 0xFF607D8B),
  ];
  return [
    for (var i = 0; i < list.length; i++)
      Category(name: list[i].$1, icon: list[i].$2, color: list[i].$3, sortOrder: i),
  ];
}

/// Makes [AppState] available to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
  String t(String arText, String enText) => app.t(arText, enText);
}
