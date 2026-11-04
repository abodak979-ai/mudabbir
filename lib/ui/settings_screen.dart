import 'package:flutter/material.dart';

import '../core/budget_math.dart';
import '../data/models.dart';
import '../services/app_lock.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import 'obligations_screen.dart';
import 'plan_editor.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final p = app.profile!;
    Widget header(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(s, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.t('الإعدادات', 'Settings'))),
      body: ListView(children: [
        header(context.t('الراتب والخطة', 'Salary & plan')),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(context.t('الراتب وقالب التوزيع', 'Salary & allocation')),
          subtitle: Text(f.money(app.plan?.netSalary ?? 0)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(context.t('يوم نزول الراتب', 'Payday')),
          trailing: DropdownButton<int>(
            value: p.paydayDay,
            underline: const SizedBox(),
            items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text(f.n(d)))],
            onChanged: (v) {
              if (v == null) return;
              p.paydayDay = v;
              app.saveProfile();
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(context.t('الالتزامات الثابتة', 'Fixed obligations')),
          subtitle: Text(f.money(app.obligationsTotal)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ObligationsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(context.t('الفئات وحدودها', 'Categories & limits')),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.add_card_outlined),
          title: Text(context.t('دخل إضافي', 'Extra income')),
          subtitle: Text(context.t('بونص، عمل جانبي…', 'Bonus, side job…')),
          onTap: () => addExtraIncomeDialog(context),
        ),

        header(context.t('اللغة والعرض', 'Language & display')),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(context.t('اللغة', 'Language')),
          trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'ar', label: Text('ع')), ButtonSegment(value: 'en', label: Text('EN'))],
            selected: {app.language},
            onSelectionChanged: (s) => app.setLanguage(s.first),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: Text(context.t('الأرقام', 'Numerals')),
          trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'western', label: Text('123')), ButtonSegment(value: 'arabic', label: Text('١٢٣'))],
            selected: {p.numerals},
            onSelectionChanged: (s) {
              p.numerals = s.first;
              app.saveProfile();
            },
          ),
        ),

        header(context.t('الأمان والخصوصية', 'Security & privacy')),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(context.t('قفل التطبيق بالبصمة/الوجه أو رمز الجهاز', 'Lock with biometrics or device PIN')),
          value: app.lockEnabled,
          onChanged: (v) async {
            if (v && !await AppLock.authenticate(context.t('فعّل قفل مُدبِّر', 'Enable Mudabbir lock'))) {
              if (context.mounted) toast(context, context.t('القفل غير متاح على هذا الجهاز', 'Lock is not available on this device'));
              return;
            }
            await app.setPref('lock', v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: Text(context.t('إخفاء الأرقام', 'Hide amounts')),
          value: app.hideAmounts,
          onChanged: (v) => app.setPref('hide', v),
        ),

        header(context.t('التنبيهات', 'Notifications')),
        SwitchListTile(
          secondary: const Icon(Icons.today_outlined),
          title: Text(context.t('تنبيه ٨٠٪ و١٠٠٪ من الحد اليومي', '80% & 100% daily limit alerts')),
          value: app.prefs.getBool('dailyAlerts') ?? true,
          onChanged: (v) => app.setPref('dailyAlerts', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.nightlight_outlined),
          title: Text(context.t('تذكير مسائي بتسجيل المصاريف', 'Evening reminder to log spending')),
          value: app.eveningReminder,
          onChanged: (v) => app.setPref('evening', v),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(context.t('السماح بالإشعارات', 'Allow notifications')),
          onTap: Notifications.requestPermission,
        ),

        header(context.t('الحساب', 'Account')),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(context.t('الاسم', 'Name')),
          subtitle: Text(p.displayName ?? '—'),
          onTap: () async {
            final c = TextEditingController(text: p.displayName);
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                content: TextField(controller: c, autofocus: true),
                actions: [FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(context.t('حفظ', 'Save')))],
              ),
            );
            if (ok == true) {
              p.displayName = c.text.trim();
              await app.saveProfile();
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: Text(context.t('مزامنة الآن', 'Sync now')),
          subtitle: Text(app.pending == 0
              ? context.t('كل البيانات متزامنة', 'Everything is synced')
              : context.t('${f.n(app.pending)} تغيير بانتظار الاتصال', '${f.n(app.pending)} changes waiting for connection')),
          onTap: app.syncNow,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(context.t('تسجيل الخروج', 'Sign out')),
          onTap: () async {
            final warn = app.pending > 0
                ? context.t('عندك تغييرات لم تُزامن وستُفقد.', 'You have unsynced changes that will be lost.')
                : '';
            if (await confirmDialog(context, context.t('تسجيل الخروج؟', 'Sign out?'), warn)) {
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
              await app.signOut();
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(context.t('حذف الحساب وكل البيانات', 'Delete account and all data'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () async {
            if (await confirmDialog(
              context,
              context.t('حذف الحساب نهائياً؟', 'Delete account permanently?'),
              context.t('ستُحذف كل بياناتك من الخادم ولا يمكن التراجع.', 'All your data will be deleted from the server. This cannot be undone.'),
            )) {
              try {
                if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                await app.deleteAccount();
              } catch (_) {
                if (context.mounted) toast(context, context.t('تعذر الحذف، تأكد من الاتصال', 'Could not delete, check your connection'));
              }
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.t('مُدبِّر لا يحرّك أموالك. محتوى الاستثمار تعليمي فقط وليس توصية مالية.',
                'Mudabbir never moves your money. Investment content is educational only, not financial advice.'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final BudgetPlan _plan = (context.app.plan ?? BudgetPlan()).copy();
  late final _salary = TextEditingController(text: amountText(_plan.netSalary));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final salary = parseAmount(_salary.text);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('الراتب والتوزيع', 'Salary & allocation'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AmountField(
          controller: _salary,
          label: context.t('الراتب الصافي الشهري', 'Monthly net salary'),
          suffix: app.fmt.currency,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PlanEditor(plan: _plan, salary: salary, obligationsTotal: app.obligationsTotal, onChanged: () => setState(() {})),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: salary <= 0
                ? null
                : () async {
                    final b = computePlan(
                      netSalary: salary,
                      obligationsTotal: app.obligationsTotal,
                      savingsMode: _plan.savingsMode,
                      savingsValue: _plan.savingsValue,
                      investmentMode: _plan.investmentMode,
                      investmentValue: _plan.investmentValue,
                    );
                    if (!b.isValid) return;
                    _plan.netSalary = salary;
                    await app.savePlan(_plan);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(context.t('حفظ', 'Save')),
          ),
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, [Category? existing]) async {
    final app = context.app;
    final name = TextEditingController(text: existing?.name);
    final limit = TextEditingController(text: amountText(existing?.monthlyLimit ?? 0));
    var icon = existing?.icon ?? 'other';
    var color = existing?.color ?? categoryColors.first;
    var alerts = existing?.alertsEnabled ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(existing == null ? context.t('فئة جديدة', 'New category') : context.t('تعديل الفئة', 'Edit category')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: context.t('الاسم', 'Name'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              AmountField(controller: limit, label: context.t('الحد الشهري (اختياري)', 'Monthly limit (optional)'), suffix: app.fmt.currency),
              const SizedBox(height: 12),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final e in categoryIcons.entries)
                  IconButton(
                    isSelected: icon == e.key,
                    style: IconButton.styleFrom(backgroundColor: icon == e.key ? Color(color).withValues(alpha: 0.2) : null),
                    icon: Icon(e.value, color: Color(color)),
                    onPressed: () => setState(() => icon = e.key),
                  ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final col in categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => color = col),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(col),
                      child: color == col ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('تنبيه عند ٨٠٪ و١٠٠٪', 'Alert at 80% and 100%')),
                value: alerts,
                onChanged: (v) => setState(() => alerts = v),
              ),
            ]),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(c, false);
                  await app.deleteCategory(existing);
                },
                child: Text(context.t('حذف', 'Delete')),
              ),
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t('إلغاء', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty), child: Text(context.t('حفظ', 'Save'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final cat = existing ?? Category(name: '', sortOrder: app.categories.length);
    final l = parseAmount(limit.text);
    cat
      ..name = name.text.trim()
      ..monthlyLimit = l > 0 ? l : null
      ..icon = icon
      ..color = color
      ..alertsEnabled = alerts;
    await app.saveCategory(cat);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final limits = app.categories.fold(0.0, (s, c) => s + (c.monthlyLimit ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(context.t('الفئات', 'Categories'))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        ListTile(
          title: Text(context.t('مجموع الحدود', 'Total of limits')),
          subtitle: Text(context.t('ميزانية الصرف ${f.money(app.breakdown.spending)}', 'Spending budget ${f.money(app.breakdown.spending)}')),
          trailing: Text(f.money(limits),
              style: TextStyle(color: limits > app.breakdown.spending ? Theme.of(context).colorScheme.error : null, fontWeight: FontWeight.w600)),
        ),
        for (final c in app.categories)
          ListTile(
            leading: CategoryAvatar(c),
            title: Text(c.name),
            subtitle: Text(c.monthlyLimit == null ? context.t('بدون حد', 'No limit') : f.money(c.monthlyLimit!)),
            trailing: Icon(c.alertsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
            onTap: () => _edit(context, c),
          ),
      ]),
    );
  }
}

Future<void> addExtraIncomeDialog(BuildContext context) async {
  final app = context.app;
  final amount = TextEditingController();
  final source = TextEditingController();
  var allocation = 'same_ratios';
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(context.t('دخل إضافي', 'Extra income')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AmountField(controller: amount, autofocus: true, label: context.t('المبلغ', 'Amount'), suffix: app.fmt.currency),
            const SizedBox(height: 12),
            TextField(controller: source, decoration: InputDecoration(labelText: context.t('المصدر (بونص، عمل حر…)', 'Source (bonus, freelance…)'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            Text(context.t('كيف نوزعه؟', 'How should we split it?')),
            RadioGroup<String>(
              groupValue: allocation,
              onChanged: (v) => setState(() => allocation = v ?? allocation),
              child: Column(children: [
                RadioListTile(value: 'same_ratios', title: Text(context.t('بنفس نسب الخطة', 'Same ratios as my plan'))),
                RadioListTile(value: 'savings', title: Text(context.t('كله للادخار', 'All to savings'))),
                RadioListTile(value: 'spending', title: Text(context.t('كله للصرف', 'All to spending'))),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.t('حفظ', 'Save'))),
        ],
      ),
    ),
  );
  final v = parseAmount(amount.text);
  if (ok == true && v > 0) {
    await app.saveIncome(Income(amount: v, sourceName: source.text.trim().isEmpty ? null : source.text.trim(), allocation: allocation));
    if (context.mounted) toast(context, context.t('أُضيف للدورة الحالية', 'Added to the current cycle'));
  }
}
