// ✅ Güncellenmiş API servis dosyası (user ve team routes ile tam uyumlu)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import '../services/socket_service.dart';

class ApiService {
  final SocketService _socketService = SocketService();

  static String get baseUrl {
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$host:3306/api';
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ✅ Kullanıcı işlemleri
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Kayıt başarısız: ${response.body}');
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final userId = data['id'] ?? data['user_id'];
      if (userId == null) throw Exception('userId eksik');
      data['userId'] = userId.toString();
      return data;
    } else {
      throw Exception('Giriş başarısız: ${response.body}');
    }
  }

  Future<List<dynamic>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) return json.decode(response.body)['users'];
    throw Exception('Kullanıcı listesi alınamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> getUserReef(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/reef/$userId'));
    if (response.statusCode == 200) return json.decode(response.body)['reef'];
    throw Exception('Reef bilgisi alınamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> completeUserPomodoro({
    required String userId,
    required int duration,
    required DateTime completedAt,
    String type = 'focus',
    String status = 'completed',
  }) async {
    try {
      print(
          'Sending pomodoro completion request to: $baseUrl/pomodoro/complete');
      print('Request body: ${json.encode({
            'user_id': userId,
            'duration': duration,
            'completed_at': completedAt.toIso8601String(),
            'type': type,
            'status': status,
          })}');

      final response = await http.post(
        Uri.parse('$baseUrl/pomodoro/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'duration': duration,
          'completed_at': completedAt.toIso8601String(),
          'type': type,
          'status': status,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // İstatistikleri güncelle
        await _updateUserStatistics(userId);

        // Başarımları kontrol et
        final achievements = await _checkAchievements(userId);

        // Creature gelişimini kontrol et
        final creatures = await _checkCreatures(userId);

        // Socket event'ini emit et (socket server.yagiz.tc:666'da)
        _socketService.socket?.emit('pomodoroCompleted', {
          'userId': userId,
          'duration': duration,
          'completedAt': completedAt.toIso8601String(),
          'type': type,
          'status': status,
        });

        return {...data, 'achievements': achievements, 'creatures': creatures};
      } else {
        final errorData = json.decode(response.body);
        print('Error response: $errorData');
        throw Exception(errorData['message'] ?? 'Pomodoro kaydı başarısız');
      }
    } catch (e) {
      print('Error in completeUserPomodoro: $e');
      throw Exception('Pomodoro kaydı sırasında bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> _updateUserStatistics(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user_statistics/$userId'),
      );
      return json.decode(response.body);
    } catch (e) {
      print('İstatistik güncellemesi başarısız: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _checkAchievements(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user_achievements/$userId'),
      );
      return List<Map<String, dynamic>>.from(
          json.decode(response.body)['achievements'] ?? []);
    } catch (e) {
      print('Başarım kontrolü başarısız: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _checkCreatures(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user_creatures/$userId'),
      );
      return List<Map<String, dynamic>>.from(
          json.decode(response.body)['creatures'] ?? []);
    } catch (e) {
      print('Creature kontrolü başarısız: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/users/profile/$userId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'username': data['name'] ?? 'Anonymous',
        'aiExplanation': data['aiExplanation'] ?? 'No description available',
      };
    } else {
      return {
        'username': 'Anonymous',
        'aiExplanation': 'No description available',
      };
    }
  }

  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      print('Fetching user statistics from: $baseUrl/stats/$userId');
      final response = await http.get(
        Uri.parse('$baseUrl/stats/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Statistics API Response Status: ${response.statusCode}');
      print('Statistics API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
            'Failed to get statistics: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getUserStatistics: $e');
      throw Exception('Failed to get statistics: $e');
    }
  }

  Future<void> updateUserStatistics({
    required String userId,
    required int productivityScore,
    required int focusLevel,
  }) async {
    try {
      print('Updating user statistics for userId: $userId');
      final response = await http.post(
        Uri.parse('$baseUrl/user_statistics/update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'productivity_score': productivityScore,
          'focus_level': focusLevel,
        }),
      );

      print('Update Statistics API Response Status: ${response.statusCode}');
      print('Update Statistics API Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update statistics: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in updateUserStatistics: $e');
      throw Exception('Failed to update statistics: $e');
    }
  }

  Future<List<dynamic>> getTasks() async {
    final response = await http.get(Uri.parse('$baseUrl/tasks'));
    if (response.statusCode == 200) return json.decode(response.body)['tasks'];
    throw Exception('Görevler alınamadı: ${response.body}');
  }

  Future<List<dynamic>> getUserTasks(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user_tasks/$userId'));
    if (response.statusCode == 200)
      return json.decode(response.body)['user_tasks'];
    throw Exception('Kullanıcı görevleri alınamadı: ${response.body}');
  }

  // ✅ Takım işlemleri
  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_name': teamName,
        'user_id': userId,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Takım oluşturma başarısız: ${response.body}');
  }

  Future<List<dynamic>> getTeams() async {
    final response = await http.get(Uri.parse('$baseUrl/teams'));
    if (response.statusCode == 200) return json.decode(response.body)['teams'];
    throw Exception('Takım listesi alınamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> joinTeam({
    required String teamId,
    required String userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/join'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_id': teamId,
        'user_id': userId,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Takıma katılım başarısız: ${response.body}');
  }

  Future<List<dynamic>> getTeamMembers(String teamId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/teams/members/$teamId'));
    if (response.statusCode == 200)
      return json.decode(response.body)['members'];
    throw Exception('Takım üyeleri alınamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> removeTeamMember({
    required String teamId,
    required String userId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teams/remove'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_id': teamId,
        'user_id': userId,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Üye çıkarılamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> deleteTeam(String teamId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teams/delete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_id': teamId,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Takım silinemedi: ${response.body}');
  }

  Future<Map<String, dynamic>> getTeamReef(String teamId) async {
    final response = await http.get(Uri.parse('$baseUrl/teams/reef/$teamId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Takım reef bilgisi alınamadı: ${response.body}');
  }

  Future<Map<String, dynamic>> updateTeamReef({
    required String teamId,
    required double pollutionChange,
    required int populationChange,
    required double growthChange,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/reef/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_id': teamId,
        'pollution_change': pollutionChange,
        'population_change': populationChange,
        'growth_change': growthChange,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Reef güncelleme başarısız: ${response.body}');
  }

  Future<Map<String, dynamic>> completeTeamPomodoro({
    required String userId,
    required String teamId,
    required int duration,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/pomodoro/complete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'room_id': teamId,
        'duration': duration,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Takım pomodoro kaydı başarısız: ${response.body}');
  }

  Future<Map<String, dynamic>> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/leave'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'room_id': teamId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to leave team: ${response.body}');
    }
  }

  // ✅ Yaratık işlemleri
  Future<List<dynamic>> getCreatures() async {
    final response = await http.get(Uri.parse('$baseUrl/creatures'));
    if (response.statusCode == 200)
      return json.decode(response.body)['creatures'];
    throw Exception('Yaratıklar alınamadı: ${response.body}');
  }

  Future<List<dynamic>> getUserCreatures(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/user_creatures/$userId'));
    if (response.statusCode == 200)
      return json.decode(response.body)['creatures'];
    throw Exception('Kullanıcı yaratıkları alınamadı: ${response.body}');
  }

  // Hem kullanıcı hem takım pomodoro'sunu tamamlar
  Future<Map<String, dynamic>> completePomodoro({
    required String userId,
    required int duration,
    String? teamId, // Opsiyonel takım ID'si
  }) async {
    try {
      // Önce kullanıcı pomodoro'sunu tamamla
      final userResult = await completeUserPomodoro(
        userId: userId,
        duration: duration,
        completedAt: DateTime.now(),
        type: 'focus',
        status: 'completed',
      );

      // Eğer takım ID'si varsa, takım pomodoro'sunu da tamamla
      if (teamId != null) {
        final teamResult = await completeTeamPomodoro(
          userId: userId,
          teamId: teamId,
          duration: duration,
        );

        return {
          'user_result': userResult,
          'team_result': teamResult,
        };
      }

      return {'user_result': userResult};
    } catch (e) {
      throw Exception('Pomodoro tamamlama sırasında bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> createUserTask({
    required String userId,
    required String description,
    required String taskType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user_tasks'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'description': description,
        'task_type': taskType,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Görev eklenemedi: ${response.body}');
  }

  Future<void> completeUserTask({
    required String userId,
    required String taskId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user_tasks/complete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'task_id': taskId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Görev tamamlanamadı: ${response.body}');
    }
  }

  Future<void> uncompleteUserTask({
    required String userId,
    required String taskId,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/user_tasks/uncomplete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'task_id': taskId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Görev geri alınamadı: ${response.body}');
    }
  }

  Future<void> deleteUserTask({
    required String userId,
    required String taskId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/user_tasks'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'task_id': taskId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Görev silinemedi: ${response.body}');
    }
  }

  Future<void> submitPomodoroSurvey({
    required String sessionId,
    required int productivityScore,
    required int focusLevel,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pomodoro/session/survey'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'session_id': sessionId,
        'productivity_score': productivityScore,
        'focus_level': focusLevel,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to submit survey: \\${response.statusCode} - \\${response.body}');
    }
  }
}
