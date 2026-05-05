import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final history = provider.history;

    if (!provider.isConfigured) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No attendance recorded yet.')),
          ],
        ),
      );
    }

    final grouped = _groupByDate(history);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: dates.length,
        itemBuilder: (context, i) {
          final dateKey = dates[i];
          final entries = grouped[dateKey]!;
          return _DaySection(dateKey: dateKey, records: entries);
        },
      ),
    );
  }

  Map<String, List<AttendanceRecord>> _groupByDate(
    List<AttendanceRecord> records,
  ) {
    final map = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      map.putIfAbsent(r.dateKey, () => []).add(r);
    }
    return map;
  }
}

class _DaySection extends StatelessWidget {
  final String dateKey;
  final List<AttendanceRecord> records;
  const _DaySection({required this.dateKey, required this.records});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dateKey);
    final label = DateFormat('EEEE, MMM d, yyyy').format(date);
    final present =
        records.where((r) => r.status == AttendanceStatus.present).length;
    final absent = records.length - present;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('$present P • $absent A'),
            ],
          ),
        ),
        ...records.map((r) => ListTile(
              leading: Icon(
                r.status == AttendanceStatus.present
                    ? Icons.check_circle
                    : Icons.cancel,
                color: r.status == AttendanceStatus.present
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(r.employeeName),
              subtitle: Text(
                'ID ${r.employeeId}${r.time.isNotEmpty ? ' • ${r.time}' : ''}',
              ),
              trailing: r.synced
                  ? const Icon(Icons.cloud_done, color: Colors.green)
                  : const Icon(Icons.cloud_queue, color: Colors.grey),
            )),
      ],
    );
  }
}
