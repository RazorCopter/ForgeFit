import '../models/training_data.dart';

class MockData {
  static List<TrainingDay> getTrainingDays() {
    return [
      _buildDay1(),
      _buildDay2(),
      _buildDay3(),
      _buildDay4(),
    ];
  }

  static TrainingDay _buildDay1() {
    return TrainingDay(
      id: 'd1',
      title: 'PUSH',
      subtitle: 'Petto Alto e Spalle',
      priority: 'Riempire il petto alto e allargare le spalle',
      exercises: [
        Exercise(
          id: 'd1_e1',
          name: 'Panca Piana Bilanciere',
          setup: 'Free Weight',
          loadNote: 'RIR 1-2 (pesante ma pulito)',
          videoUrl: 'https://www.youtube.com/watch?v=oK6YMPILKsQ',
          sets: _generateSets(4, 8, 150, minTargetReps: 6),
        ),
        Exercise(
          id: 'd1_e2',
          name: 'Multipower (Smith) Squat',
          setup: 'Multipower',
          loadNote: 'RIR 2 (profondo, talloni a terra)',
          videoUrl: 'https://www.youtube.com/watch?v=Ur1pBeuqGDU',
          sets: _generateSets(4, 10, 120, minTargetReps: 8),
        ),
        Exercise(
          id: 'd1_e3',
          name: 'Spinte Manubri 30°',
          setup: 'Panche + Manubri',
          loadNote: 'RIR 1 (focus sul petto alto)',
          videoUrl: 'https://www.youtube.com/watch?v=iKRv8OOtwAs',
          sets: _generateSets(3, 10, 90),
        ),
        Exercise(
          id: 'd1_e4',
          name: 'Pectoral Machine / Croci ai cavi',
          setup: 'Macchina/Cavi',
          loadNote: 'RIR 1 (contrazione muscolare massima)',
          videoUrl: 'https://www.youtube.com/watch?v=6dExVifvwR8',
          sets: _generateSets(3, 12, 60),
        ),
        Exercise(
          id: 'd1_e5',
          name: 'Alzate Laterali Manubri',
          setup: 'Manubri',
          loadNote: 'Cedimento all\'ultima serie',
          videoUrl: 'https://www.youtube.com/watch?v=PhFOzmpjUak',
          sets: _generateSets(3, 15, 60, minTargetReps: 12),
        ),
        Exercise(
          id: 'd1_e6',
          name: 'Pushdown Cavi',
          setup: 'Cavi',
          loadNote: 'RIR 1',
          videoUrl: 'https://www.youtube.com/watch?v=2-LAMcpzODU',
          sets: _generateSets(2, 12, 60),
        ),
      ],
    );
  }

  static TrainingDay _buildDay2() {
    return TrainingDay(
      id: 'd2',
      title: 'PULL',
      subtitle: 'Schiena e Femorali',
      priority: 'Allargare la schiena (V-taper) e stimolare i femorali',
      exercises: [
        Exercise(
          id: 'd2_e1',
          name: 'Trazioni alla sbarra',
          setup: 'Sbarra',
          loadNote: 'Se ne fai < 5, fai Lat Stretta Inversa',
          videoUrl: 'https://www.youtube.com/watch?v=Z5haXppd7EQ',
          sets: _generateSets(3, 15, 120), 
        ),
        Exercise(
          id: 'd2_e2',
          name: 'Leg Curl (Steso o Seduto)',
          setup: 'Macchina',
          loadNote: 'RIR 2 (controlla la fase di ritorno)',
          videoUrl: 'https://www.youtube.com/shorts/fsFruh7c8Jw',
          sets: _generateSets(4, 10, 90, minTargetReps: 8),
        ),
        Exercise(
          id: 'd2_e3',
          name: 'Pulley Basso',
          setup: 'Macchina',
          loadNote: 'RIR 1-2 (addome forte, schiena dritta)',
          videoUrl: 'https://www.youtube.com/watch?v=qaR7MJw1AOY',
          sets: _generateSets(3, 10, 90),
        ),
        Exercise(
          id: 'd2_e4',
          name: 'Lat Machine Presa Inversa (stretta)',
          setup: 'Macchina',
          loadNote: 'RIR 1',
          videoUrl: 'https://www.youtube.com/watch?v=C0MLVkBoJWg',
          sets: _generateSets(3, 12, 90),
        ),
        Exercise(
          id: 'd2_e5',
          name: 'Curl Bilanciere dritto (in piedi)',
          setup: 'Bilanciere Free',
          loadNote: 'RIR 1 (tecnica pulita, no slancio)',
          videoUrl: 'https://www.youtube.com/watch?v=P8mm2W4qZnU',
          sets: _generateSets(3, 10, 60),
        ),
        Exercise(
          id: 'd2_e6',
          name: 'Alzate Posteriori Manubri',
          setup: 'Panche + Manubri',
          loadNote: 'RIR 1',
          videoUrl: 'https://www.youtube.com/shorts/4ySGLXZuBTY',
          sets: _generateSets(3, 15, 60, minTargetReps: 12),
        ),
      ],
    );
  }

