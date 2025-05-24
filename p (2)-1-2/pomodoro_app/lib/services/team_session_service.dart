import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class TeamSessionService {
  static const String _teamKey = 'current_team_id';
  static String? currentTeamId;
  static bool isInTeam = false;
  static final _random = Random();

  // 6 haneli benzersiz takım ID'si oluştur
  static String generateUniqueTeamId() {
    // 100000 ile 999999 arasında random sayı üret
    return (100000 + _random.nextInt(900000)).toString();
  }

  // Takıma katıl ve oturumu kaydet
  static Future<void> joinTeam(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamKey, teamId);
    currentTeamId = teamId;
    isInTeam = true;
  }

  // Takımdan çık ve oturumu temizle
  static Future<void> leaveTeam() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_teamKey);
    currentTeamId = null;
    isInTeam = false;
  }

  // Mevcut oturumu kontrol et
  static Future<bool> checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    currentTeamId = prefs.getString(_teamKey);
    isInTeam = currentTeamId != null;
    return isInTeam;
  }
}
