import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

const kCardRadius = 16.0;
const kPillRadius = 999.0;
const kPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
const kContentMaxWidth = 720.0;

EdgeInsets responsivePagePadding(BuildContext context, {double maxWidth = kContentMaxWidth}) {
  final w = MediaQuery.sizeOf(context).width;
  final horizontal = w > maxWidth ? (w - maxWidth) / 2 : 16.0;
  return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24);
}

EdgeInsets responsiveHorizontalPadding(BuildContext context, {double maxWidth = kContentMaxWidth}) {
  final w = MediaQuery.sizeOf(context).width;
  final horizontal = w > maxWidth ? (w - maxWidth) / 2 : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal);
}

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  const AppAvatar({super.key, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = avatarColorFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? onColor;
  const CountBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.primaryContainer;
    final fg = onColor ?? theme.colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kPillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final bool present;
  const StatusChip({super.key, required this.label, required this.present});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = present
        ? const Color(0xFF10B981).withValues(alpha: 0.15)
        : const Color(0xFFEF4444).withValues(alpha: 0.15);
    final fg = present ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kPillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? scheme.onSurface : fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorStateView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      subtitle: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

const _avatarPalette = <Color>[
  Color(0xFF4F46E5),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

class MonthSelector extends StatelessWidget {
  final List<DateTime> months;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final Widget? trailing;

  const MonthSelector({
    super.key,
    required this.months,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat('MMMM yyyy').format(selected);
    final hasMultiple = months.length > 1;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (hasMultiple) ...[
            Icon(
              Icons.unfold_more,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: hasMultiple
          ? PopupMenuButton<DateTime>(
              tooltip: 'Choose month',
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: onChanged,
              itemBuilder: (ctx) => months
                  .map(
                    (m) => PopupMenuItem<DateTime>(
                      value: m,
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(DateFormat('MMMM yyyy').format(m))),
                          if (m.year == selected.year &&
                              m.month == selected.month)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(kCardRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(kCardRadius),
                  onTap: null,
                  child: content,
                ),
              ),
            )
          : content,
    );
  }
}

class PendingSyncIndicator extends StatelessWidget {
  final int count;
  final bool syncing;
  final VoidCallback onTap;
  const PendingSyncIndicator({
    super.key,
    required this.count,
    required this.syncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final amber = theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(kPillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kPillRadius),
          onTap: syncing ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncing)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: amber,
                    ),
                  )
                else
                  Icon(Icons.cloud_upload_outlined, size: 14, color: amber),
                const SizedBox(width: 6),
                Text(
                  syncing ? 'Syncing…' : '$count pending',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => themeProvider.toggle(context),
    );
  }
}

class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final String initialValue;
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(
          Icons.search,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, value, __) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctrl.clear();
                widget.onChanged('');
              },
            );
          },
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

bool matchesQuery(String query, {required String name, required String id}) {
  if (query.trim().isEmpty) return true;
  final q = query.trim().toLowerCase();
  return name.toLowerCase().contains(q) || id.toLowerCase().contains(q);
}

String friendlyError(Object error) {
  final raw = error.toString().trim();
  final lower = raw.toLowerCase();

  if (lower.contains('popup_closed') ||
      lower.contains('popup closed') ||
      lower.contains('sign-in cancelled') ||
      lower.contains('sign_in_canceled') ||
      lower.contains('sign in canceled') ||
      lower.contains('user_cancelled') ||
      lower.contains('user cancelled')) {
    return 'Sign-in was cancelled.';
  }
  if (lower.contains('popup_blocked') || lower.contains('popup blocked')) {
    return 'Your browser blocked the sign-in popup. Please allow popups for this site and try again.';
  }
  if (lower.contains('network_error') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('connection') ||
      lower.contains('handshake')) {
    return 'Network error. Check your internet connection and try again.';
  }
  if (lower.contains('timeout')) {
    return 'The request timed out. Please try again.';
  }
  if (lower.contains('http 401') || lower.contains('http 403') ||
      lower.contains('not authorized')) {
    return "You're not authorized to do that.";
  }
  if (lower.contains('http 404')) {
    return 'Resource not found. Please check your setup.';
  }
  if (RegExp(r'http 5\d\d').hasMatch(lower)) {
    return 'Server error. Please try again in a moment.';
  }
  if (lower.contains('apps_script_url is missing')) {
    return 'Setup is incomplete: APPS_SCRIPT_URL is missing from .env.';
  }
  if (lower.contains('login response')) {
    return "Sign-in didn't complete. Please try again.";
  }
  if (lower.contains('admin login required')) {
    return 'Only admins can submit attendance.';
  }
  if (lower.contains('invalid_credentials') ||
      lower.contains('invalid email or password') ||
      lower.contains('wrong password')) {
    return 'Invalid email or password.';
  }

  // Strip "SheetsApiException: " or other "Foo: " prefix.
  final colon = raw.indexOf(':');
  final cleaned = colon > 0 && colon < 40 ? raw.substring(colon + 1).trim() : raw;
  if (cleaned.isEmpty) return 'Something went wrong. Please try again.';
  return cleaned;
}

void showErrorSnack(BuildContext context, Object error) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                friendlyError(error),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: scheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
}

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
}

void showInfoSnack(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: scheme.inverseSurface,
      ),
    );
}

Color avatarColorFor(String name) {
  var hash = 0;
  for (final code in name.toLowerCase().codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}
