import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/reef_background.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bubbleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  final SocketService _socketService = SocketService();

  // State variables
  int completedPomodoros = 0;
  int reefPopulation = 0;
  double reefGrowth = 0;
  int todayFocusMinutes = 0;
  int todayPomodoros = 0;
  Map<String, double> weeklyProgress = {
    "M": 0.0,
    "T": 0.0,
    "W": 0.0,
    "TH": 0.0,
    "F": 0.0,
    "S": 0.0,
    "SN": 0.0
  };
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = '';
  String? _userId;

  final int maxPomodoros = 10;
  final int maxCorals = 20;
  final int maxFish = 15;
  final int maxPlants = 10;

  int _getCreatureCount() {
    if (todayPomodoros <= 1) return 3;
    if (todayPomodoros <= 3) return 6;
    if (todayPomodoros <= 6) return 10;
    if (todayPomodoros <= 8) return 15;
    return 20;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _bubbleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchUserData();
    _initializeSocket();
  }

  void _initializeSocket() {
    if (_socketService.socket != null) {
      _socketService.socket!.off('pomodoroCompleted');
      _socketService.socket!.on('pomodoroCompleted', (data) async {
        if (data['userId'] == null && data['user_id'] == null) return;
        final eventUserId =
            data['userId']?.toString() ?? data['user_id']?.toString();
        if (_userId != null && eventUserId == _userId) {
          await _fetchUserData();
        }
      });
      if (!_socketService.socket!.connected) {
        _socketService.socket!.connect();
      }
    } else {
      Future.delayed(const Duration(seconds: 2), _initializeSocket);
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Get user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      print('[Growth] userId from SharedPreferences: $userId');
      if (userId == null || userId.isEmpty) {
        throw Exception('User not logged in');
      }
      _userId = userId;
      // Fetch user data
      final userData = await _userService.getUserData(userId);
      print('[Growth] userData: $userData');
      if (userData == null) {
        throw Exception('Failed to get user data');
      }
      // Fetch user statistics
      final statsData = await _apiService.getUserStatistics(userId);
      print('[Growth] statsData: $statsData');
      // Fetch reef data
      final reefData = await _apiService.getUserReef(userId);
      print('[Growth] reefData: $reefData');
      // Parse statistics
      int todayMinutes = 0;
      int todaySessions = 0;
      Map<String, double> weekProgress = {
        "M": 0.0,
        "T": 0.0,
        "W": 0.0,
        "T2": 0.0,
        "F": 0.0,
        "S": 0.0,
        "S2": 0.0
      };
      if (statsData != null) {
        final List<dynamic> dailyStats = statsData['daily'] ?? [];
        final List<dynamic> weeklyStats = statsData['weekly'] ?? [];
        for (var daily in dailyStats) {
          todayMinutes += (daily['total_minutes'] as int? ?? 0);
          todaySessions += (daily['session_count'] as int? ?? 0);
        }
        for (var weekly in weeklyStats) {
          int day = weekly['day'] as int? ?? 0;
          if (day > 0 && day <= 7) {
            String dayKey;
            switch (day) {
              case 1:
                dayKey = "M";
                break;
              case 2:
                dayKey = "T";
                break;
              case 3:
                dayKey = "W";
                break;
              case 4:
                dayKey = "T2";
                break;
              case 5:
                dayKey = "F";
                break;
              case 6:
                dayKey = "S";
                break;
              case 7:
                dayKey = "S2";
                break;
              default:
                dayKey = "M";
            }
            weekProgress[dayKey] =
                (weekly['total_minutes'] as int? ?? 0) / 400.0;
          }
        }
      }
      setState(() {
        _userName = userData['username'] ?? 'User';
        _isLoading = false;
        todayFocusMinutes = todayMinutes;
        todayPomodoros = todaySessions;
        weeklyProgress = weekProgress;
        // Get reef population and growth
        if (reefData != null) {
          reefPopulation = (reefData['reef_population'] is int)
              ? reefData['reef_population']
              : (reefData['reef_population'] is double)
                  ? (reefData['reef_population'] as double).round()
                  : int.tryParse(reefData['reef_population'].toString()) ?? 0;
          reefGrowth = (reefData['reef_growth'] is num)
              ? (reefData['reef_growth'] as num).toDouble()
              : double.tryParse(reefData['reef_growth'].toString()) ?? 0.0;
        }
        // Completed pomodoros = reefPopulation (for ecosystem)
        completedPomodoros = reefPopulation;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
        print('[Growth] Error fetching user data: $e');
      });
    }
  }

  @override
  void dispose() {
    if (_socketService.socket != null) {
      _socketService.socket!.off('pomodoroCompleted');
    }
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildBubble(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 8 + 3;
    final startX = random.nextDouble() * 1.2 - 0.1;
    final startY = random.nextDouble() * 1.2 - 0.1;
    final duration = Duration(seconds: 3 + random.nextInt(4));

    return AnimatedBuilder(
      animation: _bubbleAnimation,
      builder: (context, child) {
        final progress = _bubbleAnimation.value;
        final yPos = startY - progress * 1.4;
        final xOffset = math.sin(progress * math.pi * 2) * 0.1;
        final scale = 1.0 - progress * 0.3;
        final opacity = 1.0 - progress * 0.7;

        return Positioned(
          left: (startX + xOffset) * MediaQuery.of(context).size.width,
          top: yPos * MediaQuery.of(context).size.height,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF64C8FF).withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWave(double height, double offset, double opacity) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        final progress = _waveAnimation.value;
        final waveOffset = math.sin(progress * math.pi * 2 + offset) * 30;

        return Positioned(
          bottom: height,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 100),
            painter: WavePainter(
              waveOffset: waveOffset,
              opacity: opacity,
              color: Colors.white.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFish(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 40 + 70;
    final startX = random.nextDouble() * 0.9 + 0.05;
    final startY = random.nextDouble() * 0.7 + 0.15;
    final duration = Duration(seconds: 8 + random.nextInt(4));

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final progress = _animationController.value;
        final xPos = startX + progress * 0.9;
        final yOffset = math.sin(progress * math.pi * 2) * 0.08;
        final scale = 1.0 + math.sin(progress * math.pi * 2) * 0.15;

        return Positioned(
          left: xPos * MediaQuery.of(context).size.width,
          top: (startY + yOffset) * MediaQuery.of(context).size.height,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              'assets/images/fish${(index % 3) + 1}.png',
              width: size,
              height: size,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoral(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 50 + 40;
    final xPos = random.nextDouble() * 0.8 + 0.1;
    final yPos = random.nextDouble() * 0.6 + 0.2;

    return Positioned(
      left: xPos * MediaQuery.of(context).size.width,
      top: yPos * MediaQuery.of(context).size.height,
      child: Image.asset(
        'assets/images/coral${(index % 3) + 1}.png',
        width: size,
        height: size,
      ),
    );
  }

  Widget _buildPlant(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 45 + 35;
    final xPos = random.nextDouble() * 0.8 + 0.1;
    final yPos = random.nextDouble() * 0.6 + 0.2;

    return Positioned(
      left: xPos * MediaQuery.of(context).size.width,
      top: yPos * MediaQuery.of(context).size.height,
      child: Image.asset(
        'assets/images/plant${(index % 3) + 1}.png',
        width: size,
        height: size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creatureCount = _getCreatureCount();
    final fishCount = (creatureCount * 0.6).round();
    final coralCount = (creatureCount * 0.3).round();
    final plantCount = (creatureCount * 0.1).round();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Arka plan gradyanı
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF136A8A),
                        Color(0xFF267871),
                      ],
                    ),
                  ),
                ),

                // Dalga animasyonları
                _buildWave(0, 0, 0.3),
                _buildWave(20, math.pi / 2, 0.2),
                _buildWave(40, math.pi, 0.1),

                // Baloncuk animasyonları
                ...List.generate(30, (index) => _buildBubble(index)),

                // Resif sahnesi
                ReefBackground(
                  coralCount: coralCount,
                  fishCount: fishCount,
                  plantCount: plantCount,
                  userId: _userId ?? 'default',
                ),

                // Error message if any
                if (_errorMessage != null)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.1,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Üst panel
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _userName.isNotEmpty
                                    ? '$_userName\'s Progress'
                                    : 'Your Progress',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Today\'s Focus Time: $todayFocusMinutes min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Today\'s Pomodoros: $todayPomodoros',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Ekosistem durumu
                              Text(
                                'Ecosystem Progress: ${(todayPomodoros * 10).clamp(0, 100)}%${(todayPomodoros * 10) >= 100 ? ' 🎉 🎊 🐠' : ''}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: (todayPomodoros / 10).clamp(0, 1),
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color.fromARGB(255, 0, 182, 228)),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _fetchUserData,
                                icon: const Icon(Icons.refresh,
                                    color: Colors.white),
                                label: Text(
                                  'Refresh',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Alt navigasyon çubuğu
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(Icons.home_outlined, 0),
                            _buildNavItem(Icons.menu, 1),
                            _buildNavItem(Icons.bolt_outlined, 2),
                            _buildNavItem(Icons.bar_chart_outlined, 3,
                                isSelected: true),
                            _buildNavItem(Icons.settings_outlined, 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, {bool isSelected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isSelected
              ? const Color(0xFFEF476F)
              : Colors.white.withOpacity(0.6),
          size: 28,
        ),
        onPressed: () {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/tasks');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/pomodoro');
              break;
            case 3:
              break; // Zaten buradayız
            case 4:
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double waveOffset;
  final double opacity;
  final Color color;

  WavePainter(
      {required this.waveOffset, required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    path.moveTo(0, size.height / 2);

    for (double i = 0; i < size.width; i++) {
      final y = size.height / 2 + math.sin(i * 0.04 + waveOffset) * 16;
      path.lineTo(i, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.waveOffset != waveOffset ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}
