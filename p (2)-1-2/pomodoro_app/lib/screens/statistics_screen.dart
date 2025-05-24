import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/ocean_background.dart';
import '../widgets/bottom_nav_bar.dart';
import 'morestats_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  static const int _selectedIndex = 3; // Alt navigasyonda Statistics sekmesi

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  // API'den gelecek alanlar
  String todayFocusTime = "Loading...";
  String completedPomodoros = "Loading...";
  String focusRate = "Loading...";
  String studyReport = "Loading study report...";
  String avgSessionDuration = "Loading...";
  String avgBreakDuration = "Loading...";
  String avgProductivityScore = "Loading...";
  String avgFocusLevel = "Loading...";
  String totalTasksCompleted = "Loading...";

  Map<String, double> weeklyProgress = {
    "M": 0.0,
    "T": 0.0,
    "W": 0.0,
    "T2": 0.0,
    "F": 0.0,
    "S": 0.0,
    "S2": 0.0,
  };

  bool isLoading = true;
  String errorMessage = "";
  String? _userId;

  DateTime _lastUpdated = DateTime.now();

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserIdAndFetch();

    // Auto-refresh every 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('user_id');
    if (storedId == null) {
      setState(() {
        errorMessage = "User info not found. Please log in again.";
        isLoading = false;
      });
      return;
    }
    _userId = storedId;
    await fetchStatistics();
  }

  Future<void> fetchStatistics() async {
    if (_userId == null) return;
    setState(() => isLoading = true);

    final uri = Uri.parse(
        "http://fastapi-aquafocus.onrender.com/stats?user_id=$_userId");
    try {
      final resp = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      });
      if (resp.statusCode != 200) {
        throw Exception(
            "Server error! Please complete more Pomodoro sessions: ${resp.statusCode}");
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;

      setState(() {
        todayFocusTime = data['today_focus_time'] ?? "N/A";
        completedPomodoros = (data['completed_pomodoros'] ?? 0).toString();
        focusRate = data['focus_rate'] ?? "N/A";
        studyReport = (data['study_report'] as List<dynamic>).join("\n• ");
        avgSessionDuration = "${data['avg_session_duration']} min";
        avgBreakDuration = "${data['avg_break_duration']} min";
        avgProductivityScore = data['avg_productivity_score'].toString();
        avgFocusLevel = "${data['avg_focus_level']} / 10";
        totalTasksCompleted = data['total_tasks_completed'].toString();
        weeklyProgress = Map<String, double>.from(
          (data['weekly_progress'] as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        );
        _lastUpdated = DateTime.now();
        errorMessage = "";
      });

      _animationController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _refreshData() => fetchStatistics();

  void _openMore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MoreStatsScreen()),
    );
  }

  void _shareStatistics() async {
    final statsText = """
AquaFocus Statistics:
- Today's Focus Time: $todayFocusTime
- Completed Pomodoros: $completedPomodoros
- Focus Rate: $focusRate
- Avg Session Duration: $avgSessionDuration
- Avg Break Duration: $avgBreakDuration
- Avg Productivity Score: $avgProductivityScore
- Avg Focus Level: $avgFocusLevel
- Total Tasks Completed: $totalTasksCompleted
    """;

    await Share.share(statsText, subject: 'My AquaFocus Statistics');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Column(
            children: [
              // AppBar-like section
              _buildAppBar(),

              if (errorMessage.isNotEmpty) _buildErrorMessage(),

              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLastUpdatedInfo(),

                              // Main stats grid
                              _buildMainStatsGrid(),

                              const Divider(color: Colors.white30, height: 40),

                              // Secondary stats
                              _buildSecondaryStats(),

                              const SizedBox(height: 24),

                              // Weekly progress chart
                              _buildWeeklyProgressSection(),

                              const SizedBox(height: 24),

                              // Personalized report
                              _buildStudyReportSection(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
              ),

              BottomNavBar(selectedIndex: StatisticsScreen._selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Statistics',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF64C8FF)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedInfo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.update, size: 14, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(
            'Last updated: ${_lastUpdated.hour}:${_lastUpdated.minute.toString().padLeft(2, '0')}',
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildAnimatedStatCard(
          title: "Today's Focus Time",
          value: todayFocusTime,
          subtitle: "Time spent focusing today",
          icon: Icons.access_time,
        ),
        _buildAnimatedStatCard(
          title: 'Total Pomodoros',
          value: completedPomodoros,
          subtitle: "Sessions completed",
          icon: Icons.check_circle_outline,
        ),
        _buildAnimatedStatCard(
          title: 'Focus Rate',
          value: focusRate,
          subtitle: "Focus percentage",
          icon: Icons.show_chart,
        ),
        _buildAnimatedStatCard(
          title: 'Tasks Completed',
          value: totalTasksCompleted,
          subtitle: "All time",
          icon: Icons.task_alt,
        ),
      ],
    );
  }

  Widget _buildSecondaryStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                title: 'Avg Session',
                value: avgSessionDuration,
                icon: Icons.timer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricItem(
                title: 'Avg Break',
                value: avgBreakDuration,
                icon: Icons.coffee,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                title: 'Productivity Score',
                value: avgProductivityScore,
                icon: Icons.stars,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricItem(
                title: 'Focus Level',
                value: avgFocusLevel,
                icon: Icons.psychology,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFDCFAFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, color: const Color(0xFF64C8FF), size: 18),
                ],
              ),
              const Spacer(),
              Text(
                value != "Loading..." ? value : "-",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: value.length > 6 ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64C8FF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildBarChart(),
        ),
        TextButton.icon(
          onPressed: _openMore,
          icon: const Icon(Icons.insert_chart, color: Color(0xFF64C8FF)),
          label: const Text(
            'View Detailed Charts',
            style: TextStyle(color: Color(0xFF64C8FF)),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final barGroups = weeklyProgress.entries.map((entry) {
      final value = entry.value.clamp(0.0, 1.0);
      return BarChartGroupData(
        x: _getDayIndex(entry.key),
        barRods: [
          BarChartRodData(
            toY: value * 100,
            color: const Color(0xFF64C8FF),
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // Her değeri göstermek için 1 kullanın
              getTitlesWidget: (value, meta) {
                return Text(
                  _getDayName(value.toInt()),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25, // Her 25 değerinde bir başlık göster
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 50 || value == 100) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 10),
                  );
                }
                return Container(); // Boş widget döndürün
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        maxY: 100,
      ),
      swapAnimationDuration: const Duration(milliseconds: 500),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  int _getDayIndex(String day) {
    final dayMap = {'M': 0, 'T': 1, 'W': 2, 'T2': 3, 'F': 4, 'S': 5, 'S2': 6};
    return dayMap[day] ?? 0;
  }

  String _getDayName(int index) {
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return dayNames[index % dayNames.length];
  }

  Widget _buildStudyReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalized Study Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF64C8FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Color(0xFFFFC764), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Insights',
                    style: TextStyle(
                      color: Color(0xFFFFC764),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                studyReport,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
