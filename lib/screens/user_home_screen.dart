import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<AttendanceProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: provider.state == LoadState.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.state == LoadState.loading
                ? null
                : () => provider.refresh(),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (user == null) return const SizedBox.shrink();

          if (provider.state == LoadState.loading && provider.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.state == LoadState.error && provider.history.isEmpty) {
            return _ErrorState(message: provider.error ?? 'Failed to load');
          }

          final months = provider.availableMonths();
          final selected = _resolveSelected(months);
          final summary = provider.mySummary(selected.year, selected.month);
          final dayList = provider.history
              .where(
                (r) =>
                    r.employeeId == user.id &&
                    r.date.year == selected.year &&
                    r.date.month == selected.month,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _ProfileHeader(name: user.name, email: user.email),
                _MonthBar(
                  months: months,
                  selected: selected,
                  onChanged: (m) => setState(() => _selectedMonth = m),
                ),
                _SummaryCard(summary: summary),
                if (dayList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No attendance recorded for this month yet.'),
                    ),
                  )
                else
                  ..._buildDayTiles(dayList),
              ],
            ),
          );
        },
      ),
    );
  }

  DateTime _resolveSelected(List<DateTime> months) {
    if (months.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }
    final s = _selectedMonth;
    if (s != null && months.any((m) => m.year == s.year && m.month == s.month)) {
      return s;
    }
    return months.first;
  }

  List<Widget> _buildDayTiles(List<AttendanceRecord> records) {
    return records.map((r) {
      final isPresent = r.status == AttendanceStatus.present;
      return ListTile(
        leading: Icon(
          isPresent ? Icons.check_circle : Icons.cancel,
          color: isPresent ? Colors.green : Colors.red,
        ),
        title: Text(DateFormat('EEEE, MMM d, yyyy').format(r.date)),
        trailing: Text(
          isPresent ? 'Present' : 'Absent',
          style: TextStyle(
            color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await context.read<AttendanceProvider>().clearLocalCache();
    if (!context.mounted) return;
    await context.read<AuthProvider>().logout();
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  const _ProfileHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(_initials(name), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '(no name)' : name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  email,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  final ValueChanged<DateTime> onChanged;

  const _MonthBar({
    required this.months,
    required this.selected,
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
                  value: months.any(
                          (m) => m.year == selected.year && m.month == selected.month)
                      ? selected
                      : null,
                  isExpanded: true,
                  hint: Text(DateFormat('MMMM yyyy').format(selected)),
                  items: months
                      .map(
                        (m) => DropdownMenuItem<DateTime>(
                          value: m,
                          child: Text(
                            DateFormat('MMMM yyyy').format(m),
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final EmployeeMonthSummary? summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Present', value: '${s.present}', color: Colors.green),
              _Stat(label: 'Absent', value: '${s.absent}', color: Colors.red),
              _Stat(label: 'Recorded', value: '${s.recordedDays}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<AttendanceProvider>().refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
