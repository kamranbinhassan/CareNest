import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medicine_adherence_monitoring/core/network/api_client.dart';

void main() {
  test('physical-device default points to the configured Kali LAN server', () {
    final uri = Uri.parse(physicalDeviceApiBaseUrl);
    expect(uri.host, '10.27.120.70');
    expect(uri.port, 8000);
    expect(uri.path, '/api/v1');
  });

  test(
    'registration uses FastAPI POST JSON contract and parses token response',
    () async {
      late http.Request request;
      final transport = MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'expires_in': 1800,
            'user': {'id': 'user-1', 'email': 'demo@example.test'},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(client: transport, tokenReader: () async => null);

      final response =
          await api.post('/auth/register', {
                'email': 'demo@example.test',
                'password': 'valid-password-123',
              })
              as Map<String, dynamic>;

      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://10.27.120.70:8000/api/v1/auth/register',
      );
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {
        'email': 'demo@example.test',
        'password': 'valid-password-123',
      });
      expect(response['access_token'], 'test-token');
      expect(response['user']['id'], 'user-1');
      transport.close();
    },
  );

  test('timeout reports the configured host and port', () async {
    final transport = MockClient((_) async {
      throw TimeoutException('test timeout');
    });
    final api = ApiClient(client: transport, tokenReader: () async => null);

    await expectLater(
      api.post('/auth/register', {
        'email': 'demo@example.test',
        'password': 'valid-password-123',
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('10.27.120.70:8000'),
        ),
      ),
    );
    transport.close();
  });
}
