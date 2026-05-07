import 'package:hive/hive.dart';

class BiometricRecord {
  final DateTime date;
  final double weight;
  final double hips;
  final double biceps;
  final double chest;
  final double? waist;
  final double? thigh;
  final double? calf;
  final double? neck;
  final double? wrist;

  BiometricRecord({
    required this.date,
    required this.weight,
    required this.hips,
    required this.biceps,
    required this.chest,
    this.waist,
    this.thigh,
    this.calf,
    this.neck,
    this.wrist,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weight': weight,
    'fianchi': hips,
    'biceps': biceps,
    'chest': chest,
    'waist': waist,
    'thigh': thigh,
    'polpaccio': calf,
    'collo': neck,
    'polso': wrist,
  };

  factory BiometricRecord.fromJson(Map<String, dynamic> json) => BiometricRecord(
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    hips: (json['hips'] as num?)?.toDouble() ?? 0.0,
    biceps: (json['biceps'] as num?)?.toDouble() ?? 0.0,
    chest: (json['chest'] as num?)?.toDouble() ?? 0.0,
    waist: (json['waist'] as num?)?.toDouble(),
    thigh: (json['thigh'] as num?)?.toDouble(),
    calf: (json['calf'] as num?)?.toDouble(),
    neck: (json['neck'] as num?)?.toDouble(),
    wrist: (json['wrist'] as num?)?.toDouble(),
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
      hips: reader.readDouble(),
      biceps: reader.readDouble(),
      chest: reader.readDouble(),
      waist: reader.readDouble(),
      thigh: reader.readDouble(),
      calf: reader.readDouble(),
      neck: reader.readDouble(),
      wrist: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, BiometricRecord obj) {
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeDouble(obj.weight);
    writer.writeDouble(obj.hips);
    writer.writeDouble(obj.biceps);
    writer.writeDouble(obj.chest);
    writer.writeDouble(obj.waist ?? 0.0);
    writer.writeDouble(obj.thigh ?? 0.0);
    writer.writeDouble(obj.calf ?? 0.0);
    writer.writeDouble(obj.neck ?? 0.0);
    writer.writeDouble(obj.wrist ?? 0.0);
  }
}
