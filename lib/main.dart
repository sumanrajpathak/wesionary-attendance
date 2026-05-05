import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProxyProvider<AuthProvider, AttendanceProvider>(
          create: (_) => AttendanceProvider(),
          update: (_, auth, attend) {
            attend!.setActor(auth.user);
            return attend;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'Office Attendance',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.mode,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) return const LoginScreen();
    return user.isAdmin ? const HomeScreen() : const UserHomeScreen();
  }
}
