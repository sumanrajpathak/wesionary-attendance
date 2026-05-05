import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../widgets/ui.dart';

class MarkAttendanceScreen extends StatelessWidget {
  const MarkAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    if (!provider.isConfigured) {
      return EmptyState(
        icon: Icons.settings_suggest_outlined,
        title: 'Setup needed',
        subtitle:
            'APPS_SCRIPT_URL is missing from .env. Add it and rebuild the app.',
        action: FilledButton.icon(
          onPressed: () => provider.refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (provider.state == LoadState.loading && provider.employees.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.state == LoadState.error && provider.employees.isEmpty) {
      return ErrorStateView(
        message: friendlyError(provider.error ?? 'Failed to load'),
        onRetry: () => provider.refresh(),
      );
    }

    if (provider.employees.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: 'No employees yet',
        subtitle:
            'Add rows to the "Employees" sheet (ID, Name) and reload.',
        action: FilledButton.icon(
          onPressed: () => provider.refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Reload'),
        ),
      );
    }

    return Column(
      children: const [
        _DateBar(),
        Expanded(child: _EmployeeList()),
        _SubmitBar(),
      ],
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AttendanceProvider>();
    final today = DateTime.now();
    final isToday = provider.selectedDate.year == today.year &&
        provider.selectedDate.month == today.month &&
        provider.selectedDate.day == today.day;
    final primary =
        isToday ? 'Today' : DateFormat('EEEE').format(provider.selectedDate);
    final secondary =
        DateFormat('MMM d, yyyy').format(provider.selectedDate);
    final count = provider.selectedIds.length;
    final total = provider.employees.length;

    final hp = responsiveHorizontalPadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(hp.left, 16, hp.right, 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(primary,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '$secondary • $count of $total selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickDate(context),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Change'),
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

class _EmployeeList extends StatefulWidget {
  const _EmployeeList();

  @override
  State<_EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<_EmployeeList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final theme = Theme.of(context);
    final hp = responsiveHorizontalPadding(context);
    final all = provider.employees;
    final filtered = all
        .where((e) => matchesQuery(_query, name: e.name, id: e.id))
        .toList();

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hp.left, 8, hp.right, 4),
            child: SearchField(
              hint: 'Search by name or ID',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const _Toolbar(),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle: 'Try a different name or ID.',
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(hp.left, 4, hp.right, 16),
                    itemCount: 1,
                    itemBuilder: (context, _) {
                      return AppCard(
                        child: Column(
                          children: [
                            for (var index = 0; index < filtered.length; index++) ...[
                              _EmployeeTile(
                                name: filtered[index].name.isEmpty
                                    ? '(no name)'
                                    : filtered[index].name,
                                id: filtered[index].id,
                                selected: provider.selectedIds
                                    .contains(filtered[index].id),
                                markedToday:
                                    provider.isMarkedToday(filtered[index].id),
                                isFirst: index == 0,
                                isLast: index == filtered.length - 1,
                                onTap: () => provider
                                    .toggleSelection(filtered[index].id),
                              ),
                              if (index < filtered.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 68,
                                  endIndent: 16,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                            ],
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
}

class _EmployeeTile extends StatelessWidget {
  final String name;
  final String id;
  final bool selected;
  final bool markedToday;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _EmployeeTile({
    required this.name,
    required this.id,
    required this.selected,
    required this.markedToday,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.vertical(
      top: Radius.circular(isFirst ? kCardRadius : 0),
      bottom: Radius.circular(isLast ? kCardRadius : 0),
    );
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
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
                        Text('ID $id',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        if (markedToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'marked today',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFB45309),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final hp = responsiveHorizontalPadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(hp.left, 4, hp.right, 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: provider.employees.isEmpty
                ? null
                : () => provider.selectAll(),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select all'),
          ),
          TextButton.icon(
            onPressed: provider.selectedIds.isEmpty
                ? null
                : () => provider.clearSelection(),
            icon: const Icon(Icons.clear, size: 18),
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
    final theme = Theme.of(context);
    final provider = context.watch<AttendanceProvider>();
    final present = provider.selectedIds.length;
    final total = provider.employees.length;
    final absent = total - present;
    final canSubmit = total > 0 && !provider.submitting;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            responsiveHorizontalPadding(context).left,
            12,
            responsiveHorizontalPadding(context).right,
            12,
          ),
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
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                provider.submitting
                    ? 'Submitting…'
                    : 'Submit  •  $present present, $absent absent',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    try {
      final result = await provider.submitAttendance();
      if (!context.mounted) return;
      final people = result.count == 1 ? '1 person' : '${result.count} people';
      if (result.queued) {
        showInfoSnack(
          context,
          "You're offline. Saved for $people locally — will sync when online.",
        );
      } else {
        showSuccessSnack(context, 'Attendance saved for $people.');
      }
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnack(context, e);
    }
  }
}
