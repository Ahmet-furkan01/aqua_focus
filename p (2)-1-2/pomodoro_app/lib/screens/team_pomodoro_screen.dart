import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'team_screen.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/team_session_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/team_members.dart';

class UserTimerState {
  bool isRunning;
  int remainingSeconds;
  Timer? timer;
  bool isPaused;

  UserTimerState({
    this.isRunning = false,
    this.remainingSeconds = 25 * 60,
    this.timer,
    this.isPaused = false,
  });

  void cancelTimer() {
    timer?.cancel();
    timer = null;
    isRunning = false;
  }

  void startTimer(void Function() onTick, void Function() onComplete) {
    if (!isRunning && !isPaused) {
      isRunning = true;
      isPaused = false;
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds > 0) {
          remainingSeconds--;
          onTick();
        } else {
          cancelTimer();
          onComplete();
        }
      });
    }
  }

  void pauseTimer() {
    if (isRunning) {
      timer?.cancel();
      timer = null;
      isRunning = false;
      isPaused = true;
    }
  }

  void resumeTimer(void Function() onTick, void Function() onComplete) {
    if (isPaused) {
      isPaused = false;
      startTimer(onTick, onComplete);
    }
  }

  void resetTimer() {
    cancelTimer();
    remainingSeconds = 25 * 60;
    isPaused = false;
  }
}

class TeamPomodoroScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String reefId;
  final String aiExplanation;

  const TeamPomodoroScreen({
    Key? key,
    required this.userId,
    required this.username,
    required this.reefId,
    required this.aiExplanation,
  }) : super(key: key);

  @override
  _TeamPomodoroScreenState createState() => _TeamPomodoroScreenState();
}

class _TeamPomodoroScreenState extends State<TeamPomodoroScreen> {
  final SocketService _socketService = SocketService();
  final Map<String, UserTimerState> _userTimers = {};
  final int _workDuration = 25; // 25 minutes
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  UserTimerState get _currentUserTimer {
    return _userTimers[widget.userId] ??= UserTimerState();
  }

  @override
  void initState() {
    super.initState();
    _setupSocketConnection();
    _loadTeamMembers();
    _userTimers[widget.userId] = UserTimerState();
  }

