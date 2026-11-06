import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/features/account/account_deletion.dart';

import '../helpers/test_rig.dart';

void main() {
  late Directory docs;
  late Directory temp;
  late MemoryStorage storage;
  late int reminderCancels;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'@readin/user': '{"id":"u1"}', '@readin/onboarding_complete': true});
    storage = MemoryStorage(await SharedPreferences.getInstance());
    await storage.setAccessToken('access');
    await storage.setRefreshToken('refresh');
    docs = await Directory.systemTemp.createTemp('readin_docs_');
    temp = await Directory.systemTemp.createTemp('readin_tmp_');
    await File('${docs.path}/book.epub').writeAsString('book');
    await Directory('${docs.path}/books/covers').create(recursive: true);
    await File('${docs.path}/books/covers/c.jpg').writeAsString('img');
    await File('${temp.path}/quote.png').writeAsString('png');
    reminderCancels = 0;
  });

  tearDown(() async {
    for (final d in [docs, temp]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  Future<AccountDeletion> deletion(FakeAdapter adapter) async => AccountDeletion(
        api: await makeTestApi(adapter),
        storage: storage,
        localDirs: () async => [docs, temp],
        cancelReminders: () async => reminderCancels++,
      );

  test('asks the server with DELETE /users/me + password (and DELETE for password-less accounts)', () async {
    final adapter = FakeAdapter((_) => (status: 200, body: {'success': true, 'message': 'Your account was deleted.', 'data': null}));
    final d = await deletion(adapter);
    final r = await d.deleteOnServer('my-password');
    expect(r.exceptionOrNull, isNull);
    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.path, endsWith('/users/me'));
    expect(req.data, {'password': 'my-password', 'confirm': 'DELETE'});
  });

  test('wrong password → the server message is shown and NOTHING on the phone changes', () async {
    final adapter = FakeAdapter((_) => (status: 403, body: {'success': false, 'message': 'That password is not correct.'}));
    final d = await deletion(adapter);
    final r = await d.deleteOnServer('wrong');
    expect(r.exceptionOrNull?.message, 'That password is not correct.');
    expect(adapter.requests, hasLength(1), reason: 'a 403 must not trigger a sign-in refresh + retry');
    expect(await storage.accessToken, 'access');
    expect(await File('${docs.path}/book.epub').exists(), isTrue);
  });

  test('wipeThisPhone removes sign-in, settings, every file and the reminders', () async {
    final d = await deletion(FakeAdapter((_) => (status: 200, body: {})));
    // makeTestApi resets the mock settings — put some back so "cleared" proves something.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@readin/user', '{"id":"u1"}');
    await prefs.setBool('@readin/onboarding_complete', true);
    expect(prefs.getKeys(), isNotEmpty);
    await d.wipeThisPhone();
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
    expect(prefs.getKeys(), isEmpty);
    expect(docs.listSync(), isEmpty);
    expect(temp.listSync(), isEmpty);
    expect(reminderCancels, 1);
  });

  test('wipeThisPhone never throws, even when a folder is already gone', () async {
    await docs.delete(recursive: true);
    final d = await deletion(FakeAdapter((_) => (status: 200, body: {})));
    await d.wipeThisPhone();
    expect(await storage.accessToken, isNull);
    expect(temp.listSync(), isEmpty);
  });
}
