import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/user_session.dart';
import '../services/sheets_api_service.dart';

enum LoadState { idle, loading, ready, error }

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

  UserSession? _actor;
  List<Employee> _employees = [];
  List<AttendanceRecord> _history = [];
  final Set<String> _selected = {};
  DateTime _selectedDate = DateTime.now();

  LoadState _state = LoadState.idle;
  String? _error;
  bool _submitting = false;

  UserSession? get actor => _actor;
  List<Employee> get employees => List.unmodifiable(_employees);
  List<AttendanceRecord> get history => List.unmodifiable(_history);
  Set<String> get selectedIds => Set.unmodifiable(_selected);
  DateTime get selectedDate => _selectedDate;
  LoadState get state => _state;
  String? get error => _error;
  bool get submitting => _submitting;
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
      await _persistCache();
      _state = LoadState.ready;
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
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

  Future<int> submitAttendance() async {
    final admin = _actor;
    if (admin == null || !admin.isAdmin) {
      throw SheetsApiException('Admin login required to submit attendance.');
    }
    if (_submitting || _employees.isEmpty) return 0;
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
      _history.removeWhere(
        (r) =>
            r.date.year == date.year &&
            r.date.month == date.month &&
            r.date.day == date.day,
      );
      _history.insertAll(0, records.map((r) => r.copyWith(synced: true)));
      _history.sort((a, b) => b.date.compareTo(a.date));
      _selected.clear();
      await _persistCache();
      return count;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
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
}
