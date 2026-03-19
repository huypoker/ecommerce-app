import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  String? _token;
  User? _user;

  AuthProvider(this._prefs) {
    _token = _prefs.getString('token');
    final id = _prefs.getInt('userId');
    final name = _prefs.getString('userName');
    final email = _prefs.getString('userEmail');
    final role = _prefs.getString('userRole');
    if (_token != null && id != null) {
      _user = User(id: id, name: name ?? '', email: email ?? '', role: role ?? 'user');
    }
  }

  String? get token => _token;
  User? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<String?> login(String email, String password) async {
    try {
      final data = await ApiService.login(email, password);
      if (data['error'] != null) return data['error'];
      _token = data['token'];
      _user = User.fromJson(data['user']);
      await _saveToPrefs();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final data = await ApiService.register(name, email, password);
      if (data['error'] != null) return data['error'];
      _token = data['token'];
      _user = User.fromJson(data['user']);
      await _saveToPrefs();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _prefs.clear();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    if (_token != null) await _prefs.setString('token', _token!);
    if (_user != null) {
      await _prefs.setInt('userId', _user!.id);
      await _prefs.setString('userName', _user!.name);
      await _prefs.setString('userEmail', _user!.email);
      await _prefs.setString('userRole', _user!.role);
    }
  }
}
