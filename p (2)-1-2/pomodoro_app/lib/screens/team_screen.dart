import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/team_session_service.dart';
import '../screens/team_pomodoro_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/team_members.dart';

class TeamScreen extends StatefulWidget {
  final String reefId;
  final String userId;
  final String username;
  final String aiExplanation;

  const TeamScreen({
    Key? key,
    required this.reefId,
    required this.userId,
    required this.username,
    required this.aiExplanation,
  }) : super(key: key);

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  Timer? _timer;
  int _timeLeft = 25 * 60; // 25 minutes in seconds
  Map<String, bool> _userIsRunning = {};
  List<Map<String, dynamic>> _teamMembers = [];
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
    _setupSocketListeners();
    _setupExtraSocketListeners();
  }

  void _loadTeamData() async {
    try {
      final members = await _apiService.getTeamMembers(widget.reefId);
      setState(() {
        _teamMembers = List<Map<String, dynamic>>.from(members);
      });
    } catch (e) {
      print('Error loading team data: $e');
    }
  }

  void _setupSocketListeners() async {
    try {
      String explanation =
          widget.aiExplanation ?? await _generateAiExplanation();
      _socketService.joinTeam(
          widget.userId, widget.username, widget.reefId, explanation);

      _socketService.socket?.on('newMember', (data) {
        if (mounted && data['reef_id'] == widget.reefId) {
          _loadTeamData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${data['username']} joined the session'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

      _socketService.socket?.on('userRemoved', (data) {
        if (mounted && data['reef_id'] == widget.reefId) {
          _loadTeamData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${data['username']} left the session'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _socketService.socket?.on('pomodoroStarted', (data) {
        if (data['reefId'] == widget.reefId &&
            data['userId'] == widget.userId) {
          setState(() {
            _userIsRunning[widget.userId] = true;
          });
        }
      });

      _socketService.socket?.on('pomodoroEnded', (data) {
        if (data['reefId'] == widget.reefId &&
            data['userId'] == widget.userId) {
          setState(() {
            _userIsRunning[widget.userId] = false;
            _timeLeft = 25 * 60;
          });
        }
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

      _socketService.socket?.on('timeAdded', (data) {
        if (data['reefId'] == widget.reefId &&
            data['userId'] == widget.userId) {
          setState(() {
            _timeLeft += (data['minutes'] as int) * 60;
          });
        }
      });
    } catch (e) {
      print('Error setting up socket connection: $e');
    }
  }

  Future<String> _generateAiExplanation() async {
    final stats = await _apiService.getUserStatistics(widget.userId);
    final focusRate = stats['focus_rate'] ?? 0;
    final productivityScore = stats['avg_productivity_score'] ?? 0;
    final userName = widget.username ?? 'User';
    if (focusRate >= 80 && productivityScore >= 80) {
      return "$userName, your focus rate is ($focusRate) and productivity score is ($productivityScore). Great job!";
    } else if (focusRate >= 50 && productivityScore >= 50) {
      return "$userName, your focus rate is ($focusRate) and productivity score is ($productivityScore). You can do better!";
    } else {
      return "$userName, your focus rate is ($focusRate) and productivity score is ($productivityScore). You can do better!";
    }
  }

  void _setupExtraSocketListeners() {
    final socket = _socketService.socket;
    if (socket == null) return;

    socket.on('connect', (_) {
      print('Socket.IO Connected Successfully');
    });
    socket.on('disconnect', (_) {
      print('Socket.IO Disconnected');
    });
    socket.on('connect_error', (error) {
      print('Socket.IO Connection Error: $error');
    });
    socket.on('reconnect', (attemptNumber) {
      print('Reconnected after $attemptNumber attempts');
    });
    socket.on('reconnect_error', (error) {
      print('Reconnection error: $error');
    });
    socket.on('reconnect_failed', (data) {
      print('Reconnection failed');
    });
    socket.on('joinReef', (data) {
      print('Join reef received: $data');
      if (data['reefId'] == widget.reefId) {
        _loadTeamData();
      }
    });
    socket.on('pomodoroStarted', (data) {
      if (data['userId'] == widget.userId) {
        setState(() {
          _userIsRunning[widget.userId] = true;
        });
      }
    });

    socket.on('endPomodoro', (data) {
      print('End pomodoro received: $data');
      if (data['userId'] == widget.userId) {
        setState(() {
          _userIsRunning[widget.userId] = false;
          _timeLeft = 25 * 60;
        });
      }
    });

    socket.on('reefUpdated', (data) {
      print('reefUpdated: $data');
      if (data['reefId'] == widget.reefId) {
        _loadTeamData();
      }
    });
    socket.on('teamMembersUpdated', (data) {
      print('teamMembersUpdated: $data');
      if (data['teamId'] == widget.reefId && data['members'] != null) {
        setState(() {
          _teamMembers = List<Map<String, dynamic>>.from(data['members']);
        });
      }
    });
  }

  void _toggleTimer() {
    setState(() {
      final userId = widget.userId;
      if (_userIsRunning[userId] == true) {
        _timer?.cancel();
        _userIsRunning[userId] = false;
        _socketService.socket?.emit('endPomodoro', {
          'userId': userId,
          'username': widget.username,
          'reefId': widget.reefId,
          'aiExplanation': widget.aiExplanation,
        });
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timer?.cancel();
              _userIsRunning[userId] = false;
              _timeLeft = 25 * 60;
            }
          });
        });
        _userIsRunning[userId] = true;
        _socketService.socket?.emit('startPomodoro', {
          'userId': userId,
          'username': widget.username,
          'reefId': widget.reefId,
          'aiExplanation': widget.aiExplanation,
        });
      }
    });
  }

  void _addTime(int minutes) {
    setState(() {
      _timeLeft += minutes * 60;
      _socketService.socket?.emit('addTime', {
        'userId': widget.userId,
        'reefId': widget.reefId,
        'username': widget.username,
        'minutes': minutes,
      });
    });
  }

  void _resetTimer() {
    setState(() {
      _timeLeft = 25 * 60;
      _userIsRunning[widget.userId] = false;
      _timer?.cancel();
      _socketService.socket?.emit('endPomodoro', {
        'userId': widget.userId,
        'username': widget.username,
        'reefId': widget.reefId,
        'aiExplanation': widget.aiExplanation,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFDCFAFF),
          fontSize: 12,
        ),
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    if (_userIsRunning[widget.userId] == true) {
      _timer?.cancel();
      setState(() {
        _userIsRunning[widget.userId] = false;
      });
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF06555E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure?',
                style: TextStyle(
                  color: Color(0xFFDCFAFF),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'This will reset your timer to 25 minutes',
                style: TextStyle(
                  color: Color(0xFFDCFAFF),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF3B3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _timeLeft = 25 * 60;
                      _userIsRunning[widget.userId] = false;
                      _timer?.cancel();
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "I'm sure",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_userIsRunning[widget.userId] != true) {
                    _toggleTimer();
                  }
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinTeamDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Team'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Enter team code',
            hintText: '6-digit code',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final teamId = codeController.text.trim();
              if (teamId.length == 6) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamPomodoroScreen(
                      userId: widget.userId,
                      username: widget.username,
                      reefId: widget.reefId,
                      aiExplanation: widget.aiExplanation,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid 6-digit code'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Join'),
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
              onPressed: () {
                Navigator.of(context).pop();
                _timer?.cancel();
                setState(() {
                  _userIsRunning[widget.userId] = false;
                  _timeLeft = 25 * 60;
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

  void _showLeaveReefDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Team'),
        content: const Text('Are you sure you want to leave the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.leaveTeam(
                  teamId: widget.reefId,
                  userId: widget.userId,
                );
                _timer?.cancel();
                setState(() {
                  _userIsRunning[widget.userId] = false;
                  _timeLeft = 25 * 60;
                });
                _socketService.leaveReef(widget.userId, widget.username,
                    widget.reefId, widget.aiExplanation);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamScreen(
                        reefId: widget.reefId,
                        userId: widget.userId,
                        username: widget.username,
                        aiExplanation: widget.aiExplanation,
                      ),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully left the team'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('An error occurred while leaving the team: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socketService.leaveReef(
        widget.userId, widget.username, widget.reefId, widget.aiExplanation);
    super.dispose();
  }

  Widget _buildTeamMembersBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _teamMembers.length,
            itemBuilder: (context, index) {
              final member = _teamMembers[index];
              final isCurrentUser = member['userId'] == widget.userId;
              String badgeText = '';
              Color badgeColor = Colors.transparent;
              if (isCurrentUser) {
                if (_userIsRunning[widget.userId] == true) {
                  badgeText = 'Online';
                  badgeColor = Colors.blue;
                } else {
                  badgeText = 'Waiting';
                  badgeColor = Colors.orange;
                }
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    member['username'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  member['username'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: isCurrentUser && badgeText.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: badgeColor, width: 1.5),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
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
            colors: [
              Color(0xFF02363D),
              Color(0xFF1A4B52),
              Color(0xFF2D7A85),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeButton('+5 Minute', () => _addTime(5)),
                    const SizedBox(width: 8),
                    _buildTimeButton('+10 Minute', () => _addTime(10)),
                    const SizedBox(width: 8),
                    _buildTimeButton('+15 Minute', () => _addTime(15)),
                  ],
                ),
                const SizedBox(height: 30),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
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
                            fontSize: 16,
                          ),
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
                        backgroundColor: _userIsRunning[widget.userId] == true
                            ? Colors.grey
                            : Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: _userIsRunning[widget.userId] != true
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
                      onPressed: _userIsRunning[widget.userId] == true
                          ? _showStopConfirmationDialog
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
                              // Share button action
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
                            onPressed: _showLeaveReefDialog,
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
                const SizedBox(height: 30),
                _buildTeamMembersBox(),
                const Spacer(),
                BottomNavBar(selectedIndex: _selectedIndex),
                if (widget.reefId.isNotEmpty)
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
                          widget.reefId.substring(0, 5),
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
                        tooltip: 'Kodu Kopyala',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.reefId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Takım kodu kopyalandı!'),
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
        ),
      ),
    );
  }
}
