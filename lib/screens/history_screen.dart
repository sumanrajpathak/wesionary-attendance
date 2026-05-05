import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final history = provider.history
        .where((r) => r.status == AttendanceStatus.present)
        .where((r) =>
            matchesQuery(_query, name: r.employeeName, id: r.employeeId))
        .toList();

    if (!provider.isConfigured) {
      return const EmptyState(
        icon: Icons.settings_suggest_outlined,
        title: 'Setup needed',
        subtitle:
            'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
      );
    }

    final pagePad = responsivePagePadding(context);
    final searchBar = Padding(
      padding: EdgeInsets.fromLTRB(pagePad.left, 12, pagePad.right, 4),
      child: SearchField(
        hint: 'Search by name or ID',
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    if (history.isEmpty) {
      final isSearching = _query.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          children: [
            searchBar,
            const SizedBox(height: 60),
            EmptyState(
              icon: isSearching
                  ? Icons.search_off
                  : Icons.event_available_outlined,
              title: isSearching
                  ? 'No matches'
                  : 'No attendance recorded yet',
              subtitle: isSearching
                  ? 'Try a different name or ID.'
                  : 'Pull down to refresh',
            ),
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
        padding: EdgeInsets.fromLTRB(pagePad.left, 0, pagePad.right, pagePad.bottom),
        itemCount: dates.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return searchBar;
          final dateKey = dates[i - 1];
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
    for (final list in map.values) {
      list.sort((a, b) =>
          a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase()));
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
    final theme = Theme.of(context);
    final date = DateTime.parse(dateKey);
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final primary = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('EEEE').format(date);
    final secondary = DateFormat('MMM d, yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: primary,
            subtitle: secondary,
            trailing: CountBadge(
              icon: Icons.people_alt_outlined,
              label: '${records.length} present',
            ),
          ),
          AppCard(
            child: Column(
              children: [
                for (var idx = 0; idx < records.length; idx++) ...[
                  _PersonTile(record: records[idx]),
                  if (idx < records.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                      color:
                          theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final AttendanceRecord record;
  const _PersonTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          AppAvatar(name: record.employeeName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.employeeName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID ${record.employeeId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!record.synced)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Pending sync',
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFB45309),
                ),
              ),
            ),
          if (record.time.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.time,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
