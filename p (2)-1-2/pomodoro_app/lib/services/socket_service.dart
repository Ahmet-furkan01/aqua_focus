import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  static SocketService? _instance;
  IO.Socket? socket;
  static const String _serverUrl = 'http://server.yagiz.tc:666';
  bool _isConnecting = false;
  bool _isInitialized = false;

  // Singleton factory constructor
  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal();

  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔵 Socket service already initialized');
      return;
    }

    _isInitialized = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting) {
      print('🔵 Socket connection already in progress');
      return;
    }

    _isConnecting = true;

    try {
      if (socket != null) {
        print('🔄 Cleaning up existing socket connection');
        socket!.disconnect();
        socket!.dispose();
        socket = null;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('🔄 Initializing socket connection to $_serverUrl');

      socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'timeout': 10000,
        'forceNew': false,
      });

      _setupEventHandlers();

      print('🔌 Attempting to connect socket...');
      socket!.connect();

      bool connectionSuccessful = await _waitForConnection();

      if (connectionSuccessful) {
        print('✅ Socket connection successful');
      } else {
        print('❌ Socket connection failed after timeout');
        await _retryConnection();
      }
    } catch (e) {
      print('❌ Socket connection error: $e');
      await _retryConnection();
    } finally {
      _isConnecting = false;
    }
  }

  Future<bool> _waitForConnection() async {
    int attempts = 0;
    while (attempts < 5) {
      if (socket?.connected ?? false) {
        return true;
      }
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }
    return false;
  }

  void _setupEventHandlers() {
    socket?.onConnect((_) {
      print('🟢 Socket connected successfully');
    });

    socket?.onConnecting((_) {
      print('🔄 Socket connecting...');
    });

    socket?.onDisconnect((_) {
      print('🔴 Socket disconnected');
    });

    socket?.onError((error) {
      print('⚠️ Socket error: $error');
    });

    socket?.onConnectError((error) {
      print('⚠️ Socket connection error: $error');
    });

    socket?.onConnectTimeout((_) {
      print('⚠️ Socket connection timeout');
    });
  }

  Future<void> _retryConnection() async {
    if (!_isConnecting) {
      print('🔄 Scheduling reconnection attempt...');
      await Future.delayed(const Duration(seconds: 5));
      if (socket?.connected ?? false) {
        print('✅ Already reconnected');
        return;
      }
      await _connect();
    }
  }

  bool get isConnected => socket?.connected ?? false;

  Future<void> reconnect() async {
    print('🔄 Manual reconnection requested');
    await _connect();
  }

  void dispose() {
    print('🗑️ Disposing socket service');
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _isInitialized = false;
    _instance = null;
  }

  // -------------------- TEAM SOCKET EVENTS --------------------

  void joinTeam(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('joinReef', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
        'pomodoros': 0,
        'timerState': null
      });
      print('🌊 Joining reef: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot join reef.');
    }
  }

  void leaveReef(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('leaveReef', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
      });
      print('🌊 Leaving reef: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot leave reef.');
    }
  }

  // -------------------- TIMER SOCKET EVENTS --------------------

  void startTimer(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('timerStarted', {
        'user_id': userId,
        'username': username,
        'reef_id': reefId,
        'ai_explanation': aiExplanation,
        'timerState': null
      });
      print('⏱️ Timer started for user: $username in team: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot start timer.');
    }
  }

  void pauseTimer(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('timerPaused', {
        'user_id': userId,
        'username': username,
        'reef_id': reefId,
        'ai_explanation': aiExplanation,
        'timerState': null
      });
      print('⏸️ Timer paused for user: $username in team: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot pause timer.');
    }
  }

  void resetTimer(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('timerReset', {
        'user_id': userId,
        'username': username,
        'reef_id': reefId,
        'ai_explanation': aiExplanation,
        'timerState': null
      });
      print('🔄 Timer reset for user: $username in team: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot reset timer.');
    }
  }

  void addTime(String userId, String username, String reefId,
      String aiExplanation, int minutes) {
    if (socket?.connected ?? false) {
      socket?.emit('timeAdded', {
        'user_id': userId,
        'username': username,
        'reef_id': reefId,
        'ai_explanation': aiExplanation,
        'minutes': minutes,
        'timerState': null
      });
      print(
          '➕ Added $minutes minutes to timer for user: $username in team: $reefId');
    } else {
      print('⚠️ Socket not connected. Cannot add time.');
    }
  }

  // -------------------- AQUAFOCUS CUSTOM EVENTS (EMIT) --------------------

  void joinReef({
    required String userId,
    required String username,
    required String reefId,
    required String reefName,
    String? aiExplanation,
  }) {
    if (socket?.connected ?? false) {
      socket?.emit('joinReef', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'reefName': reefName,
        'aiExplanation': aiExplanation,
      });
      print('🌊 joinReef emitted');
    } else {
      print('⚠️ Socket not connected. Cannot emit joinReef.');
    }
  }

  void startPomodoro(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('startPomodoro', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
      });
      print('🟢 startPomodoro emitted');
    } else {
      print('⚠️ Socket not connected. Cannot emit startPomodoro.');
    }
  }

  void endPomodoro(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('endPomodoro', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
      });
      print('🔴 endPomodoro emitted');
    } else {
      print('⚠️ Socket not connected. Cannot emit endPomodoro.');
    }
  }

  void requestAIInsights(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('requestAIInsights', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
      });
      print('🤖 requestAIInsights emitted');
    } else {
      print('⚠️ Socket not connected. Cannot emit requestAIInsights.');
    }
  }

  void reconnectRequest(
      String userId, String username, String reefId, String aiExplanation) {
    if (socket?.connected ?? false) {
      socket?.emit('reconnectRequest', {
        'userId': userId,
        'username': username,
        'reefId': reefId,
        'aiExplanation': aiExplanation,
      });
      print('🔁 reconnectRequest emitted');
    } else {
      print('⚠️ Socket not connected. Cannot emit reconnectRequest.');
    }
  }

  // -------------------- AQUAFOCUS CUSTOM EVENTS (LISTEN) --------------------

  void listenReefUpdated(void Function(dynamic data) callback) {
    socket?.on('reefUpdated', (data) {
      print('📦 reefUpdated: $data');
      callback(data);
    });
  }

  void listenReefRestored(void Function(dynamic data) callback) {
    socket?.on('reefRestored', (data) {
      print('♻️ reefRestored: $data');
      callback(data);
    });
  }

  void listenAIInsights(void Function(dynamic data) callback) {
    socket?.on('aiInsights', (data) {
      print('🧠 aiInsights: $data');
      callback(data);
    });
  }

  void listenPomodoroStarted(void Function(dynamic data) callback) {
    socket?.on('pomodoroStarted', (data) {
      print('⏱️ pomodoroStarted: $data');
      callback(data);
    });
  }

  void listenPomodoroEnded(void Function(dynamic data) callback) {
    socket?.on('pomodoroEnded', (data) {
      print('⛔ pomodoroEnded: $data');
      callback(data);
    });
  }

  Future<Map<String, dynamic>?> getTeamMembers(String reefId) async {
    if (socket == null) return null;

    try {
      final completer = Completer<Map<String, dynamic>>();
      socket!.emitWithAck('getTeamMembers', {'reefId': reefId}, ack: (data) {
        if (data != null && data is Map<String, dynamic>) {
          completer.complete(data);
        } else {
          completer.complete({'members': []});
        }
      });
      return await completer.future;
    } catch (e) {
      print('Error getting team members: $e');
      return {'members': []};
    }
  }
}
