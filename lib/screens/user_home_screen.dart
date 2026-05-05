import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/ui.dart';

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
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Text('My Attendance')),
                IconButton(
                  tooltip: 'Refresh',
                  icon: provider.state == LoadState.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: provider.state == LoadState.loading
                      ? null
                      : () => provider.refresh(),
                ),
                const ThemeToggleButton(),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (user == null) return const SizedBox.shrink();

          if (provider.state == LoadState.loading && provider.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.state == LoadState.error && provider.history.isEmpty) {
            return ErrorStateView(
              message: friendlyError(provider.error ?? 'Failed to load'),
              onRetry: () => provider.refresh(),
            );
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
              padding: responsivePagePadding(context),
              children: [
                _ProfileHeader(name: user.name, email: user.email),
                const SizedBox(height: 16),
                MonthSelector(
                  months: months,
                  selected: selected,
                  onChanged: (m) => setState(() => _selectedMonth = m),
                ),
                const SizedBox(height: 16),
                _SummaryCard(summary: summary),
                const SizedBox(height: 16),
                if (dayList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No attendance recorded',
                      subtitle: 'No entries for this month yet.',
                    ),
                  )
                else
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < dayList.length; i++) ...[
                          _DayRow(record: dayList[i]),
                          if (i < dayList.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                        ],
                      ],
                    ),
                  ),
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

class _DayRow extends StatelessWidget {
  final AttendanceRecord record;
  const _DayRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPresent = record.status == AttendanceStatus.present;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(record.date),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy').format(record.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: isPresent ? 'Present' : 'Absent',
            present: isPresent,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  const _ProfileHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          AppAvatar(name: name.isEmpty ? '?' : name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '(no name)' : name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Row(
        children: [
          Expanded(
              child: _Stat(
            label: 'Present',
            value: '${s.present}',
            color: const Color(0xFF10B981),
          )),
          _Divider(),
          Expanded(
              child: _Stat(
            label: 'Absent',
            value: '${s.absent}',
            color: const Color(0xFFEF4444),
          )),
          _Divider(),
          Expanded(
              child: _Stat(
            label: 'Recorded',
            value: '${s.recordedDays}',
          )),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