  void _setupSocketConnection() async {
    final socket = _socketService.socket;
    if (socket == null) return;

    // Remove all existing listeners
    socket.off('connect');
    socket.off('disconnect');
    socket.off('connect_error');
    socket.off('reconnect');
    socket.off('reconnect_error');
    socket.off('reconnect_failed');
    socket.off('joinReef');
    socket.off('pomodoroStarted');
    socket.off('pomodoroEnded');
    socket.off('timerStarted');
    socket.off('timerPaused');
    socket.off('timerReset');
    socket.off('timeAdded');
    socket.off('reefUpdated');
    socket.off('reefRestored');
    socket.off('aiInsights');
    socket.off('teamMembersUpdated');

    // Connection events
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
      _socketService.reconnectRequest(
          widget.userId, widget.username, widget.reefId, widget.aiExplanation);
    });

    // Pomodoro events - only update for the current user
    socket.on('pomodoroStarted', (data) {
      print('pomodoroStarted: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.isRunning = true;
          _userTimers[widget.userId]!.remainingSeconds = _workDuration * 60;
          _userTimers[widget.userId]!.isPaused = false;
        });
        _startTimer();
      }
    });

    socket.on('pomodoroEnded', (data) {
      print('pomodoroEnded: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.isRunning = false;
          _userTimers[widget.userId]!.isPaused = false;
          _userTimers[widget.userId]!.remainingSeconds = _workDuration * 60;
        });
        _userTimers[widget.userId]?.cancelTimer();
      }
      // Show notification for any user's endPomodoro
      if (mounted && data['username'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ 🌊 ${data['username']}\'s focus is powering the reef!'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // Timer events - only update for the current user
    socket.on('timerStarted', (data) {
      print('timerStarted: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.isRunning = true;
          _userTimers[widget.userId]!.remainingSeconds = _workDuration * 60;
          _userTimers[widget.userId]!.isPaused = false;
        });
        _startTimer();
      }
    });

    socket.on('timerPaused', (data) {
      print('timerPaused: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.isRunning = false;
          _userTimers[widget.userId]!.isPaused = true;
        });
        _userTimers[widget.userId]?.cancelTimer();
      }
    });

    socket.on('timerReset', (data) {
      print('timerReset: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.isRunning = false;
          _userTimers[widget.userId]!.isPaused = false;
          _userTimers[widget.userId]!.remainingSeconds = _workDuration * 60;
        });
        _userTimers[widget.userId]?.cancelTimer();
      }
    });

    socket.on('timeAdded', (data) {
      print('timeAdded: $data');
      if (data['reefId'] == widget.reefId && data['userId'] == widget.userId) {
        setState(() {
          _userTimers[widget.userId] ??= UserTimerState();
          _userTimers[widget.userId]!.remainingSeconds +=
              (data['minutes'] as int) * 60;
        });
      }
    });

    // Team events
    socket.on('joinReef', (data) {
      print('Join reef received: $data');
      if (data['reefId'] == widget.reefId) {
        _loadTeamMembers();
        if (data['userId'] != widget.userId) {
          _showNotification('${data['username']} takıma katıldı', Colors.green);
        }
      }
    });

    socket.on('reefUpdated', (data) {
      print('reefUpdated: $data');
      if (data['reefId'] == widget.reefId) {
        _loadTeamMembers();
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

    // Join team with explanation
    String explanation = widget.aiExplanation ?? await _generateAiExplanation();
    _socketService.joinTeam(
        widget.userId, widget.username, widget.reefId, explanation);
  }

  Future<String> _generateAiExplanation() async {
    // Bu metod AI açıklaması oluşturmak için kullanılır
    // Şimdilik basit bir açıklama döndürüyoruz
    return 'Team work for pomodoro session';
  }

  Future<void> _loadTeamMembers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _socketService.getTeamMembers(widget.reefId);
      if (response != null && response['members'] != null) {
        setState(() {
          _teamMembers = List<Map<String, dynamic>>.from(response['members']);
          for (var member in _teamMembers) {
            if (_userTimers[member['userId']] == null) {
              _userTimers[member['userId']] = UserTimerState();
            }
          }
        });
      }
    } catch (e) {
      print('Error loading team members: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleTimer() {
    final socket = _socketService.socket;
    if (socket == null) return;

    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return;

    if (currentTimer.isRunning) {
      // Timer is running, pause it
      currentTimer.timer?.cancel();
      socket.emit('endPomodoro', {
        'userId': widget.userId,
        'username': widget.username,
        'reefId': widget.reefId,
        'aiExplanation': widget.aiExplanation,
      });
      setState(() {
        currentTimer.isRunning = false;
        currentTimer.isPaused = true;
      });
    } else {
      // Timer is paused or not started, start it
      socket.emit('startPomodoro', {
        'userId': widget.userId,
        'username': widget.username,
        'reefId': widget.reefId,
        'aiExplanation': widget.aiExplanation,
      });
      setState(() {
        currentTimer.isRunning = true;
        currentTimer.isPaused = false;
        currentTimer.remainingSeconds = _workDuration * 60;
      });
      _startTimer();
    }
  }

  void _addTime(int minutes) {
    final socket = _socketService.socket;
    if (socket == null) return;

    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return;

    socket.emit('addTime', {
      'userId': widget.userId,
      'reefId': widget.reefId,
      'username': widget.username,
      'minutes': minutes,
    });

    setState(() {
      currentTimer.remainingSeconds += minutes * 60;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showCreateTeamDialog() {
    final teamId = TeamSessionService.generateUniqueTeamId();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your team code:'),
            const SizedBox(height: 8),
            Text(
              teamId,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this code with your team members to join your session.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
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
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Team'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter team code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final teamId = controller.text.trim();
              if (teamId.isNotEmpty) {
                Navigator.pop(context);
                _joinTeam(teamId);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeam(String teamId) async {
    try {
      // Join team with Socket.IO
      _socketService.joinTeam(
          widget.userId, widget.username, teamId, widget.aiExplanation);

      // Save the session
      await TeamSessionService.joinTeam(teamId);

      // Load team members
      _loadTeamMembers();

      if (mounted) {
        _showNotification(
          'Successfully joined team: $teamId',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotification(
          'Error joining team: $e',
          Colors.red,
        );
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pomodoro Completed!'),
          content: const Text(
              'Congratulations! You have successfully completed your Pomodoro session.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetTimer();
              },
            ),
          ],
        );
      },
    );
  }

  void _showStopConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Stop Pomodoro'),
          content: const Text(
              'Are you sure you want to stop the Pomodoro? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Stop'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetTimer();
              },
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
                _currentUserTimer.cancelTimer();
                setState(() {
                  _currentUserTimer.remainingSeconds = _workDuration * 60;
                  _currentUserTimer.isRunning = false;
                  _currentUserTimer.isPaused = false;
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
                      content: Text('You have successfully left the team'),
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

  void _showNotification(String message, Color backgroundColor) {
    if (!mounted) return;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  backgroundColor == Colors.green
                      ? Icons.check_circle
                      : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    overlayEntry.remove();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _resetTimer() {
    final socket = _socketService.socket;
    if (socket == null) return;

    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return;

    socket.emit('endPomodoro', {
      'userId': widget.userId,
      'username': widget.username,
      'reefId': widget.reefId,
      'aiExplanation': widget.aiExplanation,
    });

    setState(() {
      currentTimer.remainingSeconds = _workDuration * 60;
      currentTimer.isRunning = false;
      currentTimer.isPaused = false;
    });
    currentTimer.cancelTimer();
  }

  void _startTimer() {
    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return;

    currentTimer.timer?.cancel();
    currentTimer.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (currentTimer.remainingSeconds > 0) {
          currentTimer.remainingSeconds--;
        } else {
          currentTimer.timer?.cancel();
          currentTimer.isRunning = false;
          _showCompletionDialog();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                'Team Pomodoro',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildTimerDisplay(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? CircularProgressIndicator()
                        : _buildTeamMembersList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.reefId.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      tooltip: 'Copy Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.reefId));
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
      ),
    );
  }

  @override
  void dispose() {
    for (var timerState in _userTimers.values) {
      timerState.cancelTimer();
    }
    _socketService.leaveReef(
        widget.userId, widget.username, widget.reefId, widget.aiExplanation);
    super.dispose();
  }

  Widget _buildTeamMembersList() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              final timer = _userTimers[member['userId']];
              final isCurrentUser = member['userId'] == widget.userId;
              String badgeText = '';
              Color badgeColor = Colors.transparent;
              if (isCurrentUser) {
                if (timer?.isRunning == true) {
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
                subtitle: Text(
                  timer?.isRunning == true
                      ? 'Working'
                      : timer?.isPaused == true
                          ? 'Paused'
                          : 'Waiting',
                  style: TextStyle(
                    color: timer?.isRunning == true
                        ? Colors.green
                        : timer?.isPaused == true
                            ? Colors.orange
                            : Colors.grey,
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

  Widget _buildTimerDisplay() {
    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return const SizedBox.shrink();

    final minutes = (currentTimer.remainingSeconds / 60).floor();
    final seconds = currentTimer.remainingSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerControls() {
    final currentTimer = _userTimers[widget.userId];
    if (currentTimer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timer Controls',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeButton(
                currentTimer.isRunning ? 'Pause' : 'Start',
                _toggleTimer,
                true,
              ),
              const SizedBox(width: 20),
              _buildTimeButton(
                'Reset',
                _resetTimer,
                !currentTimer.isRunning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeButton('+1 min', () => _addTime(1), true),
              const SizedBox(width: 10),
              _buildTimeButton('+5 min', () => _addTime(5), true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(
      String label, VoidCallback onPressed, bool isEnabled) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: label == 'Start'
            ? Colors.green
            : label == 'Pause'
                ? Colors.orange
                : label == 'Reset'
                    ? Colors.red
                    : Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBackgroundColor: Colors.grey,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Start'
                ? Icons.play_arrow
                : label == 'Pause'
                    ? Icons.pause
                    : label == 'Reset'
                        ? Icons.stop
                        : Icons.add,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
