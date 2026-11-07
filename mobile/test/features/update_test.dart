// S2 — "a new version is ready": version constants, server answer, throttling, banner, required-update gate.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/app/app_version.dart';
import 'package:readin_flutter/core/distribution.dart';
import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/features/auth/providers/auth_providers.dart';
import 'package:readin_flutter/features/update/update_provider.dart';
import 'package:readin_flutter/features/update/update_widgets.dart';

import '../helpers/test_rig.dart';

TestReply _ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

Map<String, Object?> _answer({bool available = true, bool mandatory = false}) => {
      'channel': 'direct',
      'updateAvailable': available,
      'mandatory': mandatory,
      'latestVersion': '9.9.9',
      'latestVersionCode': 999,
      'downloadUrl': 'https://github.com/bolajigr8/readin-releases/releases/download/v9.9.9/readin-9.9.9-universal.apk',
      'sizeBytes': 89652916,
      'releaseNotes': ['Premium reminders', ' ', 'Faster library'],
    };

void main() {
  test('app_version.dart matches pubspec.yaml (written together by tool/bump_version.dart)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true).firstMatch(pubspec)!;
    expect(kAppVersion, m.group(1));
    expect(kAppVersionCode, int.parse(m.group(2)!));
  });

  group('UpdateNotifier', () {
    late DateTime now;
    Future<(ProviderContainer, FakeAdapter)> make(TestReply Function() reply, {Distribution d = Distribution.direct}) async {
      final adapter = FakeAdapter((o) => reply());
      final api = await makeTestApi(adapter);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(StorageService(prefs: prefs)),
        apiClientProvider.overrideWithValue(api),
        distributionProvider.overrideWithValue(d),
        updateProvider.overrideWith((ref) => UpdateNotifier(ref, clock: () => now)),
      ]);
      addTearDown(c.dispose);
      adapter.requests.clear();
      return (c, adapter);
    }

    setUp(() => now = DateTime(2026, 11, 7, 10));

    test('optional update → banner; sends channel + this version code', () async {
      final (c, adapter) = await make(() => _ok(_answer()));
      await c.read(updateProvider.notifier).check();
      final s = c.read(updateProvider);
      expect(s.showBanner, isTrue);
      expect(s.mustUpdate, isFalse);
      expect(s.info!.sizeText, '85.5 MB');
      expect(s.info!.releaseNotes, ['Premium reminders', 'Faster library']);
      final q = adapter.requests.single.queryParameters;
      expect(adapter.requests.single.path, endsWith('/app/version'));
      expect(q['channel'], 'direct');
      expect(q['versionCode'], kAppVersionCode);
    });

    test('the Google Play version asks for the play channel', () async {
      final (c, adapter) = await make(() => _ok(_answer()), d: Distribution.play);
      await c.read(updateProvider.notifier).check();
      expect(adapter.requests.single.queryParameters['channel'], 'play');
    });

    test('required update → full screen, no banner', () async {
      final (c, _) = await make(() => _ok(_answer(mandatory: true)));
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider).mustUpdate, isTrue);
      expect(c.read(updateProvider).showBanner, isFalse);
    });

    test('server unreachable / error → nothing shown, never blocked', () async {
      final (c, _) = await make(() => (status: 503, body: {'success': false, 'message': 'asleep'}));
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider).info, isNull);
      expect(c.read(updateProvider).mustUpdate, isFalse);
    });

    test('asks at most every 6 hours (but always while an update is required)', () async {
      var mandatory = false;
      final (c, adapter) = await make(() => _ok(_answer(mandatory: mandatory)));
      final n = c.read(updateProvider.notifier);
      await n.check();
      now = now.add(const Duration(hours: 1));
      await n.check();
      expect(adapter.requests.length, 1, reason: 'second check within 6 h is skipped');
      now = now.add(const Duration(hours: 6));
      await n.check();
      expect(adapter.requests.length, 2);
      mandatory = true;
      await n.check(force: true);
      now = now.add(const Duration(minutes: 5));
      await n.check();
      expect(adapter.requests.length, 4, reason: 'required update is re-checked on every resume');
    });

    test('"Later" hides the banner for that version (remembered on the phone)', () async {
      final (c, _) = await make(() => _ok(_answer()));
      await c.read(updateProvider.notifier).check();
      c.read(updateProvider.notifier).later();
      expect(c.read(updateProvider).showBanner, isFalse);
      expect(c.read(storageServiceProvider).readString('@readin/update_dismissed_code'), '999');
    });

    test('no newer version → nothing', () async {
      final (c, _) = await make(() => _ok(_answer(available: false)));
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider).showBanner, isFalse);
      expect(c.read(updateProvider).mustUpdate, isFalse);
    });
  });

  group('UpdateGate', () {
    Future<void> pump(WidgetTester tester, {required String at, required bool mandatory}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(initialLocation: at, routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/reader/:id', builder: (_, _) => const Scaffold(body: Text('reading'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(StorageService(prefs: prefs)),
          updateProvider.overrideWith((ref) => _Fixed(ref, mandatory)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => UpdateGate(router: router, child: child!),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('required update covers the app', (tester) async {
      await pump(tester, at: '/', mandatory: true);
      expect(find.byKey(const ValueKey('update-required')), findsOneWidget);
      expect(find.text('Please update ReadIn'), findsOneWidget);
    });

    testWidgets('never while a book is open', (tester) async {
      await pump(tester, at: '/reader/b1', mandatory: true);
      expect(find.text('reading'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-required')), findsNothing);
    });

    testWidgets('optional update never covers the app', (tester) async {
      await pump(tester, at: '/', mandatory: false);
      expect(find.byKey(const ValueKey('update-required')), findsNothing);
    });
  });
}

/// A notifier with a fixed answer (no network).
class _Fixed extends UpdateNotifier {
  _Fixed(super.ref, bool mandatory) {
    state = UpdateState(info: UpdateInfo.fromJson(_answer(mandatory: mandatory)));
  }

  @override
  Future<void> check({bool force = false}) async {}
}
