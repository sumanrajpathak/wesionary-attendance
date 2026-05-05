import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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
    final auth = context.watch<AuthProvider>();
    final busy = auth.busy;

    return Scaffold(
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
                  const Icon(Icons.event_available, size: 72, color: Colors.indigo),
                  const SizedBox(height: 12),
                  const Text(
                    'Office Attendance',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: busy ? null : () => _googleSignIn(context),
                    icon: const Icon(Icons.login),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sign in with Google'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _showAdminForm = !_showAdminForm),
                    child: Text(
                      _showAdminForm ? 'Hide admin login' : 'Admin login',
                    ),
                  ),
                  if (_showAdminForm) _buildAdminForm(context, busy),
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
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => _adminSignIn(context),
              icon: const Icon(Icons.lock),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Sign in as admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _googleSignIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().loginWithGoogle();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _adminSignIn(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().loginAdmin(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }
}
