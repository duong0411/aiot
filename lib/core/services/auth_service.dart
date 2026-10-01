import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  // Đường dẫn Backend mặc định qua tên miền riêng Cloudflare Tunnel
  static String baseUrl = 'https://duynguyen.io.vn/api'; 

  String? _token;
  String? get token => _token;

  Future<void> updateBaseUrl(String newUrl) async {
    baseUrl = newUrl.endsWith('/api') ? newUrl : '$newUrl/api';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', baseUrl);
  }

  Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl;
    }
  }

  // ─── Lưu/Xóa thông tin người dùng ──────────────────────────────────────────
  Future<void> _saveUserData(String token, Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_data', jsonEncode(userJson));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    _token = null;
  }

  Future<UserModel?> loadSavedUser() async {
    await loadBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userData = prefs.getString('user_data');
    if (token != null && userData != null) {
      _token = token;
      return UserModel.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<UserModel?> login(String email, String password) async {
    await loadBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      _token = data['data']['token'];
      final user = UserModel.fromJson(data['data']['user']);
      await _saveUserData(_token!, data['data']['user']);
      return user;
    }
    throw Exception(data['message'] ?? 'Đăng nhập thất bại');
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  Future<UserModel?> register(String name, String email, String phone, String password) async {
    await loadBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name, 
        'email': email, 
        'phone': phone, 
        'password': password
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      _token = data['data']['token'];
      final user = UserModel.fromJson(data['data']['user']);
      await _saveUserData(_token!, data['data']['user']);
      return user;
    }
    throw Exception(data['message'] ?? 'Đăng ký thất bại');
  }

  // ─── Reset Password ───────────────────────────────────────────────────────
  Future<void> resetPassword(String email, String newPassword) async {
    await loadBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'newPassword': newPassword}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Đặt lại mật khẩu thất bại');
    }
  }
}
