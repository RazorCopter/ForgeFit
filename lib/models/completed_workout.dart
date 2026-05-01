import 'package:hive/hive.dart';

class CompletedWorkout {
  final String id;
  final String title;
  final DateTime date;
  final int durationSeconds;
  final List<CompletedExercise> exercises;

  CompletedWorkout({
    required this.id,
    required this.title,
    required this.date,
    required this.durationSeconds,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) => CompletedWorkout(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    durationSeconds: json['durationSeconds'] as int? ?? 0,
    exercises: (json['exercises'] as List<dynamic>?)
        ?.map((e) => CompletedExercise.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class CompletedExercise {
  final String name;
  final List<CompletedSet> sets;
  /// Gruppo muscolare primario copiato dalla scheda al momento del salvataggio.
  final String? gruppoMuscolare;

  CompletedExercise({
    required this.name,
    required this.sets,
    this.gruppoMuscolare,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'sets': sets.map((s) => s.toJson()).toList(),
    'gruppoMuscolare': gruppoMuscolare,
  };

  factory CompletedExercise.fromJson(Map<String, dynamic> json) => CompletedExercise(
    name: json['name'] as String? ?? '',
    sets: (json['sets'] as List<dynamic>?)
        ?.map((e) => CompletedSet.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    gruppoMuscolare: json['gruppoMuscolare'] as String?,
  );
}

class CompletedSet {
  final int reps;
  final double weight;
  final int timeUnderTension;

  CompletedSet({
    required this.reps,
    required this.weight,
    this.timeUnderTension = 0,
  });

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'weight': weight,
    'timeUnderTension': timeUnderTension,
  };

  factory CompletedSet.fromJson(Map<String, dynamic> json) => CompletedSet(
    reps: json['reps'] as int? ?? 0,
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    timeUnderTension: json['timeUnderTension'] as int? ?? 0,
  );
}

// Manual Hive Adapters

class CompletedWorkoutAdapter extends TypeAdapter<CompletedWorkout> {
  @override
  final int typeId = 0;

  @override
  CompletedWorkout read(BinaryReader reader) {
    return CompletedWorkout(
      id: reader.readString(),
      title: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      durationSeconds: reader.readInt(),
      exercises: reader.readList().cast<CompletedExercise>(),
    );
  }

  @override
  void write(BinaryWriter writer, CompletedWorkout obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.durationSeconds);
    writer.writeList(obj.exercises);
  }
}

class CompletedExerciseAdapter extends TypeAdapter<CompletedExercise> {
  @override
  final int typeId = 1;

  @override
  CompletedExercise read(BinaryReader reader) {
    final name = reader.readString();
    final sets = reader.readList().cast<CompletedSet>();
    // Retrocompatibile: i vecchi record non hanno il campo gruppoMuscolare.
    String? gruppoMuscolare;
    try {
      gruppoMuscolare = reader.readString();
      // Una stringa vuota salvata in passato equivale a null
      if (gruppoMuscolare.isEmpty) gruppoMuscolare = null;
    } catch (_) {}
    return CompletedExercise(
      name: name,
      sets: sets,
      gruppoMuscolare: gruppoMuscolare,
    );
  }

  @override
  void write(BinaryWriter writer, CompletedExercise obj) {
    writer.writeString(obj.name);
    writer.writeList(obj.sets);
    // Salva una stringa vuota se il gruppo non è noto (mai null su Hive)
    writer.writeString(obj.gruppoMuscolare ?? '');
  }
}

class CompletedSetAdapter extends TypeAdapter<CompletedSet> {
  @override
  final int typeId = 2;

  @override
  CompletedSet read(BinaryReader reader) {
    int reps = reader.readInt();
    double weight = reader.readDouble();
    int timeUnderTension = 0;
    try {
      timeUnderTension = reader.readInt();
    } catch (_) {}
    
    return CompletedSet(
      reps: reps,
      weight: weight,
      timeUnderTension: timeUnderTension,
    );
  }

  @override
  void write(BinaryWriter writer, CompletedSet obj) {
    writer.writeInt(obj.reps);
    writer.writeDouble(obj.weight);
    writer.writeInt(obj.timeUnderTension);
  }
}
