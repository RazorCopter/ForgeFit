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
  bool isSynced;

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
    this.isSynced = false,
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
    hips: (json['hips'] as num? ?? json['fianchi'] as num?)?.toDouble() ?? 0.0,
    biceps: (json['biceps'] as num?)?.toDouble() ?? 0.0,
    chest: (json['chest'] as num?)?.toDouble() ?? 0.0,
    waist: (json['waist'] as num?)?.toDouble(),
    thigh: (json['thigh'] as num?)?.toDouble(),
    calf: (json['calf'] as num? ?? json['polpaccio'] as num?)?.toDouble(),
    neck: (json['neck'] as num? ?? json['collo'] as num?)?.toDouble(),
    wrist: (json['wrist'] as num? ?? json['polso'] as num?)?.toDouble(),
  );
}

class BiometricRecordAdapter extends TypeAdapter<BiometricRecord> {
  @override
  final int typeId = 4;

  // Usa -1.0 come sentinel per i campi nullable, coerente con UserProfileAdapter.
  // Record scritti prima di questo fix hanno 0.0 per i campi non inseriti:
  // verranno letti come 0.0 (non null) — comportamento documentato e accettabile.
  double? _readNullable(BinaryReader reader) {
    try {
      final v = reader.readDouble();
      return v == -1.0 ? null : v;
    } catch (_) {
      return null;
    }
  }

  @override
  BiometricRecord read(BinaryReader reader) {
    return BiometricRecord(
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      weight: reader.readDouble(),
      hips: reader.readDouble(),
      biceps: reader.readDouble(),
      chest: reader.readDouble(),
      waist: _readNullable(reader),
      thigh: _readNullable(reader),
      calf: _readNullable(reader),
      neck: _readNullable(reader),
      wrist: _readNullable(reader),
    );
    try {
      record.isSynced = reader.read() as bool? ?? false;
    } catch (_) {}
    return record;
  }

  @override
  void write(BinaryWriter writer, BiometricRecord obj) {
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeDouble(obj.weight);
    writer.writeDouble(obj.hips);
    writer.writeDouble(obj.biceps);
    writer.writeDouble(obj.chest);
    writer.writeDouble(obj.waist ?? -1.0);
    writer.writeDouble(obj.thigh ?? -1.0);
    writer.writeDouble(obj.calf ?? -1.0);
    writer.writeDouble(obj.neck ?? -1.0);
    writer.writeDouble(obj.wrist ?? -1.0);
    writer.write(obj.isSynced);
  }
}
