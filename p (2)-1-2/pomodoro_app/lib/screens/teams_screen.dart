import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../widgets/bottom_nav_bar.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import 'team_screen.dart';
import 'team_pomodoro_screen.dart';
import '../services/api_service.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/team_members.dart';

class TeamsScreen extends StatefulWidget {
  final String? userId;
  final String? username;
  final String? aiExplanation;

  const TeamsScreen({
    super.key,
    this.userId,
    this.username,
    this.aiExplanation,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  int _selectedIndex = 0;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  bool _isReconnecting = false;
  List<dynamic> _teamMembers = [];
  String? _currentReefId;
  String? _currentReefName;
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _aiInsights = {};
  late IO.Socket socket;
  Timer? _timer;
  bool _isRunning = false;
  int _timeLeft = 25 * 60;
  int _currentRound = 1;
  int _completedGoals = 0;
  int _totalRounds = 4;
  int _totalGoals = 5;
  List<Map<String, dynamic>> _teams = [];
  String? _currentUserId;
  String? _currentUserName;
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  // User information
  String? userId;
  String? username;
  String? aiExplanation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      userId = widget.userId;
      username = widget.username;
      aiExplanation = widget.aiExplanation;

      if (userId != null && username != null) {
        _connectWebSocket();
      } else {
        // Redirect to login if user data is not available
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    if (userId == null || username == null) return;

    try {
      print('Attempting to connect to WebSocket...');
      setState(() {
        _connectionStatus = 'Connecting...';
      });

      socket = IO.io('ws://server.yagiz.tc:666', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 3,
        'reconnectionDelay': 2000,
        'forceNew': true,
        'path': '/socket.io/',
        'timeout': 10000,
        'pingTimeout': 20000,
        'pingInterval': 10000,
        'query': {'EIO': '4', 'transport': 'websocket'}
      });

      socket.connect();

      // Pomodoro events
      socket.on('pomodoroStarted', (data) {
        print('pomodoroStarted: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _isRunning = true;
            _timeLeft = 25 * 60;
          });
        }
      });

      socket.on('pomodoroEnded', (data) {
        print('pomodoroEnded: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _isRunning = false;
            _timeLeft = 25 * 60;
          });
        }
      });

      socket.on('timerStarted', (data) {
        print('timerStarted: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _isRunning = true;
            _timeLeft = 25 * 60;
          });
        }
      });

      socket.on('timerPaused', (data) {
        print('timerPaused: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _isRunning = false;
          });
        }
      });

      socket.on('timerReset', (data) {
        print('timerReset: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _isRunning = false;
            _timeLeft = 25 * 60;
          });
        }
      });

      socket.on('timeAdded', (data) {
        print('timeAdded: $data');
        if (data['reefId'] == _currentReefId && data['userId'] == userId) {
          setState(() {
            _timeLeft += (data['minutes'] as int) * 60;
          });
        }
      });

      socket.onConnect((_) {
        print('Socket.IO Connected Successfully');
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected';
        });

        if (_currentReefId != null) {
          socket.emit('reconnectRequest', {
            'userId': userId,
            'username': username,
            'reefId': _currentReefId,
            'aiExplanation': aiExplanation
          });
        }
      });

      socket.onConnecting((_) {
        print('Socket.IO Connecting...');
        setState(() {
          _connectionStatus = 'Connecting...';
        });
      });

      socket.onConnectError((error) {
        print('Socket.IO Connection Error: $error');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Connection Error: $error';
        });
        _attemptReconnect();
      });

      socket.onError((error) {
        print('Socket.IO Error: $error');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Error: $error';
        });
        _attemptReconnect();
      });

      socket.onDisconnect((_) {
        print('Socket.IO Disconnected');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Disconnected';
        });
        _attemptReconnect();
      });

      socket.on('reconnectRequest', (data) {
        print('Reconnect request received: $data');
        setState(() {
          _connectionStatus = 'Reconnecting...';
        });
        if (data['reefId'] != null) {
          _currentReefId = data['reefId'];
          socket.emit('reefRestored',
              {'reefId': _currentReefId, 'timestamp': DateTime.now()});
        }
      });

      socket.on('reconnect', (attemptNumber) {
        print('Reconnected after $attemptNumber attempts');
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Reconnected';
        });
      });

      socket.on('reconnect_error', (error) {
        print('Reconnection error: $error');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Reconnection Failed: $error';
        });
      });

      socket.on('reconnect_failed', (dynamic data) {
        print('Reconnection failed');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Reconnection Failed';
        });
      });

      socket.on('joinReef', (data) {
        print('Join reef received: $data');
        if (data['reefId'] != null && data['userData'] != null) {
          setState(() {
            _currentReefId = data['reefId'];
            _userData = data['userData'];
            _teamMembers = [
              ..._teamMembers,
              {
                'username': data['userData']['username'],
                'isActive': true,
                'timeLeft': 25 * 60
              }
            ];
          });
        }
      });

      socket.on('startPomodoro', (data) {
        print('Start pomodoro received: $data');
        if (data['userId'] == userId) {
          _toggleTimer(); // sadece kendine aitse başlat
        }
      });

      socket.on('endPomodoro', (data) {
        print('End pomodoro received: $data');
        if (data['userId'] == userId) {
          _resetTimer();
        }
        // Show notification for any user's endPomodoro
        if (mounted && data['username'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ 🌊 ${data['username']}\'s focus is powering the reef!'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });

      socket.on('requestAIInsights', (data) {
        print('AI insights request received: $data');
        if (data['reefId'] == _currentReefId) {
          socket.emit('aiInsights', {
            'reefId': _currentReefId,
            'insights': {
              'timeLeft': _timeLeft,
              'round': _currentRound,
              'goals': _completedGoals,
              'timestamp': DateTime.now()
            }
          });
        }
      });

      socket.on('reefRestored', (data) {
        print('Reef restored: $data');
        if (data['reefId'] != null) {
          setState(() {
            _currentReefId = data['reefId'];
            _connectionStatus = 'Reef Restored';
          });
        }
      });

      socket.on('reefUpdated', (data) {
        print('Reef updated: $data');
        if (data['reefId'] == _currentReefId) {
          setState(() {
            if (data['teamMembers'] != null) {
              _teamMembers =
                  List<Map<String, dynamic>>.from(data['teamMembers']);
            }
            if (data['status'] != null) {
              _connectionStatus = data['status'];
            }
          });
        }
      });

      socket.on('aiInsights', (data) {
        print('AI insights received: $data');
        if (data['reefId'] == _currentReefId) {
          setState(() {
            _aiInsights = data['insights'];
          });
        }
      });
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Connection Error: $e';
      });
      _attemptReconnect();
    }
  }

  void _tryNonSecureConnection() {
    try {
      print('Attempting non-secure connection...');
      socket = IO.io('ws://server.yagiz.tc:666', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 3,
        'reconnectionDelay': 2000,
        'reconnectionDelayMax': 5000,
        'forceNew': true,
        'path': '/socket.io/',
        'timeout': 10000,
        'pingTimeout': 20000,
        'pingInterval': 10000,
        'query': {'platform': 'flutter', 'version': '1.0.0'}
      });

      socket.connect();

      socket.onConnect((_) {
        print('Socket.IO Connected Successfully (Non-secure)');
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected to Server (Non-secure)';
        });
      });

      socket.onConnectError((error) {
        print('Socket.IO Non-secure Connection Error: $error');
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Non-secure Connection Error: $error';
        });
        _attemptReconnect();
      });
    } catch (e) {
      print('Non-secure WebSocket Initialization Error: $e');
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Non-secure Initialization Error: $e';
      });
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (!_isReconnecting) {
      _isReconnecting = true;
      setState(() {
        _connectionStatus = 'Attempting to reconnect...';
      });
      Future.delayed(const Duration(seconds: 3), () {
        print('Attempting to reconnect...');
        _isReconnecting = false;
        _connectWebSocket();
      });
    }
  }

  void _showStopConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF06555E),
          title: const Text(
            'Are you sure you want to stop the Pomodoro?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This action will end the current Pomodoro session.',
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

                try {
                  // Calculate completed duration in minutes (25 - remaining minutes)
                  final completedMinutes = 25 - (_timeLeft ~/ 60);

                  // Call the complete API
                  final result = await _apiService.completeUserPomodoro(
                    userId: userId!,
                    duration: completedMinutes,
                    completedAt: DateTime.now(),
                  );

                  if (result != null && mounted) {
                    // Show completion notification
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '$username completed a $completedMinutes minute pomodoro! 🎉'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );

                    // Show achievements if any
                    if (result['achievements'] != null &&
                        result['achievements'].isNotEmpty) {
                      for (var achievement in result['achievements']) {
                        if (achievement['is_new'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '🏆 New Achievement: ${achievement['title']}'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }

                    // Show creature updates if any
                    if (result['creatures'] != null &&
                        result['creatures'].isNotEmpty) {
                      for (var creature in result['creatures']) {
                        if (creature['has_update'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('🌱 ${creature['name']} has grown!'),
                              backgroundColor: Colors.blue,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error completing pomodoro: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                setState(() {
                  _isRunning = false;
                  _timeLeft = 25 * 60;
                });

                socket.emit('endPomodoro', {
                  'userId': userId,
                  'username': username,
                  'reefId': _currentReefId,
                  'aiExplanation': aiExplanation
                });
              },
              child: const Text(
                'Stops',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleTimer() {
    if (!_isRunning) {
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _showCompletionDialog();
          }
        });
      });

      // Emit start event
      socket.emit('startPomodoro', {
        'userId': userId,
        'username': username,
        'reefId': _currentReefId,
        'aiExplanation': aiExplanation,
      });
    } else {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
      socket.emit('endPomodoro', {
        'userId': userId,
        'username': username,
        'reefId': _currentReefId,
        'aiExplanation': aiExplanation,
      });
    }
  }

  void _addTime(int minutes) {
    setState(() {
      _timeLeft += minutes * 60;
      socket.emit('addTime', {
        'userId': userId,
        'username': username,
        'reefId': _currentReefId,
        'minutes': minutes,
        'aiExplanation': aiExplanation
      });
    });
  }

  void _resetTimer() {
    setState(() {
      _timeLeft = 25 * 60;
      _isRunning = false;
      _timer?.cancel();
      socket.emit('endPomodoro', {
        'userId': userId,
        'username': username,
        'reefId': _currentReefId,
        'aiExplanation': aiExplanation,
      });
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

  void _showShareDialog() {
    String teamName = '';
    String teamCode = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF06555E),
        title: const Text(
          'Team Actions',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Takım Oluşturma Bölümü
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Team',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Team Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      onChanged: (value) {
                        teamName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_currentReefId != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentReefId!.substring(0, 5),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                color: Colors.white70, size: 20),
                            tooltip: 'Copy Code',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _currentReefId!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Team code copied!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Takıma Katılma Bölümü
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Join Team',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Team ID',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      onChanged: (value) {
                        teamCode = value;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (teamName.isNotEmpty && userId != null) {
                try {
                  final result = await _apiService.createTeam(
                    teamName: teamName,
                    userId: userId!,
                  );
                  String explanation =
                      aiExplanation ?? await _generateAiExplanation();
                  socket.emit('teamCreated', {
                    'userId': userId,
                    'username': username,
                    'teamName': teamName,
                    'roomId': result['room_id'],
                    'reefId': result['reef_id'],
                  });
                  setState(() {
                    _currentReefId = result['room_id'];
                    _currentReefName = teamName;
                  });
                  socket.emit('joinReef', {
                    'userId': userId,
                    'username': username,
                    'reefId': result['room_id'],
                    'reefName': teamName,
                    'aiExplanation': explanation
                  });
                  Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating team: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else if (teamCode.isNotEmpty && userId != null) {
                try {
                  final result = await _apiService.joinTeam(
                    teamId: teamCode,
                    userId: userId!,
                  );
                  String explanation =
                      aiExplanation ?? await _generateAiExplanation();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ??
                            'Successfully joined the team!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  socket.emit('joinReef', {
                    'userId': userId,
                    'username': username,
                    'reefId': teamCode,
                    'reefName': result['room_name'] ?? 'Unknown Team',
                    'aiExplanation': explanation
                  });
                  setState(() {
                    _currentReefId = teamCode;
                    _currentReefName = result['room_name'] ?? 'Unknown Team';
                  });
                  Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error joining team: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog() {
    bool wasRunning = _isRunning;
    if (_isRunning) {
      _toggleTimer(); // Pause the timer while showing dialog
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
                  _toggleTimer(); // Resume timer if it was running
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

  void _joinReef() {
    if (_currentReefId != null) {
      socket.emit('joinReef', {
        'userId': userId,
        'username': username,
        'reefId': _currentReefId,
        'reefName': _currentReefName ?? 'Unknown Team',
        'aiExplanation': aiExplanation
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket.dispose();
    super.dispose();
  }

  Widget _buildTeamMemberStatus(String username, bool isActive, int timeLeft) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            username,
            style: const TextStyle(
              color: Color(0xFFDCFAFF),
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 10),
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: 1 - (timeLeft / (25 * 60)),
                strokeWidth: 2,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        onPressed: userId == this.userId && !_isRunning
                            ? _toggleTimer
                            : null,
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
                        onPressed: userId == this.userId && _isRunning
                            ? _resetTimer
                            : null,
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
                      Column(
                        children: [
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
                                _showShareDialog();
                              },
                              child: const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _showLeaveReefDialog({
                                'id': _currentReefId,
                                'name': _currentReefName ?? 'Team',
                              }),
                              child: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_currentReefId != null &&
                      _currentReefId!.startsWith('TEAM-'))
                    Card(
                      color: Colors.white.withOpacity(0.08),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentReefName ?? 'Team',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _currentReefId!.substring(0, 5),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy,
                                          color: Colors.white70, size: 20),
                                      tooltip: 'Kodu Kopyala',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: _currentReefId!));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Takım kodu kopyalandı!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.logout),
                              label: const Text('Leave'),
                              onPressed: () {
                                _showLeaveReefDialog({
                                  'id': _currentReefId,
                                  'name': _currentReefName ?? 'Team',
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 28, 132, 184)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentReefName ?? 'Team',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTeamMembersSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BottomNavBar(selectedIndex: _selectedIndex),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  team['name'] ?? 'Unnamed Team',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () => _showShareDialog(),
                          tooltip: 'Share Team Code',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () => _showLeaveReefDialog(team),
                          tooltip: 'Leave Team',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Team Code: ${team['code']}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildTeamMembers(team),
          ],
        ),
      ),
    );
  }

  void _showLeaveReefDialog(Map<String, dynamic> team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Team'),
        content: Text(
          'Are you sure you want to leave ${team['name'] ?? 'this team'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveReef(team);
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveReef(Map<String, dynamic> team) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _apiService.leaveTeam(
        teamId: team['id'],
        userId: userId!,
      );

      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _timeLeft = 25 * 60;
      });

      // Sadece leaveReef eventini gönder
      socket.emit('leaveReef', {
        'userId': userId,
        'username': username,
        'reefId': team['id'],
        'aiExplanation': aiExplanation,
      });

      if (response['message'] == '✅ User left the team successfully') {
        setState(() {
          _teams.removeWhere((t) => t['id'] == team['id']);
          _currentReefId = null;
          _currentReefName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the team'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to leave team: ${response['message']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTeamMembers(Map<String, dynamic> team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...(team['members'] ?? []).map<Widget>((member) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: member['isActive'] ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(member['username'] ?? 'Unknown User'),
              ],
            ),
          );
        }).toList(),
      ],
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _timeLeft = 25 * 60;
                _currentRound++;
                _completedGoals++;
              });
              socket.emit('requestAIInsights', {
                'userId': userId,
                'username': username,
                'reefId': _currentReefId,
                'aiExplanation': aiExplanation
              });
            },
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  Future<String> _generateAiExplanation() async {
    final stats = await _apiService.getUserStatistics(userId!);
    final focusRate = stats['focus_rate'] ?? 0;
    final productivityScore = stats['avg_productivity_score'] ?? 0;
    final userName = username ?? 'Kullanıcı';
    if (focusRate >= 80 && productivityScore >= 80) {
      return "$userName, focus rate'in ($focusRate) ve productivity score'un ($productivityScore) çok iyi! Harika gidiyorsun.";
    } else if (focusRate >= 50 && productivityScore >= 50) {
      return "$userName, focus rate'in ($focusRate) ve productivity score'un ($productivityScore) ortalama seviyede. Daha iyiye gidebilirsin!";
    } else {
      return "$userName, focus rate'in ($focusRate) ve productivity score'un ($productivityScore) düşük görünüyor. Motivasyonunu artırmak için yeni yöntemler deneyebilirsin.";
    }
  }

  Widget _buildTeamMembersSection() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final prefs = snapshot.data!;
        final reefId = prefs.getString('reefId') ?? _currentReefId;
        if (reefId == null || reefId.isEmpty) {
          return const Center(
            child: Text(
              'No team created yet.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return TeamMembers(teamId: reefId);
      },
    );
  }
}
