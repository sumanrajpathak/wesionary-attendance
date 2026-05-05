import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';

class MarkAttendanceScreen extends StatelessWidget {
  const MarkAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    if (!provider.isConfigured) {
      return const _ErrorState(
        message:
            'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
      );
    }

    if (provider.state == LoadState.loading && provider.employees.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.state == LoadState.error && provider.employees.isEmpty) {
      return _ErrorState(message: provider.error ?? 'Failed to load');
    }

    if (provider.employees.isEmpty) {
      return _EmptyEmployees();
    }

    return Column(
      children: [
        _DateBar(),
        Expanded(child: _EmployeeList()),
        const _SubmitBar(),
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
              onPressed: () =>
                  context.read<AttendanceProvider>().refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEmployees extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No employees found.\n'
              'Add rows to the "Employees" sheet (ID, Name) and reload.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  context.read<AttendanceProvider>().refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final fmt = DateFormat('EEE, MMM d, yyyy').format(provider.selectedDate);
    final count = provider.selectedIds.length;
    final total = provider.employees.length;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.event, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmt, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$count present, ${total - count} absent',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _pickDate(context),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) provider.setDate(picked);
  }
}

class _EmployeeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final employees = provider.employees;

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: Column(
        children: [
          _Toolbar(),
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                final selected = provider.selectedIds.contains(emp.id);
                final markedToday = provider.isMarkedToday(emp.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => provider.toggleSelection(emp.id),
                  title: Text(emp.name.isEmpty ? '(no name)' : emp.name),
                  subtitle: Text(
                    'ID: ${emp.id}'
                    '${markedToday ? ' • already marked today' : ''}',
                    style: TextStyle(
                      color: markedToday ? Colors.orange.shade800 : null,
                    ),
                  ),
                  secondary: CircleAvatar(
                    child: Text(_initials(emp.name)),
                  ),
                );
              },
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

class _Toolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: provider.employees.isEmpty
                ? null
                : () => provider.selectAll(),
            icon: const Icon(Icons.select_all),
            label: const Text('Select all'),
          ),
          TextButton.icon(
            onPressed: provider.selectedIds.isEmpty
                ? null
                : () => provider.clearSelection(),
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Reload from sheet',
            onPressed: provider.state == LoadState.loading
                ? null
                : () => provider.refresh(),
            icon: provider.state == LoadState.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final present = provider.selectedIds.length;
    final total = provider.employees.length;
    final absent = total - present;
    final canSubmit = total > 0 && !provider.submitting;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canSubmit ? () => _submit(context) : null,
            icon: provider.submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                provider.submitting
                    ? 'Submitting…'
                    : 'Submit ($present P / $absent A)',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await provider.submitAttendance();
      messenger.showSnackBar(
        SnackBar(content: Text('Recorded $n entries')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
