import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// API URL can be set at build time with --dart-define=API_BASE_URL=...
/// This default is for the reported physical-phone/Kali development network.
/// Android emulators should override it with http://10.0.2.2:8000/api/v1.
const physicalDeviceApiBaseUrl = 'http://10.27.120.70:8000/api/v1';
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: physicalDeviceApiBaseUrl,
);

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    String? baseUrl,
    FlutterSecureStorage? storage,
    http.Client? client,
    Future<String?> Function()? tokenReader,
  }) : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
       _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _tokenReader = tokenReader;

  final String baseUrl;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<String?> Function()? _tokenReader;
  static const _tokenKey = 'backend_access_token';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<bool> get hasToken async =>
      (await _storage.read(key: _tokenKey)) != null;

  Future<dynamic> get(String endpoint) => _request('GET', endpoint);
  Future<dynamic> post(String endpoint, [Map<String, dynamic>? body]) =>
      _request('POST', endpoint, body: body);
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) =>
      _request('PUT', endpoint, body: body);
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) =>
      _request('PATCH', endpoint, body: body);
  Future<void> delete(String endpoint) async => _request('DELETE', endpoint);

  Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = _tokenReader == null
        ? await _storage.read(key: _tokenKey)
        : await _tokenReader();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$endpoint');
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw StateError('Unsupported HTTP method');
      }
    } on TimeoutException {
      throw ApiException(
        0,
        'Timed out connecting to ${uri.host}:${uri.port}. Check the configured server address and phone network.',
      );
    } on SocketException catch (error) {
      throw ApiException(
        0,
        'Could not connect to ${uri.host}:${uri.port}: ${error.message}',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        0,
        'Could not connect to ${uri.host}:${uri.port}: ${error.message}',
      );
    } on Exception catch (error) {
      throw ApiException(0, 'Could not reach the care server: $error');
    }
    if (response.statusCode == 401 &&
        endpoint != '/auth/login' &&
        endpoint != '/auth/register') {
      await clearToken();
      throw const ApiException(401, 'Your session expired. Sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Server request failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) {
          message = decoded['detail'].toString();
        }
      } catch (_) {}
      throw ApiException(response.statusCode, message);
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
