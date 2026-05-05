import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showAdminForm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final busy = auth.busy;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [ThemeToggleButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.event_available,
                      size: 44,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Office Attendance',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: busy ? null : () => _googleSignIn(context),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () =>
                            setState(() => _showAdminForm = !_showAdminForm),
                    child: Text(
                      _showAdminForm ? 'Hide admin login' : 'Admin login',
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _showAdminForm
                        ? _buildAdminForm(context, busy)
                        : const SizedBox.shrink(),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminForm(BuildContext context, bool busy) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => _adminSignIn(context),
              icon: const Icon(Icons.lock),
              label: const Text('Sign in as admin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _googleSignIn(BuildContext context) async {
    try {
      await context.read<AuthProvider>().loginWithGoogle();
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _adminSignIn(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await context.read<AuthProvider>().loginAdmin(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnack(context, e);
    }
  }
}
