import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiExplanationPage extends StatefulWidget {
  const AiExplanationPage({Key? key}) : super(key: key);

  @override
  State<AiExplanationPage> createState() => _AiExplanationPageState();
}

class _AiExplanationPageState extends State<AiExplanationPage> {
  final SocketService _socketService = SocketService();
  String? aiResponse;
  bool isLoading = true;
  String? error;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _listenAiResponse();
    _fetchStatsAndExplain();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && isLoading) {
        setState(() => error = 'AI açıklaması alınamadı.');
      }
    });
  }

  Future<void> _fetchStatsAndExplain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name') ?? 'Kullanıcı';
      if (userId == null) throw Exception('Kullanıcı bulunamadı');

      final uri = Uri.parse('https://fastapi-aquafocus.onrender.com/stats?user_id=$userId');
      final response = await http.get(uri);
      if (response.statusCode != 200) throw Exception('API hatası: ${response.statusCode}');
      final stats = jsonDecode(response.body) as Map<String, dynamic>;

      // Parse stats
      final focusRate = double.tryParse((stats['focus_rate'] as String).replaceAll('%', '')) ?? 0.0;
      final productivityScore = (stats['avg_productivity_score'] as num).toDouble();
      final completedPomodoros = (stats['completed_pomodoros'] as num).toInt();
      final todayFocusTime = stats['today_focus_time'] as String;
      final avgSessionDuration = (stats['avg_session_duration'] as num).toDouble();
      final weeklyProgress = (stats['weekly_progress'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));

      // Send to Gemini API
      await _sendToGeminiApi(
        userName,
        focusRate,
        productivityScore,
        completedPomodoros,
        todayFocusTime,
        avgSessionDuration,
        weeklyProgress,
      );
    } catch (e) {
      setState(() {
        error = 'Veri alınamadı: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _sendToGeminiApi(
      String userName,
      double focusRate,
      double productivityScore,
      int completedPomodoros,
      String todayFocusTime,
      double avgSessionDuration,
      Map<String, double> weeklyProgress,
      ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAmUkx-fw5yRlHaRz8f9IGZUAeujBUGQSM',
    );

    final prompt = '''
    Hello $userName, based on your current stats, here are a few personalized, practical suggestions to help you improve focus and productivity. Keep them short, actionable, and motivating:
As a guidance counselor, provide short, motivational, and action-focused suggestions based on the user's following stats:
• Focus rate: ${focusRate.toStringAsFixed(1)}%
• Productivity score: ${productivityScore.toStringAsFixed(1)}
• Completed Pomodoro sessions: $completedPomodoros
• Today's focus time: $todayFocusTime
• Average session duration: ${avgSessionDuration.toStringAsFixed(1)} minutes
• Weekly progress: ${weeklyProgress.entries.map((e) => "${e.key}: ${(e.value * 100).toStringAsFixed(1)}%").join(", ")}

Give 3 to 5 clear and practical recommendations to help the user improve.''';


    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        aiResponse = data['candidates'][0]['content']['parts'][0]['text'] ?? 'AI’den yanıt gelmedi.';
        isLoading = false;
      });
    } else {
      setState(() {
        error = 'Gemini API hatası: ${response.statusCode}';
        isLoading = false;
      });
    }
  }

  void _listenAiResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    _socketService.listenAIInsights((data) {
      if (data['userId'] == userId && mounted) {
        _timeoutTimer?.cancel();
        setState(() {
          aiResponse = data['message'] ?? data.toString();
          isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF06555E),
        title: const Text('AI Insights'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06555E), Color(0xFF298690), Color(0xFF5ECEDB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : (error != null)
                ? Text(error!, style: const TextStyle(color: Colors.white))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                aiResponse ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
