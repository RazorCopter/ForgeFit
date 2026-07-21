/// Stati espliciti di una singola sessione esercizio.
enum SetSessionPhase {
  preparing,
  countdown,
  executing,
  confirming,
  resting,
  completed,
}

/// Macchina a stati pura: separa le regole del flusso dai timer e dalla UI.
class SetSessionFlow {
  SetSessionFlow({required this.totalSets, int initialSetIndex = 0})
      : activeSetIndex = initialSetIndex {
    if (totalSets <= 0) {
      throw ArgumentError.value(totalSets, 'totalSets', 'Deve essere positivo');
    }
    if (initialSetIndex < 0 || initialSetIndex >= totalSets) {
      throw RangeError.range(
          initialSetIndex, 0, totalSets - 1, 'initialSetIndex');
    }
  }

  final int totalSets;
  int activeSetIndex;
  SetSessionPhase phase = SetSessionPhase.preparing;

  bool get isLastSet => activeSetIndex == totalSets - 1;

  void startCountdown() {
    _require(SetSessionPhase.preparing);
    phase = SetSessionPhase.countdown;
  }

  void cancelCountdown() {
    _require(SetSessionPhase.countdown);
    phase = SetSessionPhase.preparing;
  }

  void startExecution() {
    _require(SetSessionPhase.countdown);
    phase = SetSessionPhase.executing;
  }

  void stopExecution() {
    _require(SetSessionPhase.executing);
    phase = SetSessionPhase.confirming;
  }

  void confirmSet() {
    _require(SetSessionPhase.confirming);
    phase = isLastSet ? SetSessionPhase.completed : SetSessionPhase.resting;
  }

  void finishRest() {
    _require(SetSessionPhase.resting);
    activeSetIndex++;
    phase = SetSessionPhase.preparing;
  }

  void _require(SetSessionPhase expected) {
    if (phase != expected) {
      throw StateError('Transizione non valida: $phase, atteso $expected');
    }
  }
}
