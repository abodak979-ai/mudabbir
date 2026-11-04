import 'package:flutter/material.dart';

import '../services/app_lock.dart';
import '../state/app_state.dart';
import 'add_expense.dart';
import 'expenses_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'reports_screen.dart';

/// Bottom navigation: Home · Expenses · (+) · Goals · Reports.
/// Also owns the app lock and hides content in the app switcher.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  int _reportsOffset = 0;
  bool _locked = false;
  bool _obscured = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.app.lockEnabled) {
        setState(() => _locked = true);
        _unlock();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = context.app;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        setState(() => _obscured = true);
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
        _backgroundedAt = null;
        setState(() {
          _obscured = false;
          if (app.lockEnabled && away > const Duration(seconds: 30)) _locked = true;
        });
        if (_locked) _unlock();
        app.syncNow();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    final ok = await AppLock.authenticate(context.t('افتح مُدبِّر', 'Unlock Mudabbir'));
    if (ok && mounted) setState(() => _locked = false);
  }

  void _openReports({bool previous = false}) => setState(() {
        _reportsOffset = previous ? 1 : 0;
        _tab = 3;
      });

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(openReports: _openReports),
      const ExpensesScreen(),
      const GoalsScreen(),
      ReportsScreen(initialOffset: _reportsOffset),
    ];
    return Stack(children: [
      Scaffold(
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab >= 2 ? _tab + 1 : _tab,
          onDestinationSelected: (i) {
            if (i == 2) {
              showAddExpense(context);
              return;
            }
            setState(() => _tab = i > 2 ? i - 1 : i);
          },
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.t('الرئيسية', 'Home')),
            NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: context.t('المصاريف', 'Expenses')),
            NavigationDestination(
              icon: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
              ),
              label: context.t('إضافة', 'Add'),
            ),
            NavigationDestination(icon: const Icon(Icons.flag_outlined), selectedIcon: const Icon(Icons.flag), label: context.t('الأهداف', 'Goals')),
            NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: context.t('التقارير', 'Reports')),
          ],
        ),
      ),
      if (_locked || _obscured)
        Positioned.fill(
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                if (_locked) FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: Text(context.t('فتح', 'Unlock'))),
              ]),
            ),
          ),
        ),
    ]);
  }
}
