import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:handover/services/api.dart';

void main() {
  group('describeError', () {
    test('formats a list of field errors', () {
      final message = describeError(
        ApiException(
          jsonEncode({
            'detail': [
              {'msg': 'Value error, share_phone is required when accepting'},
              {'msg': 'Field required'},
            ],
          }),
          statusCode: 422,
        ),
      );

      expect(message, contains('share_phone is required when accepting'));
      expect(message, contains('Field required'));
      expect(message, isNot(contains('Value error, ')));
    });

    test('returns a plain string detail', () {
      final message = describeError(
        ApiException(
          jsonEncode({'detail': 'Email already registered'}),
          statusCode: 409,
        ),
      );

      expect(message, 'Email already registered');
    });

    test('returns the raw message when it is not JSON', () {
      final message = describeError(
        ApiException('connection reset', statusCode: 500),
      );

      expect(message, 'connection reset');
    });

    test('falls back to a server-unreachable hint for other errors', () {
      final message = describeError(StateError('boom'));

      expect(message, contains('Can\'t reach the server'));
      expect(message, contains(Api.baseUrl));
    });
  });
}
