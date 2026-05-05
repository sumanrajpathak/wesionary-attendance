import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/user_session.dart';
import '../services/sheets_api_service.dart';

enum LoadState { idle, loading, ready, error }

class SubmitResult {
  final int count;
  final bool queued;
  const SubmitResult({required this.count, required this.queued});
}

class _PendingBatch {
  final String id;
  final List<AttendanceRecord> records;
  final String adminEmail;
  final DateTime queuedAt;

  _PendingBatch({
    required this.id,
    required this.records,
    required this.adminEmail,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'adminEmail': adminEmail,
        'queuedAt': queuedAt.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory _PendingBatch.fromJson(Map<String, dynamic> json) => _PendingBatch(
        id: (json['id'] ?? '').toString(),
        adminEmail: (json['adminEmail'] ?? '').toString(),
        queuedAt: DateTime.tryParse(json['queuedAt']?.toString() ?? '') ??
            DateTime.now(),
        records: ((json['records'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => AttendanceRecord.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class EmployeeMonthSummary {
  final String employeeId;
  final String employeeName;
  final int present;
  final int absent;
  final int recordedDays;

  const EmployeeMonthSummary({
    required this.employeeId,
    required this.employeeName,
    required this.present,
    required this.absent,
    required this.recordedDays,
  });
}

class _MutableSummary {
  final String id;
  final String name;
  int present = 0;
  int absent = 0;
  _MutableSummary(this.id, this.name);
}

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({SheetsApiService? service})
      : _service = service ?? SheetsApiService();

  final SheetsApiService _service;

  static const _kEmployees = 'cache_employees_v2';
  static const _kHistory = 'cache_history_v2';
  static const _kPending = 'pending_batches_v1';

  UserSession? _actor;
  List<Employee> _employees = [];
  List<AttendanceRecord> _history = [];
  final Set<String> _selected = {};
  DateTime _selectedDate = DateTime.now();
  final List<_PendingBatch> _pending = [];

  LoadState _state = LoadState.idle;
  String? _error;
  bool _submitting = false;
  bool _syncing = false;

  UserSession? get actor => _actor;
  List<Employee> get employees => List.unmodifiable(_employees);
  List<AttendanceRecord> get history => List.unmodifiable(_history);
  Set<String> get selectedIds => Set.unmodifiable(_selected);
  DateTime get selectedDate => _selectedDate;
  LoadState get state => _state;
  String? get error => _error;
  bool get submitting => _submitting;
  bool get syncing => _syncing;
  int get pendingCount => _pending.length;
  bool get hasPending => _pending.isNotEmpty;
  bool get isConfigured => _service.isConfigured;
  String? get endpointUrl => _service.baseUrl;
  SheetsApiService get service => _service;

  Future<void> setActor(UserSession? user) async {
    if (_actor?.email == user?.email && _actor?.role == user?.role) return;
    _actor = user;
    _selected.clear();
    if (user == null) {
      _employees = [];
      _history = [];
      _state = LoadState.idle;
      _error = null;
      notifyListeners();
      return;
    }
    await _restoreCache();
    await _restorePending();
    if (_service.isConfigured) {
      await refresh();
    } else {
      _state = LoadState.error;
      _error = 'APPS_SCRIPT_URL is missing from .env.';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final actor = _actor;
    if (actor == null || !_service.isConfigured) return;
    _state = LoadState.loading;
    _error = null;
    notifyListeners();
    try {
      if (actor.isAdmin) {
        final results = await Future.wait([
          _service.fetchEmployees(),
          _service.fetchAttendance(),
        ]);
        _employees = results[0] as List<Employee>;
        _history = results[1] as List<AttendanceRecord>;
      } else {
        _employees = const [];
        _history = await _service.fetchAttendance(employeeId: actor.id);
      }
      _history.sort((a, b) => b.date.compareTo(a.date));
      _selected.removeWhere(
        (id) => !_employees.any((e) => e.id == id),
      );
      _reapplyPendingToHistory();
      await _persistCache();
      _state = LoadState.ready;
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
    if (_pending.isNotEmpty && actor.isAdmin) {
      unawaited(retryPendingSync());
    }
  }

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selected
      ..clear()
      ..addAll(_employees.map((e) => e.id));
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  Future<SubmitResult> submitAttendance() async {
    final admin = _actor;
    if (admin == null || !admin.isAdmin) {
      throw SheetsApiException('Admin login required to submit attendance.');
    }
    if (_submitting || _employees.isEmpty) {
      return const SubmitResult(count: 0, queued: false);
    }
    _submitting = true;
    _error = null;
    notifyListeners();

    final now = DateTime.now();
    final time = DateFormat('HH:mm').format(now);
    final date = _selectedDate;

    final records = _employees
        .map(
          (e) => AttendanceRecord(
            employeeId: e.id,
            employeeName: e.name,
            date: date,
            status: _selected.contains(e.id)
                ? AttendanceStatus.present
                : AttendanceStatus.absent,
            time: time,
          ),
        )
        .toList();

    try {
      final count =
          await _service.markAttendance(records, adminEmail: admin.email);
      _replaceDayInHistory(date, records.map((r) => r.copyWith(synced: true)));
      _selected.clear();
      await _persistCache();
      return SubmitResult(count: count, queued: false);
    } catch (e) {
      if (_isTransient(e)) {
        // Save locally and queue for retry — admin's data isn't lost.
        _replaceDayInHistory(date, records);
        await _enqueue(_PendingBatch(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          records: records,
          adminEmail: admin.email,
          queuedAt: DateTime.now(),
        ));
        _selected.clear();
        await _persistCache();
        return SubmitResult(count: records.length, queued: true);
      }
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<int> retryPendingSync() async {
    if (_syncing || _pending.isEmpty) return 0;
    final admin = _actor;
    if (admin == null || !admin.isAdmin) return 0;
    _syncing = true;
    notifyListeners();
    var sent = 0;
    final remaining = <_PendingBatch>[];
    for (final batch in _pending) {
      try {
        await _service.markAttendance(batch.records,
            adminEmail: batch.adminEmail);
        _replaceDayFromBatch(batch);
        sent += batch.records.length;
      } catch (e) {
        if (_isTransient(e)) {
          remaining.add(batch);
        } else {
          // Permanent failure — drop the batch so it doesn't loop forever.
          // The locally-applied records stay visible but unsynced.
          continue;
        }
      }
    }
    _pending
      ..clear()
      ..addAll(remaining);
    await _persistPending();
    await _persistCache();
    _syncing = false;
    notifyListeners();
    return sent;
  }

  bool _isTransient(Object error) {
    if (error is http.ClientException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('handshake') ||
        msg.contains('http 5'); // 5xx server errors
  }

  void _replaceDayInHistory(
    DateTime date,
    Iterable<AttendanceRecord> newRecords,
  ) {
    _history.removeWhere(
      (r) =>
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
    );
    _history.insertAll(0, newRecords);
    _history.sort((a, b) => b.date.compareTo(a.date));
  }

  void _replaceDayFromBatch(_PendingBatch batch) {
    if (batch.records.isEmpty) return;
    final date = batch.records.first.date;
    _replaceDayInHistory(
      date,
      batch.records.map((r) => r.copyWith(synced: true)),
    );
  }

  void _reapplyPendingToHistory() {
    for (final batch in _pending) {
      if (batch.records.isEmpty) continue;
      final date = batch.records.first.date;
      _replaceDayInHistory(date, batch.records);
    }
  }

  Future<void> _enqueue(_PendingBatch batch) async {
    // Keep only the latest batch per day to avoid unbounded growth.
    final date = batch.records.isEmpty ? null : batch.records.first.date;
    if (date != null) {
      _pending.removeWhere((b) =>
          b.records.isNotEmpty &&
          b.records.first.date.year == date.year &&
          b.records.first.date.month == date.month &&
          b.records.first.date.day == date.day);
    }
    _pending.add(batch);
    await _persistPending();
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmployees);
    await prefs.remove(_kHistory);
    _employees = [];
    _history = [];
    notifyListeners();
  }

  List<DateTime> availableMonths() {
    final seen = <String>{};
    final months = <DateTime>[];
    for (final r in _history) {
      final key = '${r.date.year}-${r.date.month}';
      if (seen.add(key)) months.add(DateTime(r.date.year, r.date.month));
    }
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month}';
    if (seen.add(currentKey)) {
      months.add(DateTime(now.year, now.month));
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  List<EmployeeMonthSummary> monthlySummary(int year, int month) {
    final byEmp = <String, _MutableSummary>{};
    final daysWithData = <int>{};
    for (final r in _history) {
      if (r.date.year != year || r.date.month != month) continue;
      daysWithData.add(r.date.day);
      final s = byEmp.putIfAbsent(
        r.employeeId,
        () => _MutableSummary(r.employeeId, r.employeeName),
      );
      if (r.status == AttendanceStatus.present) {
        s.present++;
      } else {
        s.absent++;
      }
    }
    for (final e in _employees) {
      byEmp.putIfAbsent(e.id, () => _MutableSummary(e.id, e.name));
    }
    final out = byEmp.values
        .map(
          (m) => EmployeeMonthSummary(
            employeeId: m.id,
            employeeName: m.name,
            present: m.present,
            absent: m.absent,
            recordedDays: daysWithData.length,
          ),
        )
        .toList()
      ..sort((a, b) => a.employeeName
          .toLowerCase()
          .compareTo(b.employeeName.toLowerCase()));
    return out;
  }

  EmployeeMonthSummary? mySummary(int year, int month) {
    final actor = _actor;
    if (actor == null || actor.isAdmin) return null;
    final daysWithData = <int>{};
    int present = 0;
    int absent = 0;
    for (final r in _history) {
      if (r.date.year != year || r.date.month != month) continue;
      if (r.employeeId != actor.id) continue;
      daysWithData.add(r.date.day);
      if (r.status == AttendanceStatus.present) {
        present++;
      } else {
        absent++;
      }
    }
    return EmployeeMonthSummary(
      employeeId: actor.id,
      employeeName: actor.name,
      present: present,
      absent: absent,
      recordedDays: daysWithData.length,
    );
  }

  int countOn(DateTime day) {
    return _history.where((r) {
      return r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day &&
          r.status == AttendanceStatus.present;
    }).length;
  }

  bool isMarkedToday(String employeeId) {
    final today = DateTime.now();
    return _history.any(
      (r) =>
          r.employeeId == employeeId &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
    );
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kEmployees,
      jsonEncode(_employees.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _kHistory,
      jsonEncode(_history.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    final empJson = prefs.getString(_kEmployees);
    if (empJson != null) {
      try {
        final list = jsonDecode(empJson) as List;
        _employees = list
            .whereType<Map>()
            .map((m) => Employee.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        _employees = [];
      }
    }
    final histJson = prefs.getString(_kHistory);
    if (histJson != null) {
      try {
        final list = jsonDecode(histJson) as List;
        _history = list
            .whereType<Map>()
            .map((m) => AttendanceRecord.fromJson(Map<String, dynamic>.from(m)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {
        _history = [];
      }
    }
  }

  Future<void> _persistPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPending,
      jsonEncode(_pending.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> _restorePending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPending);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _pending
        ..clear()
        ..addAll(
          list.whereType<Map>().map(
                (m) => _PendingBatch.fromJson(Map<String, dynamic>.from(m)),
              ),
        );
    } catch (_) {
      _pending.clear();
    }
  }
}
