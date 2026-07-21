import 'package:flutter_test/flutter_test.dart';
import 'package:forgefit/core/set_session_flow.dart';

void main() {
  group('SetSessionFlow', () {
    test('percorre preview, countdown, esecuzione, conferma e recupero', () {
      final flow = SetSessionFlow(totalSets: 2);

      expect(flow.phase, SetSessionPhase.preparing);
      flow.startCountdown();
      expect(flow.phase, SetSessionPhase.countdown);
      flow.startExecution();
      expect(flow.phase, SetSessionPhase.executing);
      flow.stopExecution();
      expect(flow.phase, SetSessionPhase.confirming);
      flow.confirmSet();
      expect(flow.phase, SetSessionPhase.resting);

      flow.finishRest();
      expect(flow.activeSetIndex, 1);
      expect(flow.phase, SetSessionPhase.preparing);
    });

    test('annullare il countdown torna alla preparazione', () {
      final flow = SetSessionFlow(totalSets: 1);
      flow.startCountdown();
      flow.cancelCountdown();
      expect(flow.phase, SetSessionPhase.preparing);
    });

    test('l ultima serie termina la sessione esercizio', () {
      final flow = SetSessionFlow(totalSets: 1);
      flow.startCountdown();
      flow.startExecution();
      flow.stopExecution();
      flow.confirmSet();
      expect(flow.phase, SetSessionPhase.completed);
    });

    test('blocca transizioni non valide e doppi avvii', () {
      final flow = SetSessionFlow(totalSets: 1);
      expect(flow.startExecution, throwsStateError);
      flow.startCountdown();
      expect(flow.startCountdown, throwsStateError);
    });
  });
}
