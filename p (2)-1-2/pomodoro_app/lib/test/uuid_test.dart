import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import '../services/team_session_service.dart';

void main() {
  test('UUID v4 generation test', () {
    // UUID v4 örnekleri oluştur
    final uuid = Uuid();
    final teamId1 = TeamSessionService.generateUniqueTeamId();
    final teamId2 = TeamSessionService.generateUniqueTeamId();
    final teamId3 = TeamSessionService.generateUniqueTeamId();

    // UUID formatını kontrol et
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    // UUID'lerin formatını kontrol et
    expect(uuidRegex.hasMatch(teamId1), true);
    expect(uuidRegex.hasMatch(teamId2), true);
    expect(uuidRegex.hasMatch(teamId3), true);

    // UUID'lerin benzersiz olduğunu kontrol et
    expect(teamId1 != teamId2, true);
    expect(teamId1 != teamId3, true);
    expect(teamId2 != teamId3, true);

    // Örnek UUID'leri yazdır
    print('Team ID 1: $teamId1');
    print('Team ID 2: $teamId2');
    print('Team ID 3: $teamId3');
  });
}
