import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/ocean_background.dart';
import '../widgets/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required String userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _waterController;
  late AnimationController _bubblesController;
  late AnimationController _glowController;
  late AnimationController _particlesController;
  late Timer _timer;
  String _currentTime = '';
  String _currentPeriod = '';

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    setState(() {
      final now = DateTime.now().toUtc().add(const Duration(hours: 3)); // GMT+3
      _currentTime = DateFormat('HH:mm').format(now);
      _currentPeriod = DateFormat('ss').format(now);
    });
  }

  void _setupAnimationControllers() {
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bubblesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _timer.cancel();
    _waterController.dispose();
    _bubblesController.dispose();
    _glowController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let\'s make today productive',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Modern Clock Display
                      _buildModernClock(),
                      const SizedBox(height: 40),
                      // Menu Boxes - 2x2 Grid
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          padding: const EdgeInsets.all(8),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMenuBox(
                              'Growth',
                              'Track your\nprogress',
                              Icons.trending_up,
                              const Color(0xFF64C8FF),
                              () => Navigator.pushNamed(context, '/growth'),
                            ),
                            _buildMenuBox(
                              'Achievements',
                              'View your\nachievements',
                              Icons.emoji_events,
                              const Color(0xFFFFD700),
                              () =>
                                  Navigator.pushNamed(context, '/achievements'),
                            ),
                            _buildMenuBox(
                              'Tasks',
                              'Manage your\ntasks',
                              Icons.task,
                              const Color.fromARGB(255, 0, 106, 4),
                              () => Navigator.pushNamed(context, '/tasks'),
                            ),
                            _buildMenuBox(
                              'AI Insights',
                              'AI Explanations Part',
                              Icons.psychology,
                              const Color(0xFF64C8FF),
                              () => Navigator.pushNamed(
                                  context, '/ai_explanation'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom navigation bar
              const BottomNavBar(selectedIndex: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnderwaterEffect() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF02162D),
          ),
        ),
        ...List.generate(5, (index) => _buildBubble(index)),
        ...List.generate(8, (index) => _buildParticle(index)),
      ],
    );
  }

  Widget _buildBubble(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 8 + 2;

    return AnimatedBuilder(
      animation: _bubblesController,
      builder: (context, child) {
        final startX = random.nextDouble() * MediaQuery.of(context).size.width;
        final startY = MediaQuery.of(context).size.height;
        final endY = startY * 0.2;

        final currentY = startY - (_bubblesController.value * (startY - endY));
        if (currentY < 0) return const SizedBox.shrink();

        return Positioned(
          left: startX + math.sin(_bubblesController.value * math.pi * 2) * 20,
          top: currentY,
          child: child ?? const SizedBox.shrink(),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.3),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticle(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 3 + 1;

    return AnimatedBuilder(
      animation: _particlesController,
      builder: (context, child) {
        final startX = random.nextDouble() * MediaQuery.of(context).size.width;
        final startY = MediaQuery.of(context).size.height;
        final endY = startY * 0.3;

        final currentY =
            startY - (_particlesController.value * (startY - endY));
        if (currentY < 0) return const SizedBox.shrink();

        return Positioned(
          left: startX,
          top: currentY,
          child: child ?? const SizedBox.shrink(),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x99B4F0FF),
        ),
      ),
    );
  }

  Widget _buildModernClock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1964C8FF),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _currentTime,
            style: const TextStyle(
              color: Color(0xFFDCFAFF),
              fontSize: 72,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1932FFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _currentPeriod,
                  style: const TextStyle(
                    color: Color(0xFFDCFAFF),
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'GMT+3',
                style: TextStyle(
                  color: Color(0x99DCFAFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroBox({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF64C8FF).withOpacity(0.2),
              const Color(0xFF3B7CFF).withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF64C8FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B7CFF).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt,
                color: Color(0xFFDCFAFF),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pomodoro\nTimer',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFDCFAFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgressBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3364C8FF),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: 0.7,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF64C8FF)),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '125',
                        style: TextStyle(
                          color: const Color(0xFFDCFAFF),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'dk',
                        style: TextStyle(
                          color: const Color(0xFFDCFAFF),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '5 Pomodoro',
            style: TextStyle(
              color: const Color(0xFFDCFAFF).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBox(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
