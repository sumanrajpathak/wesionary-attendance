import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/user_role.dart';
import '../models/user_session.dart';

class SheetsApiException implements Exception {
  final String message;
  SheetsApiException(this.message);
  @override
  String toString() => 'SheetsApiException: $message';
}

class SheetsApiService {
  SheetsApiService()
    : _baseUrl = (dotenv.maybeGet('APPS_SCRIPT_URL') ?? '').trim();

  final String _baseUrl;

  String? get baseUrl => _baseUrl.isEmpty ? null : _baseUrl;
  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _uri([Map<String, String>? params]) {
    if (!isConfigured) {
      throw SheetsApiException(
        'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
      );
    }
    final base = Uri.parse(_baseUrl);
    final merged = {...base.queryParameters, ...?params};
    return base.replace(queryParameters: merged);
  }

  Future<List<Employee>> fetchEmployees() async {
    final res = await http.get(_uri({'action': 'getEmployees'}));
    final body = _decode(res);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => Employee.fromJson(Map<String, dynamic>.from(m)))
        .where(
          (e) =>
              e.role != UserRole.admin &&
              (e.id.isNotEmpty || e.name.isNotEmpty),
        )
        .toList();
  }

  Future<List<AttendanceRecord>> fetchAttendance({String? employeeId}) async {
    final params = {'action': 'getAttendance'};
    if (employeeId != null && employeeId.isNotEmpty) {
      params['employeeId'] = employeeId;
    }
    final res = await http.get(_uri(params));
    final body = _decode(res);
    final list = (body['data'] as List?) ?? const [];
    final records = <AttendanceRecord>[];
    for (final item in list.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final dateStr = (map['date'] ?? '').toString();
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }
      records.add(
        AttendanceRecord(
          employeeId: (map['employeeId'] ?? '').toString(),
          employeeName: (map['employeeName'] ?? '').toString(),
          date: date,
          status: AttendanceStatusX.parse(map['status'] as String?),
          time: (map['time'] ?? '').toString(),
          synced: true,
        ),
      );
    }
    return records;
  }

  Future<int> markAttendance(
    List<AttendanceRecord> records, {
    required String adminEmail,
  }) async {
    if (records.isEmpty) return 0;
    final res = await _postFollowingRedirects(
      _uri(),
      jsonEncode({
        'action': 'markAttendance',
        'adminEmail': adminEmail,
        'records': records.map((r) => r.toWire()).toList(),
      }),
    );
    if (res == null) return records.length;
    final body = _decode(res);
    return (body['count'] as num?)?.toInt() ?? records.length;
  }

  Future<UserSession> loginAdmin(String email, String password) async {
    final res = await _postFollowingRedirects(
      _uri(),
      jsonEncode({
        'action': 'login',
        'method': 'admin',
        'email': email.trim(),
        'password': password,
      }),
    );
    if (res == null) {
      throw SheetsApiException('Login response was dropped. Try again.');
    }
    final body = _decode(res);
    final user = body['user'];
    if (user is! Map) {
      throw SheetsApiException('Login response missing user.');
    }
    return UserSession.fromJson(Map<String, dynamic>.from(user));
  }

  Future<UserSession> loginGoogle(String email) async {
    final res = await _postFollowingRedirects(
      _uri(),
      jsonEncode({
        'action': 'login',
        'method': 'google',
        'email': email.trim(),
      }),
    );
    if (res == null) {
      throw SheetsApiException('Login response was dropped. Try again.');
    }
    final body = _decode(res);
    final user = body['user'];
    if (user is! Map) {
      throw SheetsApiException('Login response missing user.');
    }
    return UserSession.fromJson(Map<String, dynamic>.from(user));
  }

  // Apps Script web apps respond to POST with a 302 redirect to
  // script.googleusercontent.com. The http package doesn't follow cross-host
  // POST redirects, so we have to chase the Location header ourselves.
  // Returns null if the POST succeeded but the follow-up read was dropped —
  // by the time Apps Script issues the 302, doPost has already run, so the
  // server-side write is durable even when the body never arrives.
  Future<http.Response?> _postFollowingRedirects(Uri uri, String body) async {
    if (kIsWeb) {
      // Browsers follow redirects automatically and forbid setting User-Agent.
      // text/plain keeps this a CORS "simple request" (no preflight).
      final res = await http.post(
        uri,
        headers: const {'Content-Type': 'text/plain;charset=utf-8'},
        body: body,
      );
      return res;
    }
    final client = http.Client();
    try {
      final post = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..headers['User-Agent'] = _userAgent
        ..body = body;
      var streamed = await client.send(post);
      var hops = 0;
      var sawRedirect = false;
      while (_isRedirect(streamed.statusCode) && hops < 5) {
        sawRedirect = true;
        final location = streamed.headers['location'];
        if (location == null || location.isEmpty) break;
        final next = uri.resolve(location);
        final follow = http.Request('GET', next)
          ..followRedirects = false
          ..headers['User-Agent'] = _userAgent
          ..headers['Accept'] = 'application/json, text/plain, */*';
        try {
          streamed = await client.send(follow);
        } on http.ClientException {
          return null;
        } catch (_) {
          return null;
        }
        hops++;
      }
      try {
        return await http.Response.fromStream(streamed);
      } on http.ClientException {
        if (sawRedirect) return null;
        rethrow;
      }
    } finally {
      client.close();
    }
  }

  static const _userAgent = 'wesionary_attendance/1.0 (Flutter)';

  bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SheetsApiException('HTTP ${res.statusCode}: ${res.body}');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw SheetsApiException(
        'Unexpected response from Apps Script. Make sure the deployment is "Execute as: Me" and "Who has access: Anyone".',
      );
    }
    if (body['success'] != true) {
      throw SheetsApiException((body['error'] ?? 'Unknown error').toString());
    }
    return body;
  }
}
