import 'package:intl/intl.dart';

enum AttendanceStatus { present, absent }

extension AttendanceStatusX on AttendanceStatus {
  String get wire => name;

  static AttendanceStatus parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return s == 'absent' ? AttendanceStatus.absent : AttendanceStatus.present;
  }
}

class AttendanceRecord {
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final AttendanceStatus status;
  final String time;
  final bool synced;

  const AttendanceRecord({
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.status,
    required this.time,
    this.synced = false,
  });

  AttendanceRecord copyWith({bool? synced}) => AttendanceRecord(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        status: status,
        time: time,
        synced: synced ?? this.synced,
      );

  String get dateKey => DateFormat('yyyy-MM-dd').format(date);

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': date.toIso8601String(),
        'status': status.wire,
        'time': time,
        'synced': synced,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      date: DateTime.parse(json['date'] as String),
      status: AttendanceStatusX.parse(json['status'] as String?),
      time: (json['time'] ?? '').toString(),
      synced: json['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toWire() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': dateKey,
        'status': status.wire,
        'time': time,
      };
}
