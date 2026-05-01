import 'package:hive/hive.dart';

class BiometricRecord {
  final DateTime date;
  final double weight;
  final double abdomen;
  final double biceps;
  final double chest;
  final double? waist;
  final double? thigh;

  BiometricRecord({
    required this.date,
    required this.weight,
    required this.abdomen,
    required this.biceps,
    required this.chest,
    this.waist,
    this.thigh,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weight': weight,
    'abdomen': abdomen,
    'biceps': biceps,
    'chest': chest,
    'waist': waist,
    'thigh': thigh,
  };

  factory BiometricRecord.fromJson(Map<String, dynamic> json) => BiometricRecord(
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    abdomen: (json['abdomen'] as num?)?.toDouble() ?? 0.0,
    biceps: (json['biceps'] as num?)?.toDouble() ?? 0.0,
    chest: (json['chest'] as num?)?.toDouble() ?? 0.0,
    waist: (json['waist'] as num?)?.toDouble(),
    thigh: (json['thigh'] as num?)?.toDouble(),
  );
}

class BiometricRecordAdapter extends TypeAdapter<BiometricRecord> {
  @override
  final int typeId = 4;

  @override
  BiometricRecord read(BinaryReader reader) {
    return BiometricRecord(
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      weight: reader.readDouble(),
      abdomen: reader.readDouble(),
      biceps: reader.readDouble(),
      chest: reader.readDouble(),
      waist: reader.readDouble(),
      thigh: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, BiometricRecord obj) {
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeDouble(obj.weight);
    writer.writeDouble(obj.abdomen);
    writer.writeDouble(obj.biceps);
    writer.writeDouble(obj.chest);
    writer.writeDouble(obj.waist ?? 0.0);
    writer.writeDouble(obj.thigh ?? 0.0);
  }
}
