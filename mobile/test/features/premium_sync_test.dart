import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/sync/doc_syncer.dart';
import 'package:readin_flutter/features/features/feature_models.dart';
import 'package:readin_flutter/features/habits/habit_models.dart';
import 'package:readin_flutter/features/shelves/shelf_models.dart';

import '../helpers/test_rig.dart';

void main() {
  group('FeatureAccess', () {
    final now = DateTime(2026, 10, 20, 12);

    test('parses the server answer', () {
      final a = FeatureAccess.fromJson({
        'state': 'trial',
        'reason': 'free trial',
        'trialEndsAt': now.add(const Duration(days: 5, hours: 3)).toIso8601String(),
      });
      expect(a.state, AccessState.trial);
      expect(a.allowed, isTrue);
      expect(a.daysLeft(now), 6);
      expect(FeatureAccess.fromJson({'state': 'trial_available'}).canStartTrial, isTrue);
      expect(FeatureAccess.fromJson({'state': 'wat'}).state, AccessState.unknown);
    });

    test('who is allowed in', () {
      for (final s in ['full', 'trial']) {
        expect(FeatureAccess.fromJson({'state': s}).allowed, isTrue, reason: s);
      }
      for (final s in ['trial_available', 'expired', 'locked', 'disabled']) {
        expect(FeatureAccess.fromJson({'state': s}).allowed, isFalse, reason: s);
      }
      // server asleep / no answer yet → never lock people out
      expect(const FeatureAccess().allowed, isTrue);
    });

    test('a cached trial expires on its own, even offline', () {
      final a = FeatureAccess(state: AccessState.trial, trialEndsAt: now.add(const Duration(hours: 1)));
      expect(a.evaluate(now).state, AccessState.trial);
      expect(a.evaluate(now.add(const Duration(hours: 2))).state, AccessState.expired);
      expect(a.evaluate(now.add(const Duration(hours: 2))).allowed, isFalse);
    });

    test('cache round trip', () {
      final s = FeaturesState(features: {
        'habits': FeatureAccess(state: AccessState.trial, trialEndsAt: DateTime(2030, 1, 1)),
      }, loaded: true);
      final back = FeaturesState.decode(s.encode());
      expect(back.loaded, isTrue);
      expect(back.features['habits']!.state, AccessState.trial);
      expect(FeaturesState.decode('garbage').loaded, isFalse);
      expect(FeaturesState.decode(null).features, isEmpty);
    });
  });

  group('merge (never loses data)', () {
    test('habits: union, bigger amount, local mark wins', () {
      final h1 = Habit(id: 'a', name: 'Local', goal: 10, createdAt: DateTime(2026, 10, 1));
      final h2 = Habit(id: 'b', name: 'FromPhone2', goal: 5, createdAt: DateTime(2026, 10, 1));
      final local = HabitData(habits: [h1], log: {
        'a': {'2026-10-05': const DayLog(amount: 4, mark: DayMark.done)},
      });
      final server = HabitData(habits: [h1, h2], log: {
        'a': {
          '2026-10-05': const DayLog(amount: 9, mark: DayMark.failed),
          '2026-10-06': const DayLog(amount: 3),
        },
        'b': {'2026-10-05': const DayLog(amount: 5)},
      });
      final m = mergeHabitData(local, server);
      expect(m.habits.map((h) => h.id), ['a', 'b']);
      expect(m.log['a']!['2026-10-05']!.amount, 9);
      expect(m.log['a']!['2026-10-05']!.mark, DayMark.done);
      expect(m.log['a']!['2026-10-06']!.amount, 3);
      expect(m.log['b']!['2026-10-05']!.amount, 5);
    });

    test('shelves: union of statuses, favourites and shelf members', () {
      const local = ShelfData(
        status: {'1': ReadStatus.want},
        favorites: {'1'},
        shelves: [Shelf(id: 's', name: 'Sci-fi', bookIds: {'1'})],
        yearlyGoal: 30,
      );
      const server = ShelfData(
        status: {'1': ReadStatus.finished, '2': ReadStatus.reading},
        favorites: {'2'},
        shelves: [Shelf(id: 's', name: 'Sci-fi', bookIds: {'2'}), Shelf(id: 't', name: 'Other', bookIds: {})],
        yearlyGoal: 12,
      );
      final m = mergeShelfData(local, server);
      expect(m.status['1'], ReadStatus.want); // local wins a clash
      expect(m.status['2'], ReadStatus.reading);
      expect(m.favorites, {'1', '2'});
      expect(m.shelves.firstWhere((s) => s.id == 's').bookIds, {'1', '2'});
      expect(m.shelves.length, 2);
      expect(m.yearlyGoal, 30);
    });
  });

  group('DocSyncer', () {
    late FakeAdapter adapter;

    Future<({DocSyncer sync, List<String> applied, String Function() local})> make({
      required TestReply Function(RequestOptions) handler,
      required String initial,
      bool enabled = true,
    }) async {
      adapter = FakeAdapter(handler);
      final api = await makeTestApi(adapter);
      final prefs = await SharedPreferences.getInstance();
      var local = initial;
      final applied = <String>[];
      final sync = DocSyncer(
        api: api,
        storage: MemoryStorage(prefs),
        key: 'habits',
        readLocal: () => local,
        isLocalEmpty: () => local == '{}',
        applyRemote: (j) {
          local = j;
          applied.add(j);
        },
        merge: (a, b) {
          final ma = jsonDecode(a) as Map<String, dynamic>;
          final mb = jsonDecode(b) as Map<String, dynamic>;
          return jsonEncode({...mb, ...ma});
        },
        enabled: () => enabled,
        debounce: const Duration(milliseconds: 10),
      );
      return (sync: sync, applied: applied, local: () => local);
    }

    TestReply ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

    test('first time on the account: uploads what the phone has (version 0)', () async {
      final r = await make(
        initial: '{"a":1}',
        handler: (o) => o.method == 'GET' ? ok({'data': null, 'version': 0}) : ok({'version': 1}),
      );
      await r.sync.pull();
      final put = adapter.requests.firstWhere((x) => x.method == 'PUT');
      expect((put.data as Map)['baseVersion'], 0);
      expect(jsonDecode((put.data as Map)['data'] as String), {'a': 1});
      expect(r.sync.version, 1);
    });

    test('empty phone adopts the server copy; nothing is uploaded', () async {
      final r = await make(
        initial: '{}',
        handler: (o) => ok({'data': '{"x":2}', 'version': 7}),
      );
      await r.sync.pull();
      expect(r.local(), '{"x":2}');
      expect(adapter.requests.where((x) => x.method == 'PUT'), isEmpty);
      expect(r.sync.version, 7);
    });

    test('both have data: merged, applied locally and uploaded with the server version', () async {
      final r = await make(
        initial: '{"a":1}',
        handler: (o) => o.method == 'GET' ? ok({'data': '{"b":2}', 'version': 3}) : ok({'version': 4}),
      );
      await r.sync.pull();
      expect(jsonDecode(r.local()), {'a': 1, 'b': 2});
      final put = adapter.requests.firstWhere((x) => x.method == 'PUT');
      expect((put.data as Map)['baseVersion'], 3);
      expect(r.sync.version, 4);
    });

    test('409 conflict: fetch, merge, retry — no data lost', () async {
      var puts = 0;
      final r = await make(
        initial: '{"a":1}',
        handler: (o) {
          if (o.method == 'PUT') {
            puts++;
            if (puts == 1) return (status: 409, body: {'success': false, 'message': 'Out of date'});
            return ok({'version': 9});
          }
          return ok({'data': '{"b":2}', 'version': 8});
        },
      );
      r.sync.markChanged();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(puts, 2);
      expect(jsonDecode(r.local()), {'a': 1, 'b': 2});
      expect(r.sync.version, 9);
    });

    test('an edit made offline is uploaded first — a deletion is not resurrected', () async {
      var puts = 0;
      Object? lastPut;
      final r = await make(
        initial: '{"a":1}', // the user deleted "gone" while offline
        handler: (o) {
          if (o.method == 'PUT') {
            puts++;
            lastPut = o.data;
            if (puts == 1) return (status: 503, body: {'success': false, 'message': 'asleep'});
            return (puts == 2 && (o.data as Map)['baseVersion'] == 5)
                ? ok({'version': 6})
                : (status: 409, body: {'success': false, 'message': 'conflict'});
          }
          return ok({'data': '{"a":1,"gone":2}', 'version': 5});
        },
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('@readin/sync_v_habits', 5);

      r.sync.markChanged(); // push fails (server asleep) → stays dirty
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(r.sync.dirty, isTrue);

      await r.sync.pull(); // back online: uploads FIRST, no merge with the old server copy
      expect(r.local(), '{"a":1}');
      expect(r.applied, isEmpty);
      expect(jsonDecode((lastPut as Map)['data'] as String), {'a': 1});
      expect(r.sync.dirty, isFalse);
      expect(r.sync.version, 6);
    });

    test('offline / locked / disabled: the local copy is never touched', () async {
      final locked = await make(
        initial: '{"a":1}',
        handler: (o) => (status: 403, body: {'success': false, 'message': 'locked'}),
      );
      await locked.sync.pull();
      await locked.sync.push();
      expect(locked.local(), '{"a":1}');
      expect(locked.applied, isEmpty);

      final off = await make(initial: '{"a":1}', enabled: false, handler: (o) => ok({}));
      await off.sync.pull();
      off.sync.markChanged();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(adapter.requests, isEmpty);
    });
  });
}
