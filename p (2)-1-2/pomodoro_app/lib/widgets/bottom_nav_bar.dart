import 'package:flutter/material.dart';
import '../screens/home_page.dart';
import '../screens/home_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/settings_screen.dart';
import '../services/user_service.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  Future<void> _onNavItemTapped(int index, BuildContext context) async {
    if (selectedIndex == index) return;

    // Get userId from SharedPreferences
    final userId = await UserService.getUserId();

    if (userId == null) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    if (!context.mounted) return;

    switch (index) {
      case 0: // Home Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userId: userId)),
        );
        break;
      case 1: // Tasks
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TasksScreen(userId: userId)),
        );
        break;
      case 2: // Pomodoro Timer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
        );
        break;
      case 3: // Statistics
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StatisticsScreen()),
        );
        break;
      case 4: // Settings
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
  }

  Widget _buildNavButton(IconData icon, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF32FFFF).withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF64C8FF).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFDCFAFF) : const Color(0x99DCFAFF),
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF144678).withOpacity(0.4),
            const Color(0xFF1E5096).withOpacity(0.4),
            const Color(0xFF144678).withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001E50).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(Icons.home, selectedIndex == 0,
              onTap: () => _onNavItemTapped(0, context)),
          _buildNavButton(Icons.menu, selectedIndex == 1,
              onTap: () => _onNavItemTapped(1, context)),
          _buildNavButton(Icons.bolt, selectedIndex == 2,
              onTap: () => _onNavItemTapped(2, context)),
          _buildNavButton(Icons.bar_chart, selectedIndex == 3,
              onTap: () => _onNavItemTapped(3, context)),
          _buildNavButton(Icons.settings, selectedIndex == 4,
              onTap: () => _onNavItemTapped(4, context)),
        ],
      ),
    );
  }
}
