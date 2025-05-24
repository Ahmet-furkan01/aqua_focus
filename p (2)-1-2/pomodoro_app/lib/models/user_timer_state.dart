import 'dart:async';

class UserTimerState {
  bool isRunning;
  bool isPaused;
  int remainingSeconds;
  Timer? timer;

  UserTimerState({
    this.isRunning = false,
    this.isPaused = false,
    this.remainingSeconds = 25 * 60,
  });

  void cancelTimer() {
    timer?.cancel();
    timer = null;
  }
}
