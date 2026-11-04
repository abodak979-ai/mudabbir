import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Quick entry: type amount → tap category → save (3 taps). Works offline.
Future<void> showAddExpense(BuildContext context, {Expense? existing}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddExpenseSheet(existing: existing),
    );

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, this.existing});
  final Expense? existing;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late String _amount = widget.existing == null ? '' : amountText(widget.existing!.amount);
  String? _categoryId;
  late DateTime _date = widget.existing?.spentAt ?? DateTime.now();
  late final _note = TextEditingController(text: widget.existing?.note);
  late String? _receipt = widget.existing?.receiptLocal;
  bool _showNote = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.app;
    _categoryId ??= widget.existing?.categoryId ??
        (app.expenses.isNotEmpty ? app.expenses.first.categoryId : (app.categories.isEmpty ? null : app.categories.first.id));
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '⌫') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount = _amount.isEmpty ? '0.' : '$_amount.';
      } else if (_amount.length < 9) {
        final dot = _amount.indexOf('.');
        if (dot < 0 || _amount.length - dot <= 2) _amount = _amount == '0' ? k : '$_amount$k';
      }
    });
  }

  double get _value => double.tryParse(_amount) ?? 0;

  Future<void> _pickReceipt() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1600);
    if (img == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'receipts', '${DateTime.now().millisecondsSinceEpoch}.jpg');
    await Directory(p.dirname(dest)).create(recursive: true);
    await img.saveTo(dest);
    setState(() => _receipt = dest);
  }

  Future<void> _save() async {
    if (_value <= 0) return;
    final app = context.app;
    final e = widget.existing ?? Expense(amount: 0);
    final prevPath = e.receiptLocal;
    e
      ..amount = _value
      ..categoryId = _categoryId
      ..spentAt = _date
      ..note = _note.text.trim().isEmpty ? null : _note.text.trim()
      ..receiptLocal = _receipt;
    if (_receipt != prevPath) e.receiptPath = null; // new photo → re-upload
    Navigator.pop(context);
    await app.saveExpense(e, previous: widget.existing);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final f = app.fmt;
    final theme = Theme.of(context);
    final today = DateUtils.isSameDay(_date, DateTime.now());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${f.n(_value, decimals: _amount.contains('.') ? 2 : 0)} ${f.currency}',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (!app.hideAmounts)
            Text(
              context.t('متبقي اليوم بعده: ${f.money(app.remainingToday - (widget.existing == null ? _value : 0))}',
                  'Left today after this: ${f.money(app.remainingToday - (widget.existing == null ? _value : 0))}'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in app.categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _categoryId = c.id),
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _categoryId == c.id ? Color(c.color) : Colors.transparent, width: 2),
                        ),
                        child: Column(children: [
                          CategoryAvatar(c, size: 36),
                          const SizedBox(height: 4),
                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(today ? context.t('اليوم', 'Today') : f.date(_date)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDate: _date,
                  );
                  if (d != null) setState(() => _date = DateUtils.isSameDay(d, DateTime.now()) ? DateTime.now() : DateTime(d.year, d.month, d.day, 12));
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.notes, size: 18),
                label: Text(context.t('ملاحظة', 'Note')),
                onPressed: () => setState(() => _showNote = !_showNote),
              ),
              ActionChip(
                avatar: Icon(_receipt == null ? Icons.photo_camera_outlined : Icons.check_circle, size: 18),
                label: Text(context.t('صورة الإيصال', 'Receipt')),
                onPressed: _pickReceipt,
              ),
            ]),
          ),
          if (_showNote || (_note.text.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(controller: _note, decoration: InputDecoration(hintText: context.t('ملاحظة اختيارية', 'Optional note'), isDense: true)),
            ),
          const SizedBox(height: 8),
          _Keypad(onKey: _key, digits: (d) => f.n(int.parse(d))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _value > 0 ? _save : null,
              child: Text(context.t('حفظ', 'Save'), style: const TextStyle(fontSize: 18)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.digits});
  final ValueChanged<String> onKey;
  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final k in keys)
            TextButton(
              onPressed: () => onKey(k),
              child: k == '⌫'
                  ? Icon(Icons.backspace_outlined, semanticLabel: context.t('حذف', 'Delete'))
                  : Text(k == '.' ? '.' : digits(k), style: Theme.of(context).textTheme.headlineSmall),
            ),
        ],
      ),
    );
  }
}
