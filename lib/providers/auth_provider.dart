import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';
import '../services/sheets_api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({SheetsApiService? service, GoogleSignIn? googleSignIn})
      : _service = service ?? SheetsApiService(),
        _googleSignIn = googleSignIn ?? _defaultGoogleSignIn();

  final SheetsApiService _service;
  final GoogleSignIn _googleSignIn;

  static const _kSession = 'auth_session_v1';

  UserSession? _user;
  bool _bootstrapping = true;
  bool _busy = false;

  UserSession? get user => _user;
  bool get bootstrapping => _bootstrapping;
  bool get busy => _busy;
  SheetsApiService get service => _service;

  static GoogleSignIn _defaultGoogleSignIn() {
    final serverClientId = dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID')?.trim();
    final webClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim();
    return GoogleSignIn(
      scopes: const ['email'],
      clientId: kIsWeb && webClientId != null && webClientId.isNotEmpty
          ? webClientId
          : null,
      serverClientId:
          !kIsWeb && serverClientId != null && serverClientId.isNotEmpty
              ? serverClientId
              : null,
    );
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSession);
    if (raw != null) {
      try {
        _user = UserSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        await prefs.remove(_kSession);
      }
    }
    _bootstrapping = false;
    notifyListeners();
  }

  Future<void> loginAdmin(String email, String password) async {
    _setBusy(true);
    try {
      final session = await _service.loginAdmin(email, password);
      await _persist(session);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> loginWithGoogle() async {
    _setBusy(true);
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw SheetsApiException('Google sign-in cancelled.');
      }
      final session = await _service.loginGoogle(account.email);
      await _persist(session);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSession);
    _user = null;
    notifyListeners();
  }

  Future<void> _persist(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSession, jsonEncode(session.toJson()));
    _user = session;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
