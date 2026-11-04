import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_db.dart';

/// Two-way sync: push locally-dirty rows (upsert), then pull rows changed on the server
/// since the last pull. A row edited locally and not yet pushed is never overwritten.
class SyncService {
  SyncService(this.db, this.sb);
  final LocalDb db;
  final SupabaseClient sb;

  // Order matters: categories before expenses (foreign key).
  static const tables = [
    'budget_plans',
    'categories',
    'fixed_obligations',
    'incomes',
    'expenses',
    'savings_goals',
  ];

  // Columns that exist only on the device.
  static const _localOnly = {'receipt_local'};

  bool _running = false;

  Future<bool> run() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pushProfile(uid);
      await _pullProfile(uid);
      for (final t in tables) {
        await _push(t, uid);
      }
      for (final t in tables) {
        await _pull(t, uid);
      }
      return true;
    } catch (e, st) {
      debugPrint('sync failed: $e\n$st');
      return false;
    } finally {
      _running = false;
    }
  }

  Future<void> _pushProfile(String uid) async {
    for (final row in await db.dirty('profiles')) {
      final saved = await sb.from('profiles').upsert({...row, 'id': uid}).select().single();
      await db.put('profiles', saved, dirty: false);
    }
  }

  Future<void> _pullProfile(String uid) async {
    final row = await sb.from('profiles').select().eq('id', uid).maybeSingle();
    if (row != null && !await db.isDirty('profiles', uid)) {
      await db.put('profiles', row, dirty: false);
    }
  }

  Future<void> _push(String t, String uid) async {
    final rows = await db.dirty(t);
    if (rows.isEmpty) return;
    if (t == 'expenses') {
      for (final r in rows) {
        await _uploadReceipt(r, uid);
      }
    }
    final payload = [
      for (final r in rows)
        {
          for (final e in r.entries)
            if (!_localOnly.contains(e.key) && e.key != 'updated_at') e.key: e.value,
          'user_id': uid,
        },
    ];
    final saved = await sb.from(t).upsert(payload).select();
    final local = {for (final r in rows) r['id']: r};
    for (final s in saved) {
      final keep = {
        for (final k in _localOnly)
          if (local[s['id']]?[k] != null) k: local[s['id']]![k],
      };
      await db.put(t, {...s, ...keep}, dirty: false);
    }
  }

  Future<void> _uploadReceipt(Map<String, dynamic> r, String uid) async {
    final localPath = r['receipt_local'] as String?;
    if (localPath == null || r['receipt_path'] != null) return;
    final file = File(localPath);
    if (!file.existsSync()) return;
    final path = '$uid/${r['id']}.jpg';
    await sb.storage.from('receipts').upload(path, file, fileOptions: const FileOptions(upsert: true));
    r['receipt_path'] = path;
  }

  Future<void> _pull(String t, String uid) async {
    final key = 'pull:$t';
    final since = await db.meta(key);
    var q = sb.from(t).select().eq('user_id', uid);
    if (since != null) q = q.gte('updated_at', since);
    final rows = await q.order('updated_at').limit(1000);
    if (rows.isEmpty) return;
    final existing = {for (final r in await db.all(t)) r['id']: r};
    for (final r in rows) {
      if (await db.isDirty(t, r['id'])) continue;
      final keep = {
        for (final k in _localOnly)
          if (existing[r['id']]?[k] != null) k: existing[r['id']]![k],
      };
      await db.put(t, {...r, ...keep}, dirty: false);
    }
    await db.setMeta(key, rows.last['updated_at'] as String);
    // More than one page changed: continue from the last timestamp.
    if (rows.length == 1000) await _pull(t, uid);
  }
}
