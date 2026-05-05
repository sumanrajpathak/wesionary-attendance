import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

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

    final months = provider.availableMonths();
    if (months.isEmpty) {
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

    final selected = _resolveSelected(months);
    final summary = provider.monthlySummary(selected.year, selected.month);

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: Column(
        children: [
          _MonthBar(
            months: months,
            selected: selected,
            recordedDays: summary.isEmpty ? 0 : summary.first.recordedDays,
            onChanged: (m) => setState(() => _selectedMonth = m),
          ),
          Expanded(
            child: summary.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No employees in this month.')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: summary.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = summary[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(_initials(s.employeeName))),
                        title: Text(
                          s.employeeName.isEmpty ? '(no name)' : s.employeeName,
                        ),
                        subtitle: Text('ID: ${s.employeeId}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${s.present} P',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${s.absent} A',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  DateTime _resolveSelected(List<DateTime> months) {
    final s = _selectedMonth;
    if (s != null && months.any((m) => m.year == s.year && m.month == s.month)) {
      return s;
    }
    return months.first;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _MonthBar extends StatelessWidget {
  final List<DateTime> months;
  final DateTime selected;
  final int recordedDays;
  final ValueChanged<DateTime> onChanged;

  const _MonthBar({
    required this.months,
    required this.selected,
    required this.recordedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DateTime>(
                  value: selected,
                  isExpanded: true,
                  items: months
                      .map(
                        (m) => DropdownMenuItem<DateTime>(
                          value: m,
                          child: Text(
                            DateFormat('MMMM yyyy').format(m),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
            Text(
              '$recordedDays day${recordedDays == 1 ? '' : 's'} recorded',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
