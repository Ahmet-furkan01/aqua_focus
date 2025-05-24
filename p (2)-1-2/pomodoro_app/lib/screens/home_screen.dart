import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../widgets/bottom_nav_bar.dart';
import 'statistics_screen.dart' as stats;
import 'settings_screen.dart' as settings;
import 'tasks_screen.dart';
import 'home_page.dart';
import 'teams_screen.dart';
import 'package:http/http.dart' as http;
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String? userId;

  const HomeScreen({
    super.key,
    this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRunning = false;
  int _timeLeft = 25 * 60;
  Timer? _timer;
  int _currentRound = 2;
  int _totalRounds = 4;
  int _completedGoals = 1;
  int _totalGoals = 12;
  int _selectedIndex = 2;
  late SocketService socketService;
  bool _isConnected = false;
  String _connectionStatus = 'Initializing...';
  String? _currentReefId;
  Map<String, dynamic>? _userData;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;
  Timer? _reconnectTimer;
  List<Action> _actions = [];
  Map<String, dynamic>? _aiInsights;
  List<dynamic> _teamMembers = [];
  String? userId;
  String? username;
  String? aiExplanation;
  String? _currentReefName;
  final int _workDuration = 25; // 25 minutes
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _isLoading = true;
        _connectionStatus = 'Initializing...';
      });

      // Önce SharedPreferences'tan kullanıcı verisini al
      final storedUserId = await UserService.getUserId();
      final storedUsername = await UserService.getUserName();

      if (storedUserId == null || storedUserId.isEmpty) {
        print('No stored userId found');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Stored verileri kullan
      setState(() {
        userId = storedUserId;
        username = storedUsername;
        _connectionStatus = 'Connecting...';
      });

      // Socket servisini başlat
      socketService = SocketService();
      await socketService.initialize();
      _setupSocketListeners();

      // API'den güncel veriyi al
      print('Fetching user data for userId: $storedUserId');
      final userData = await _userService.getUserData(storedUserId);

      if (userData != null && mounted) {
        setState(() {
          userId = userData['userId'];
          username = userData['username'];
          _currentReefId = userData['reefId'] ?? 'default_reef';
          _isLoading = false;
        });

        print('User data initialized successfully:');
        print('userId: $userId');
        print('username: $username');
        print('reefId: $_currentReefId');
      }
    } catch (e) {
      print('Error in _initializeApp: $e');
      _handleConnectionError();
    }
  }

  void _handleConnectionError() {
    if (!mounted) return;

    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _reconnectAttempts++;

      setState(() {
        _isConnected = false;
        _isReconnecting = true;
      });

      // Önceki zamanlayıcıyı iptal et
      _reconnectTimer?.cancel();

      // Yeni bir yeniden bağlanma denemesi planla
      _reconnectTimer =
          Timer(Duration(seconds: _reconnectAttempts * 2), () async {
        if (mounted && !_isConnected) {
          print('Attempting reconnect #$_reconnectAttempts');
          await socketService.reconnect();
        }
      });
    } else {
      setState(() {
        _isConnected = false;
        _isReconnecting = false;
      });
    }
  }

  void _setupSocketListeners() {
    if (socketService.socket != null) {
      print('Setting up socket listeners...');

      // Mevcut dinleyicileri temizle
      socketService.socket!.off('connect');
      socketService.socket!.off('disconnect');
      socketService.socket!.off('connect_error');
      socketService.socket!.off('startPomodoro');
      socketService.socket!.off('endPomodoro');

      socketService.socket!.onConnect((_) {
        print('Socket Connected Successfully');
        if (mounted) {
          setState(() {
            _isConnected = true;
            _isReconnecting = false;
            _reconnectAttempts = 0;
          });
        }
      });

      socketService.socket!.onDisconnect((_) {
        print('Socket Disconnected');
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
          if (!_isReconnecting) {
            _handleConnectionError();
          }
        }
      });

      socketService.socket!.onConnectError((error) {
        print('Socket Connection Error: $error');
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
          if (!_isReconnecting) {
            _handleConnectionError();
          }
        }
      });

      // Pomodoro event listeners
      socketService.socket!.on('startPomodoro', (data) {
        print('Start pomodoro received: $data');
        if (mounted && data['reefId'] == _currentReefId) {
          _toggleTimer();
        }
      });

      socketService.socket!.on('endPomodoro', (data) {
        print('End pomodoro received: $data');
        if (mounted && data['reefId'] == _currentReefId) {
          _resetTimer();
        }
      });

      // Bağlantı durumunu hemen kontrol et
      if (socketService.isConnected) {
        print('Socket is already connected');
        setState(() {
          _isConnected = true;
          _isReconnecting = false;
          _reconnectAttempts = 0;
        });
      }
    }
  }

  void _toggleTimer() {
    if (!_isRunning) {
      print('Starting timer...');
      setState(() {
        _isRunning = true;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          print('Timer tick: $_timeLeft seconds left');
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              print('Timer completed!');
              _timer?.cancel();
              _isRunning = false;
              _showCompletionDialog();
            }
          });
        }
      });

      print('Emitting socket event...');
      // Emit start event using SocketService
      if (userId != null && username != null && _currentReefId != null) {
        socketService.startPomodoro(
          userId!,
          username!,
          _currentReefId!,
          aiExplanation ?? '',
        );
        print('Socket event emitted successfully');
      } else {
        print('Cannot emit socket event: missing user data');
        print('userId: $userId');
        print('username: $username');
        print('reefId: $_currentReefId');
      }
    } else {
      print('Timer is already running');
    }
  }

  void _addTime(int minutes) {
    setState(() {
      _timeLeft += minutes * 60;
      if (userId != null && username != null && _currentReefId != null) {
        socketService.addTime(
          userId!,
          username!,
          _currentReefId!,
          aiExplanation ?? '',
          minutes,
        );
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _timeLeft = _workDuration * 60;
      _isRunning = false;
      _timer?.cancel();
      if (userId != null && username != null && _currentReefId != null) {
        socketService.resetTimer(
          userId!,
          username!,
          _currentReefId!,
          aiExplanation ?? '',
        );
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFDCFAFF), fontSize: 14),
      ),
    );
  }

  void _onNavItemTapped(int index, BuildContext context) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomePage(userId: userId ?? '')));
        break;
      case 1:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const TasksScreen()));
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const stats.StatisticsScreen()));
        break;
      case 4:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const settings.SettingsScreen()));
        break;
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    socketService.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showResetConfirmationDialog() {
    bool wasRunning = _isRunning;
    if (_isRunning) {
      _toggleTimer();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF06555E),
          title: const Text(
            'Are you sure?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will reset the timer to 25 minutes.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (wasRunning) {
                  _toggleTimer();
                }
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetTimer();
              },
              child: const Text(
                "I'm sure",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchActions() async {
    try {
      print('Fetching actions from server...');
      final response = await http.get(
        Uri.parse('server.yagiz.tc:666/actions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _actions = data.map((item) => Action.fromJson(item)).toList();
        });
      } else {
        print('Failed to fetch actions. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to fetch actions: ${response.body}');
      }
    } catch (e) {
      print('Error fetching actions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching actions: $e')),
        );
      }
    }
  }

  Future<void> _syncAction(Action action) async {
    try {
      print('Syncing action to server: ${action.toJson()}');
      final response = await http.post(
        Uri.parse('http://server.yagiz.tc:666/actions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(action.toJson()),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Action synced successfully');
      } else {
        print('Failed to sync action. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to sync action: ${response.body}');
      }
    } catch (e) {
      print('Error syncing action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing action: $e')),
        );
      }
    }
  }

  void _joinReef() {
    if (_currentReefId != null && userId != null && username != null) {
      socketService.joinReef(
        userId: userId!,
        username: username!,
        reefId: _currentReefId!,
        reefName: _currentReefName ?? 'My Reef',
        aiExplanation: aiExplanation,
      );
    }
  }

  Future<void> _saveCompletedPomodoro({int? actualDuration}) async {
    try {
      // First check if we can get the user ID from SharedPreferences
      final storedUserId = await UserService.getUserId();

      if (storedUserId == null || storedUserId.isEmpty) {
        print('No stored userId found in SharedPreferences');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has ended. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Calculate actual duration in minutes
      final completedDuration = actualDuration ?? _workDuration;

      print('Attempting to save pomodoro for user: $storedUserId');
      print('Duration: $completedDuration minutes');
      print('Completed at: ${DateTime.now()}');

      final result = await _apiService.completeUserPomodoro(
        userId: storedUserId,
        duration: completedDuration,
        completedAt: DateTime.now(),
        type: 'focus',
        status: completedDuration >= 25 ? 'completed' : 'incomplete',
      );

      print('Pomodoro completion API response: $result');

      if (result != null && mounted) {
        final username = await UserService.getUserName() ?? 'User';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🌊$username completed a $completedDuration minute pomodoro! 🎉'),
            backgroundColor: Colors.green,
          ),
        );

        // Show survey dialog with session_id
        final sessionId = result['session_id'];
        _showSurveyDialog(storedUserId, sessionId);
      }
    } catch (e) {
      print('Error saving completed pomodoro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pomodoro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSurveyDialog(String userId, String sessionId) {
    int productivityScore = 3;
    int focusLevel = 3;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF06555E),
              title: const Text(
                'Session Survey',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How productive were you during this session?',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            productivityScore = index + 1;
                          });
                        },
                        child: Icon(
                          Icons.star_rounded,
                          color: index < productivityScore
                              ? Colors.amber.shade700
                              : Colors.grey.shade300,
                          size: 40,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'How focused did you feel?',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            focusLevel = index + 1;
                          });
                        },
                        child: Icon(
                          Icons.star_rounded,
                          color: index < focusLevel
                              ? Colors.amber.shade700
                              : Colors.grey.shade300,
                          size: 40,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      // Map star values to database values
                      int mappedProductivityScore =
                          [0, 20, 40, 60, 80, 100][productivityScore];
                      int mappedFocusLevel = [0, 2, 4, 6, 8, 10][focusLevel];
                      // Send survey results to the correct endpoint with session_id
                      await _apiService.submitPomodoroSurvey(
                        sessionId: sessionId,
                        productivityScore: mappedProductivityScore,
                        focusLevel: mappedFocusLevel,
                      );
                      Navigator.of(context).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your feedback has been saved!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not save feedback: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pomodoro Completed! 🎉'),
        content: const Text('Great job! Take a short break.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveCompletedPomodoro();
              setState(() {
                _timeLeft = _workDuration * 60;
                _currentRound++;
                _completedGoals++;
              });
            },
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  void _showStopConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF06555E),
          title: const Text(
            'Do you want to stop the pomodoro?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This action will end the current pomodoro session.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                _timer?.cancel();
                // Calculate actual completed duration in minutes
                final completedMinutes =
                    ((_workDuration * 60 - _timeLeft) ~/ 60)
                        .clamp(1, _workDuration);
                await _saveCompletedPomodoro(actualDuration: completedMinutes);
                setState(() {
                  _isRunning = false;
                  _timeLeft = _workDuration * 60;
                });
              },
              child: const Text(
                'Stop',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF06555E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.28, 0.55, 1.0],
            colors: [Color(0xFF06555E), Color(0xFF298690), Color(0xFF5ECEDB)],
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeButton('+5 Minute', () => _addTime(5)),
                      const SizedBox(width: 10),
                      _buildTimeButton('+10 Minute', () => _addTime(10)),
                      const SizedBox(width: 10),
                      _buildTimeButton('+15 Minute', () => _addTime(15)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CircularProgressIndicator(
                          value: 1 - (_timeLeft / (25 * 60)),
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF64C8FF)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_timeLeft),
                            style: const TextStyle(
                              color: Color(0xFFDCFAFF),
                              fontSize: 72,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_timeLeft ~/ 60).toString()} minutes left',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                            height: 2, color: Colors.white.withOpacity(0.1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            31,
                            (index) => Container(
                              width: 2,
                              height: index % 5 == 0 ? 12 : 6,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                        Positioned(
                            left: 0,
                            child: Text('20',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12))),
                        Positioned(
                            child: Text('25',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12))),
                        Positioned(
                            right: 0,
                            child: Text('30',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.refresh,
                              color: Colors.white.withOpacity(0.7), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Round $_currentRound/$_totalRounds',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.flag,
                              color: Colors.white.withOpacity(0.7), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_completedGoals/$_totalGoals Goal',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isRunning ? Colors.grey : Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: _isRunning ? null : _toggleTimer,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed:
                            _isRunning ? _showStopConfirmationDialog : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 30,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Stop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamsScreen(
                                  userId: userId,
                                  username: username,
                                  aiExplanation: aiExplanation,
                                ),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '"Do not take life too seriously. You will never get out of it alive"',
                          style: TextStyle(
                            color: Color(0xFFDCFAFF),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— Elbert Hubbard',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BottomNavBar(
                    selectedIndex: _selectedIndex,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Action {
  final String id;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  Action({
    required this.id,
    required this.type,
    required this.timestamp,
    this.data,
  });

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      id: json['id'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }
}
