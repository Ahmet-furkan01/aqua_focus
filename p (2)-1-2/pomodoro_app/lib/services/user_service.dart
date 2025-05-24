import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _baseUrl = 'http://10.0.2.2:3306/api';

  static Future<void> saveUserData(
      String userId, String userName, String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userNameKey, userName);
    await prefs.setString(_userEmailKey, userEmail);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
  }

  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      print('Fetching user data for userId: $userId');
      final response = await http.get(
        Uri.parse('$_baseUrl/users/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      print('User profile response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userData = data['user'];
        if (userData == null) {
          throw Exception('No user object in response: ${response.body}');
        }
        return {
          'userId': userData['user_id'] ?? userId,
          'username': userData['name'] ?? 'Anonymous',
          'reefId': 'default_reef',
        };
      } else {
        throw Exception('Failed to get user data: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting user data: $e');
    }
  }
}
