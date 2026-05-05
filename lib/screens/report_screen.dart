import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../utils/csv_export.dart';
import '../widgets/ui.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _selectedMonth;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    if (!provider.isConfigured) {
      return const EmptyState(
        icon: Icons.settings_suggest_outlined,
        title: 'Setup needed',
        subtitle:
            'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
      );
    }

    final months = provider.availableMonths();
    if (months.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No attendance recorded yet',
              subtitle: 'Pull down to refresh',
            ),
          ],
        ),
      );
    }

    final selected = _resolveSelected(months);
    final fullSummary =
        provider.monthlySummary(selected.year, selected.month);
    final recordedDays =
        fullSummary.isEmpty ? 0 : fullSummary.first.recordedDays;
    final summary = fullSummary
        .where((s) =>
            matchesQuery(_query, name: s.employeeName, id: s.employeeId))
        .toList();
    final isSearching = _query.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: responsivePagePadding(context),
        children: [
          MonthSelector(
            months: months,
            selected: selected,
            onChanged: (m) => setState(() => _selectedMonth = m),
            trailing: CountBadge(
              icon: Icons.event_outlined,
              label: '$recordedDays day${recordedDays == 1 ? '' : 's'}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: 'Search by name or ID',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Export CSV',
                onPressed: fullSummary.isEmpty
                    ? null
                    : () => _exportCsv(context, selected, fullSummary,
                        recordedDays),
                icon: const Icon(Icons.download_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: isSearching ? Icons.search_off : Icons.people_outline,
                title: isSearching
                    ? 'No matches'
                    : 'No employees in this month',
                subtitle: isSearching ? 'Try a different name or ID.' : null,
              ),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < summary.length; i++) ...[
                    _SummaryRow(
                      summary: summary[i],
                      recordedDays: recordedDays,
                    ),
                    if (i < summary.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
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
  }

  DateTime _resolveSelected(List<DateTime> months) {
    final s = _selectedMonth;
    if (s != null && months.any((m) => m.year == s.year && m.month == s.month)) {
      return s;
    }
    return months.first;
  }

  Future<void> _exportCsv(
    BuildContext context,
    DateTime month,
    List<EmployeeMonthSummary> rows,
    int recordedDays,
  ) async {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final fileLabel = DateFormat('yyyy-MM').format(month);
    final csv = buildCsv([
      ['Employee ID', 'Name', 'Present', 'Absent', 'Recorded days', 'Rate %'],
      for (final r in rows)
        [
          r.employeeId,
          r.employeeName,
          '${r.present}',
          '${r.absent}',
          '$recordedDays',
          recordedDays == 0
              ? ''
              : (r.present / recordedDays * 100).toStringAsFixed(1),
        ],
    ]);
    try {
      await shareCsv(
        filename: 'attendance_$fileLabel.csv',
        content: csv,
        subject: 'Attendance report — $monthLabel',
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnack(context, e);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final EmployeeMonthSummary summary;
  final int recordedDays;
  const _SummaryRow({required this.summary, required this.recordedDays});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = summary.employeeName.isEmpty
        ? '(no name)'
        : summary.employeeName;
    final rate = recordedDays == 0
        ? null
        : (summary.present / recordedDays * 100).round();
    final isDark = theme.brightness == Brightness.dark;
    final rateColor = rate == null
        ? theme.colorScheme.onSurfaceVariant
        : rate >= 90
            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
            : rate >= 75
                ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))
                : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          AppAvatar(name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('ID ${summary.employeeId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    if (rate != null) ...[
                      Text(' • ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      Text(
                        '$rate%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: rateColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        ' (${summary.present}/$recordedDays days)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          StatusChip(label: '${summary.present} P', present: true),
          const SizedBox(width: 6),
          StatusChip(label: '${summary.absent} A', present: false),
        ],
      ),
    );
  }
}

