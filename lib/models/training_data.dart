class ExerciseSet {
  final int number;
  int targetReps;
  int minTargetReps;
  int actualReps;
  double weight;
  int targetRestSeconds;
  bool isCompleted;
  int timeUnderTension;

  ExerciseSet({
    required this.number,
    required this.targetReps,
    this.minTargetReps = 0,
    this.actualReps = 0,
    this.weight = 0.0,
    required this.targetRestSeconds,
    this.isCompleted = false,
    this.timeUnderTension = 0,
  });
}

class Exercise {
  final String id;
  final String name;
  final String setup;
  final String loadNote; // es: RIR 1-2
  final String videoUrl;
  final String? externalNote;
  /// Gruppo muscolare primario, valorizzato dal backend (es. 'Petto', 'Schiena').
  final String? gruppoMuscolare;

  final List<ExerciseSet> sets;

  Exercise({
    required this.id,
    required this.name,
    required this.setup,
    required this.loadNote,
    required this.sets,
    this.videoUrl = '',
    this.externalNote,
    this.gruppoMuscolare,
  });
}

class TrainingDay {
  final String id;
  final String title; // es: PUSH
  final String subtitle; // es: Petto Alto e Spalle
  final String priority;
  final List<Exercise> exercises;

  TrainingDay({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.exercises,
  });
}
