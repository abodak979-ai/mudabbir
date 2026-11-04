import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

double _d(Object? v) => v == null ? 0 : (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _nowIso() => DateTime.now().toUtc().toIso8601String();

class Profile {
  final String id;
  String? displayName;
  String language;
  String numerals;
  int paydayDay;
  bool onboarded;

  Profile({
    required this.id,
    this.displayName,
    this.language = 'ar',
    this.numerals = 'western',
    this.paydayDay = 27,
    this.onboarded = false,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'],
        displayName: m['display_name'],
        language: m['language'] ?? 'ar',
        numerals: m['numerals'] ?? 'western',
        paydayDay: (m['payday_day'] as num?)?.toInt() ?? 27,
        onboarded: m['onboarded'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'language': language,
        'numerals': numerals,
        'payday_day': paydayDay,
        'onboarded': onboarded,
      };
}

class BudgetPlan {
  final String id;
  double netSalary;
  String template;
  String savingsMode;
  double savingsValue;
  String investmentMode;
  double investmentValue;
  bool emergencyFirst;
  final String createdAt;

  BudgetPlan({
    String? id,
    this.netSalary = 0,
    this.template = '50_30_20',
    this.savingsMode = 'percent',
    this.savingsValue = 12,
    this.investmentMode = 'percent',
    this.investmentValue = 8,
    this.emergencyFirst = false,
    String? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? _nowIso();

  factory BudgetPlan.fromMap(Map<String, dynamic> m) => BudgetPlan(
        id: m['id'],
        netSalary: _d(m['net_salary']),
        template: m['template'],
        savingsMode: m['savings_mode'],
        savingsValue: _d(m['savings_value']),
        investmentMode: m['investment_mode'],
        investmentValue: _d(m['investment_value']),
        emergencyFirst: m['emergency_first'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'net_salary': netSalary,
        'template': template,
        'savings_mode': savingsMode,
        'savings_value': savingsValue,
        'investment_mode': investmentMode,
        'investment_value': investmentValue,
        'emergency_first': emergencyFirst,
        'deleted': false,
        'created_at': createdAt,
      };

  BudgetPlan copy() => BudgetPlan.fromMap(toMap());
}

class Income {
  final String id;
  double amount;
  String kind;
  String? sourceName;
  DateTime receivedOn;
  String allocation;
  bool deleted;
  final String createdAt;

  Income({
    String? id,
    required this.amount,
    this.kind = 'extra',
    this.sourceName,
    DateTime? receivedOn,
    this.allocation = 'same_ratios',
    this.deleted = false,
    String? createdAt,
  })  : id = id ?? newId(),
        receivedOn = receivedOn ?? DateTime.now(),
        createdAt = createdAt ?? _nowIso();

  factory Income.fromMap(Map<String, dynamic> m) => Income(
        id: m['id'],
        amount: _d(m['amount']),
        kind: m['kind'],
        sourceName: m['source_name'],
        receivedOn: DateTime.parse(m['received_on']),
        allocation: m['allocation'] ?? 'same_ratios',
        deleted: m['deleted'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'kind': kind,
        'source_name': sourceName,
        'received_on': _day(receivedOn),
        'allocation': allocation,
        'deleted': deleted,
        'created_at': createdAt,
      };
}

class Obligation {
  final String id;
  String name;
  double amount;
  int dueDay;
  String kind;
  bool remind;
  DateTime? lastPaidOn;
  bool deleted;
  final String createdAt;

  Obligation({
    String? id,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.kind = 'bill',
    this.remind = true,
    this.lastPaidOn,
    this.deleted = false,
    String? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? _nowIso();

  factory Obligation.fromMap(Map<String, dynamic> m) => Obligation(
        id: m['id'],
        name: m['name'],
        amount: _d(m['amount']),
        dueDay: (m['due_day'] as num).toInt(),
        kind: m['kind'],
        remind: m['remind'] ?? true,
        lastPaidOn: m['last_paid_on'] == null ? null : DateTime.parse(m['last_paid_on']),
        deleted: m['deleted'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'due_day': dueDay,
        'kind': kind,
        'remind': remind,
        'last_paid_on': lastPaidOn == null ? null : _day(lastPaidOn!),
        'deleted': deleted,
        'created_at': createdAt,
      };
}

class Category {
  final String id;
  String name;
  String icon;
  int color;
  double? monthlyLimit;
  bool alertsEnabled;
  int sortOrder;
  bool deleted;
  final String createdAt;

  Category({
    String? id,
    required this.name,
    this.icon = 'other',
    this.color = 0xFF2E7D6B,
    this.monthlyLimit,
    this.alertsEnabled = true,
    this.sortOrder = 0,
    this.deleted = false,
    String? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? _nowIso();

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'],
        name: m['name'],
        icon: m['icon'] ?? 'other',
        color: (m['color'] as num?)?.toInt() ?? 0xFF2E7D6B,
        monthlyLimit: _dn(m['monthly_limit']),
        alertsEnabled: m['alerts_enabled'] ?? true,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        deleted: m['deleted'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'monthly_limit': monthlyLimit,
        'alerts_enabled': alertsEnabled,
        'sort_order': sortOrder,
        'deleted': deleted,
        'created_at': createdAt,
      };
}

class Expense {
  final String id;
  double amount;
  String? categoryId;
  DateTime spentAt;
  String? note;
  String? receiptPath; // path in the "receipts" storage bucket
  String? receiptLocal; // local file waiting to be uploaded (never sent to the server)
  String source;
  bool deleted;
  final String createdAt;

  Expense({
    String? id,
    required this.amount,
    this.categoryId,
    DateTime? spentAt,
    this.note,
    this.receiptPath,
    this.receiptLocal,
    this.source = 'manual',
    this.deleted = false,
    String? createdAt,
  })  : id = id ?? newId(),
        spentAt = spentAt ?? DateTime.now(),
        createdAt = createdAt ?? _nowIso();

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'],
        amount: _d(m['amount']),
        categoryId: m['category_id'],
        spentAt: _date(m['spent_at'])!,
        note: m['note'],
        receiptPath: m['receipt_path'],
        receiptLocal: m['receipt_local'],
        source: m['source'] ?? 'manual',
        deleted: m['deleted'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'category_id': categoryId,
        'spent_at': spentAt.toUtc().toIso8601String(),
        'note': note,
        'receipt_path': receiptPath,
        if (receiptLocal != null) 'receipt_local': receiptLocal,
        'source': source,
        'deleted': deleted,
        'created_at': createdAt,
      };
}

class SavingsGoal {
  final String id;
  String name;
  double targetAmount;
  double currentAmount;
  DateTime? targetDate;
  bool isEmergency;
  int? emergencyMonths;
  bool deleted;
  final String createdAt;

  SavingsGoal({
    String? id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.isEmergency = false,
    this.emergencyMonths,
    this.deleted = false,
    String? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? _nowIso();

  DateTime get created => DateTime.parse(createdAt).toLocal();
  double get progress => targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1).toDouble();

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
        id: m['id'],
        name: m['name'],
        targetAmount: _d(m['target_amount']),
        currentAmount: _d(m['current_amount']),
        targetDate: m['target_date'] == null ? null : DateTime.parse(m['target_date']),
        isEmergency: m['is_emergency'] ?? false,
        emergencyMonths: (m['emergency_months'] as num?)?.toInt(),
        deleted: m['deleted'] ?? false,
        createdAt: m['created_at'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date': targetDate == null ? null : _day(targetDate!),
        'is_emergency': isEmergency,
        'emergency_months': emergencyMonths,
        'deleted': deleted,
        'created_at': createdAt,
      };
}