  static TrainingDay _buildDay3() {
    return TrainingDay(
      id: 'd3',
      title: 'LEGS',
      subtitle: 'Full Body depletivo',
      priority: 'Metabolismo, addome e pump depletivo',
      exercises: [
        Exercise(
          id: 'd3_e1',
          name: 'Affondi inversi con manubri',
          setup: 'Manubri',
          loadNote: 'RIR 2 (per gamba)',
          videoUrl: 'https://www.youtube.com/watch?v=u1hgQEjFFpM',
          sets: _generateSets(3, 10, 90),
        ),
        Exercise(
          id: 'd3_e2',
          name: 'Lento Avanti Multipower',
          setup: 'Multipower + Panca',
          loadNote: 'RIR 2 (spinta verticale)',
          videoUrl: 'https://www.youtube.com/watch?v=DzSDb_tFtkY',
          sets: _generateSets(3, 10, 90),
        ),
        Exercise(
          id: 'd3_e3',
          name: 'Leg Extension',
          setup: 'Macchina',
          loadNote: 'Cedimento tecnico (pompaggio)',
          videoUrl: 'https://www.youtube.com/watch?v=YyvSfVjQeL0',
          sets: _generateSets(3, 15, 60, minTargetReps: 12),
        ),
        Exercise(
          id: 'd3_e4',
          name: 'Rematore Manubrio singolo',
          setup: 'Panca + Manubri',
          loadNote: 'RIR 1 (per braccio)',
          videoUrl: 'https://www.youtube.com/watch?v=pYcpY20QaE8',
          sets: _generateSets(3, 10, 60),
        ),
        Exercise(
          id: 'd3_e5',
          name: 'Plank Addominale',
          setup: 'Corpo Libero',
          loadNote: 'Fino a cedimento tecnico (Max Tempo)',
          videoUrl: 'https://www.youtube.com/watch?v=ASdvN_XEl_c',
          sets: _generateSets(3, 60, 60),
        ),
        Exercise(
          id: 'd3_e6',
          name: 'Crunch Addominale ai cavi',
          setup: 'Cavi',
          loadNote: 'RIR 1 (arrotola la colonna)',
          videoUrl: 'https://www.youtube.com/shorts/TgbM-oaHbjk',
          sets: _generateSets(3, 15, 60),
        ),
      ],
    );
  }

  static TrainingDay _buildDay4() {
    return TrainingDay(
      id: 'd4',
      title: 'HOME (Opzionale)',
      subtitle: 'Weakpoints / Arms',
      priority: 'Volume extra su petto, spalle, bicipiti e tricipiti',
      exercises: [
        Exercise(
          id: 'd4_e1',
          name: 'Floor Press Bilanciere',
          setup: 'Panca + Bil. (a terra)',
          loadNote: 'RIR 1-2 (Più sicuro a casa)',
          videoUrl: 'https://www.youtube.com/watch?v=nYa_rGWlBpk',
          sets: _generateSets(3, 10, 120, minTargetReps: 8),
        ),
        Exercise(
          id: 'd4_e2',
          name: 'Dumbbell Pullover',
          setup: 'Panca + 1 Manubrio',
          loadNote: 'RIR 1 (Apre cassa toracica)',
          videoUrl: 'https://www.youtube.com/watch?v=ABMUy5dLJzM',
          sets: _generateSets(3, 12, 90, minTargetReps: 10),
        ),
        Exercise(
          id: 'd4_e3',
          name: 'Lento Avanti Seduto Manubri',
          setup: 'Panca 90° + Manubri',
          loadNote: 'RIR 1 (Per massa spalle)',
          videoUrl: 'https://www.youtube.com/watch?v=qEwKCR5JCog',
          sets: _generateSets(3, 12, 90, minTargetReps: 10),
        ),
        Exercise(
          id: 'd4_e4',
          name: 'EZ Bar Curl',
          setup: 'Bil. curvo',
          loadNote: 'RIR 1-2',
          videoUrl: 'https://www.youtube.com/watch?v=7ECvCFpsOik',
          sets: _generateSets(3, 12, 60, minTargetReps: 10),
        ),
        Exercise(
          id: 'd4_e5',
          name: 'Panca Stretta Manubri',
          setup: 'Panca + Manubri',
          loadNote: 'RIR 1-2',
          videoUrl: 'https://www.youtube.com/watch?v=wj7A2IuFxhw',
          sets: _generateSets(3, 12, 60, minTargetReps: 10),
        ),
      ],
    );
  }

  static List<ExerciseSet> _generateSets(
      int count, int reps, int restSeconds, {int minTargetReps = 0}) {
    List<ExerciseSet> result = [];
    for (int i = 0; i < count; i++) {
      result.add(ExerciseSet(
        number: i + 1,
        targetReps: reps,
        minTargetReps: minTargetReps,
        targetRestSeconds: restSeconds,
      ));
    }
    return result;
  }
}
