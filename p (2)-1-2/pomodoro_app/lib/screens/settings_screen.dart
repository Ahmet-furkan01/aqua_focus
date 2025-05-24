import 'package:flutter/material.dart';
import '../widgets/ocean_background.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/audio_service.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoResumeTimer = false;
  bool _sound = false;
  bool _notifications = true;
  int _focusLength = 25;
  int _pomodorosUntilLongBreak = 4;
  int _shortBreakLength = 5;
  int _longBreakLength = 15;
  final int _selectedIndex = 4;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _autoResumeTimer = prefs.getBool('auto_resume_timer') ?? false;
      _notifications = prefs.getBool('notifications') ?? false;
      _focusLength = prefs.getInt('focus_length') ?? 25;
      _pomodorosUntilLongBreak =
          prefs.getInt('pomodoros_until_long_break') ?? 4;
      _shortBreakLength = prefs.getInt('short_break_length') ?? 5;
      _longBreakLength = prefs.getInt('long_break_length') ?? 15;
    });

    // Load sound setting from AudioService
    final audioService = Provider.of<AudioService>(context, listen: false);
    setState(() {
      _sound = audioService.isSoundEnabled;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('auto_resume_timer', _autoResumeTimer);
    await prefs.setBool('notifications', _notifications);
    await prefs.setInt('focus_length', _focusLength);
    await prefs.setInt('pomodoros_until_long_break', _pomodorosUntilLongBreak);
    await prefs.setInt('short_break_length', _shortBreakLength);
    await prefs.setInt('long_break_length', _longBreakLength);
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.white,
                      onPressed: () {
                        _saveSettings();
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView(
                    children: [
                      _buildSection(
                        'Timer Settings',
                        [
                          _buildNumberSetting(
                            'Focus length',
                            _focusLength,
                            (value) {
                              setState(() => _focusLength = value);
                              _saveSettings();
                            },
                            minValue: 1,
                            maxValue: 60,
                            suffix: 'min',
                          ),
                          _buildNumberSetting(
                            'Short break length',
                            _shortBreakLength,
                            (value) {
                              setState(() => _shortBreakLength = value);
                              _saveSettings();
                            },
                            minValue: 1,
                            maxValue: 30,
                            suffix: 'min',
                          ),
                          _buildNumberSetting(
                            'Long break length',
                            _longBreakLength,
                            (value) {
                              setState(() => _longBreakLength = value);
                              _saveSettings();
                            },
                            minValue: 5,
                            maxValue: 45,
                            suffix: 'min',
                          ),
                          _buildNumberSetting(
                            'Pomodoros until long break',
                            _pomodorosUntilLongBreak,
                            (value) {
                              setState(() => _pomodorosUntilLongBreak = value);
                              _saveSettings();
                            },
                            minValue: 2,
                            maxValue: 8,
                            suffix: 'sessions',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        'App Settings',
                        [

                          _buildSwitchSetting(
                            'Auto resume timer',
                            _autoResumeTimer,
                            (value) async {
                              setState(() => _autoResumeTimer = value);
                              await _saveSettings();
                            },
                            icon: Icons.timer,
                          ),
                          _buildSwitchSetting(
                            'Sound',
                            _sound,
                            (value) async {
                              setState(() => _sound = value);
                              await audioService.toggleSound(value);
                            },
                            icon: Icons.volume_up,
                          ),
                          _buildSwitchSetting(
                            'Notifications',
                            _notifications,
                            (value) async {
                              setState(() => _notifications = value);
                              await _saveSettings();
                            },
                            icon: Icons.notifications,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BottomNavBar(selectedIndex: _selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF5ECEDB),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildSwitchSetting(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 10),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF5ECEDB),
            activeTrackColor: const Color(0xFF5ECEDB).withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.9),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberSetting(
    String title,
    int value,
    ValueChanged<int> onChanged, {
    required int minValue,
    required int maxValue,
    required String suffix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              Text(
                '$value $suffix',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
