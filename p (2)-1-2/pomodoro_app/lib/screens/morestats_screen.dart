import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'statistics_screen.dart';
import '../widgets/ocean_background.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dart:convert'; // for jsonDecode
import 'package:http/http.dart' as http; // for API requests
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/socket_service.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class MoreStatsScreen extends StatefulWidget {
  const MoreStatsScreen({super.key});

  static const int _selectedIndex = 3;

  @override
  State<MoreStatsScreen> createState() => _MoreStatsScreenState();
}

bool isWeekly = false;

class _MoreStatsScreenState extends State<MoreStatsScreen> {
  late IO.Socket socket;
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _weeklyStats = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetch();
    _initializeSocket();
  }

  Future<void> _loadUserIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      await _fetchStats();
    }
  }

  void _initializeSocket() {
    socket = IO.io('ws://server.yagiz.tc:666', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 3,
      'reconnectionDelay': 2000,
      'forceNew': true,
    });

    socket.onConnect((_) {
      print('MoreStats Screen - Socket Connected');
    });

    socket.on('pomodoroCompleted', (data) async {
      if (data['user_id'] == _userId) {
        print('Pomodoro completed, updating stats...');
        await _fetchStats();
      }
    });

    socket.onDisconnect((_) {
      print('MoreStats Screen - Socket Disconnected');
    });

    socket.connect();
  }

  Future<void> _fetchStats() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3306/api/stats/$_userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          _dailyStats = List<Map<String, dynamic>>.from(json['daily']);
          _weeklyStats = List<Map<String, dynamic>>.from(json['weekly']);
          _isLoading = false;
        });
      } else {
        print('Failed to load stats: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: OceanBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: ListView(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                color: Colors.white,
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Text(
                                'Detailed Statistics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isWeekly = false;
                                });
                              },
                              child: Text("Day",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isWeekly
                                    ? Color(0xFF04363C)
                                    : Color(0xFF298690),
                              ),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isWeekly = true;
                                });
                              },
                              child: Text("Week",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isWeekly
                                    ? Color(0xFF298690)
                                    : Color(0xFF04363C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Focus Hours",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        _buildSessionChart1(),
                        _buildSessionChart2(),
                      ],
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: const BottomNavBar(
                    selectedIndex: MoreStatsScreen._selectedIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionChart1() {
    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          child: Stack(
            children: [
              BarChart(BarChartData(
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      // Cast to int and check if the value is less than 2
                      int barValue = rod.toY <= 2 ? 0 : rod.toY.toInt();

                      String tooltipText =
                          '$barValue Minutes'; // Use the adjusted bar value

                      // If it's not the weekly version (i.e., daily), add the time of day
                      if (!isWeekly) {
                        tooltipText =
                            '$barValue Minutes \n ${_getTimeOfDay(group.x.toDouble())}-${_getTimeOfDay(group.x + 1.toDouble())}';
                      }

                      return BarTooltipItem(
                        tooltipText,
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                maxY: isWeekly ? 600 : 120,
                barGroups: _getBarGroups(isWeekly),
                backgroundColor: Colors.white.withOpacity(0.1),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (isWeekly) {
                          const days = [
                            "Mon",
                            "Tue",
                            "Wed",
                            "Thu",
                            "Fri",
                            "Sat",
                            "Sun"
                          ];
                          int index = value.toInt() - 1;
                          if (index >= 0 && index < days.length) {
                            return Text(
                              days[index],
                              style: const TextStyle(color: Colors.white),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        } else {
                          int hour = (value.toInt() - 1) * 2;
                          if (hour % 6 == 0 && hour <= 22) {
                            return Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(color: Colors.white),
                            );
                          } else if (hour == 22) {
                            return Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(color: Colors.white),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value % 20 == 0 && value != 120 && value != 600) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(color: Colors.white),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (value) {
                    if (value % 20 == 0 && value != 120 && value != 600) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.2),
                        strokeWidth: 1,
                        dashArray: [5, 5], // Optional: dashed lines
                      );
                    }
                    return FlLine(strokeWidth: 0); // Hide other lines
                  },
                  drawVerticalLine: false, // Optional: only horizontal lines
                ),
              )),
              Positioned(
                top: 10,
                left: 50,
                child: Text(
                  'Total Time: ${(_getTotalTime(isWeekly) / 60).toInt()} Hours ${_getTotalTime(isWeekly) % 60} minutes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionChart2() {
    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Sessions Completed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      minY: 0,
                      maxY: isWeekly ? 70 : 12,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toInt()} ${spot.y.toInt() == 1 ? 'Session' : 'Sessions'}${!isWeekly ? '\n ${_getTimeOfDay(spot.x)}-${_getTimeOfDay(spot.x + 1)}' : ''}',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getSessionLineData(isWeekly),
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: Colors.blue,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, lineChartBarData) {
                              // Only show dot if the current spot has the maximum Y value
                              double maxY = _getSessionLineData(isWeekly)
                                  .map((spot) => spot.y)
                                  .reduce((a, b) => a > b ? a : b);
                              return spot.y == maxY;
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (!isWeekly) {
                                int hour = (value.toInt() - 1) * 2;
                                if (hour % 6 == 0 && hour <= 22) {
                                  return Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(color: Colors.white),
                                  );
                                } else if (hour == 22) {
                                  return Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(color: Colors.white),
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              } else {
                                const days = [
                                  "Mon",
                                  "Tue",
                                  "Wed",
                                  "Thu",
                                  "Fri",
                                  "Sat",
                                  "Sun"
                                ];
                                int index = value.toInt() - 1;
                                if (index >= 0 && index < days.length) {
                                  return Text(
                                    days[index],
                                    style: const TextStyle(color: Colors.white),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value % 2 == 0 &&
                                  value != 12 &&
                                  value != 70) {
                                return Text('${value.toInt()}',
                                    style:
                                        const TextStyle(color: Colors.white));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (value) {
                          if (isWeekly) {
                            if (value % 10 == 0) {
                              return FlLine(
                                color: Colors.white.withOpacity(0.2),
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              );
                            }
                          } else if (!isWeekly) {
                            if (value % 2 == 0) {
                              return FlLine(
                                color: Colors.white.withOpacity(0.2),
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              );
                            }
                          }

                          return FlLine(strokeWidth: 0);
                        },
                        drawVerticalLine: false,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 50,
                    child: Text(
                      'Most Sessions Completed ${isWeekly ? "on" : "at"}: ${_getMostCompletedSessionLabel(isWeekly)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups(bool isWeekly) {
    if (isWeekly) {
      // Weekly stats için mevcut kod aynı kalacak
      List<double> minutesPerDay = List.filled(7, 0);
      for (var entry in _weeklyStats) {
        int? day = entry['day'];
        double minutes = (entry['total_minutes'] ?? 0).toDouble();
        if (day != null && day >= 1 && day <= 7) {
          minutesPerDay[day - 1] = minutes;
        }
      }

      return List.generate(7, (i) {
        return BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: minutesPerDay[i],
              color: Colors.blue,
              width: 16,
            ),
          ],
        );
      });
    } else {
      // Daily stats için yeni kod
      List<double> minutesPerBlock = List.filled(12, 0);

      // Daily stats'ten gelen verileri bloklara dağıt
      for (var entry in _dailyStats) {
        int? block = entry['block'];
        double minutes = (entry['total_minutes'] ?? 0).toDouble();
        if (block != null && block >= 0 && block < 12) {
          minutesPerBlock[block] = minutes;
        }
      }

      return List.generate(12, (i) {
        return BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: minutesPerBlock[i],
              color: Colors.blue,
              width: 16,
            ),
          ],
        );
      });
    }
  }

  List<FlSpot> _getSessionLineData(bool isWeekly) {
    if (isWeekly) {
      // Weekly stats için mevcut kod aynı kalacak
      List<double> sessionCounts = List.filled(7, 0);
      for (var entry in _weeklyStats) {
        int? day = entry['day'];
        double count = (entry['session_count'] ?? 0).toDouble();
        if (day != null && day >= 1 && day <= 7) {
          sessionCounts[day - 1] = count;
        }
      }

      return List.generate(
          7, (i) => FlSpot((i + 1).toDouble(), sessionCounts[i]));
    } else {
      // Daily stats için yeni kod
      List<double> sessionCounts = List.filled(12, 0);

      // Daily stats'ten gelen verileri bloklara dağıt
      for (var entry in _dailyStats) {
        int? block = entry['block'];
        double count = (entry['session_count'] ?? 0).toDouble();
        if (block != null && block >= 0 && block < 12) {
          sessionCounts[block] = count;
        }
      }

      return List.generate(
          12, (i) => FlSpot((i + 1).toDouble(), sessionCounts[i]));
    }
  }

  String _getTimeOfDay(double blockNumber) {
    int hour = ((blockNumber - 1) * 2).toInt();
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  int _getTotalTime(bool isWeekly) {
    if (isWeekly) {
      return _weeklyStats.fold<int>(
          0, (sum, entry) => sum + ((entry['total_minutes'] ?? 0) as int));
    } else {
      return _dailyStats.fold<int>(
          0, (sum, entry) => sum + ((entry['total_minutes'] ?? 0) as int));
    }
  }

  String _getMostCompletedSessionLabel(bool isWeekly) {
    List<FlSpot> data = _getSessionLineData(isWeekly);
    if (data.isEmpty) return "No data available";

    FlSpot max = data.reduce((a, b) => a.y > b.y ? a : b);
    int index = max.x.toInt();

    if (isWeekly) {
      List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      index = index.clamp(1, 7) - 1;
      return "${days[index]} - ${max.y.toInt()} sessions";
    } else {
      index = index.clamp(1, 12);
      int hour = (index - 1) * 2;
      return "${hour.toString().padLeft(2, '0')}:00 - ${max.y.toInt()} sessions";
    }
  }
}
