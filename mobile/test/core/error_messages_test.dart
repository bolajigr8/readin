import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_rig.dart';

/// What the user reads when the server answers with an error status.
void main() {
  Future<String?> messageFor(int status, Object body) async {
    final api = await makeTestApi(FakeAdapter((_) => (status: status, body: body)));
    final r = await api.post<Object?>('/payments/checkout', data: {'planId': 'monthly'});
    return r.exceptionOrNull?.message;
  }

  test('502 with a message from our server → that message (e.g. payments blocked)', () async {
    expect(
      await messageFor(502, {
        'success': false,
        'message': 'Payments are temporarily unavailable. Please try again later.',
      }),
      'Payments are temporarily unavailable. Please try again later.',
    );
  });

  test('503 with a message → that message', () async {
    expect(
      await messageFor(503, {'success': false, 'message': 'Payments are not set up yet. Please try again later.'}),
      'Payments are not set up yet. Please try again later.',
    );
  });

  test('502 without a message (e.g. a gateway page) → generic text', () async {
    expect(await messageFor(502, '<html>Bad gateway</html>'), 'Server error. Please try again later.');
  });

  test('500 never shows the server text (could be an internal error)', () async {
    expect(
      await messageFor(500, {'success': false, 'message': 'TypeError: x is undefined'}),
      'Server error. Please try again later.',
    );
  });
}
