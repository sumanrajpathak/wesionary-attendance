import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import 'history_screen.dart';
import 'mark_attendance_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Office Attendance'),
              if (user != null)
                Text(
                  user.name.isEmpty ? user.email : user.name,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.checklist), text: 'Mark'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Report'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
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
