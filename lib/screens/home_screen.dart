import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/ui.dart';
import 'history_screen.dart';
import 'mark_attendance_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attend = context.watch<AttendanceProvider>();
    final user = auth.user;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Office Attendance'),
                        if (user != null)
                          Text(
                            user.name.isEmpty ? user.email : user.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PendingSyncIndicator(
                    count: attend.pendingCount,
                    syncing: attend.syncing,
                    onTap: () => _retrySync(context),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 24),
            child: ResponsiveCenter(
              child: TabBar(
                tabs: const [
                  Tab(icon: Icon(Icons.checklist_outlined), text: 'Mark'),
                  Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Report'),
                  Tab(icon: Icon(Icons.history_outlined), text: 'History'),
                ],
                dividerColor: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            MarkAttendanceScreen(),
            ReportScreen(),
            HistoryScreen(),
          ],
        ),
      ),
    );
  }

  Future<void> _retrySync(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    try {
      final sent = await provider.retryPendingSync();
      if (!context.mounted) return;
      if (sent > 0) {
        showSuccessSnack(context, 'Synced $sent pending entries.');
      } else if (provider.pendingCount > 0) {
        showInfoSnack(context, 'Still offline — will retry on next refresh.');
      }
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnack(context, e);
    }
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
