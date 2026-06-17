import 'package:hive/hive.dart';

class UserProfile {
  final int? id;
  final String name;
  final DateTime dateOfBirth;
  final double height;
  /// 'M' = Maschio, 'F' = Femmina, null = non specificato
  final String? sesso;

  final double? bmi;
  final int? bmr;
  final double? whr;
  final double? acquaLitri;
  final int? proteineMin;
  final int? proteineMax;
  final double? bodyFatPerc;

  UserProfile({
    this.id,
    required this.name,
    required this.dateOfBirth,
    required this.height,
    this.sesso,
    this.bmi,
    this.bmr,
    this.whr,
    this.acquaLitri,
    this.proteineMin,
    this.proteineMax,
    this.bodyFatPerc,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'height': height,
    'sesso': sesso,
    'bmi': bmi,
    'bmr': bmr,
    'whr': whr,
    'acqua_litri': acquaLitri,
    'proteine_min': proteineMin,
    'proteine_max': proteineMax,
    'body_fat_perc': bodyFatPerc,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: (json['id'] as num? ?? json['user_id'] as num?)?.toInt(),
    name: json['name'] as String? ?? 
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
    dateOfBirth: DateTime.tryParse(json['date_of_birth'] as String? ?? json['dateOfBirth'] as String? ?? '') ?? DateTime.now(),
    height: (json['height'] as num? ?? json['altezza'] as num?)?.toDouble() ?? 0.0,
    sesso: json['gender'] as String? ?? json['sesso'] as String?,
    bmi: (json['bmi'] as num?)?.toDouble() ?? 0.0,
    bmr: (json['bmr'] as num?)?.toInt() ?? 0,
    whr: (json['whr'] as num?)?.toDouble() ?? 0.0,
    acquaLitri: (json['acqua_litri'] as num?)?.toDouble() ?? 0.0,
    proteineMin: (json['proteine_min'] as num?)?.toInt() ?? 0,
    proteineMax: (json['proteine_max'] as num?)?.toInt() ?? 0,
    bodyFatPerc: (json['body_fat_perc'] as num?)?.toDouble() ?? 0.0,
  );
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 3;

  // Increment this when adding new fields. Old records without the version
  // byte are treated as schema v0 (all try/catch paths remain in effect).
  static const int _currentSchemaVersion = 1;

  @override
  UserProfile read(BinaryReader reader) {
    // Schema version byte written since v1. Old records start with the id int.
    // We detect v0 by attempting to read an int and checking if it equals 1 (version marker).
    // Since old id values are either -1 or positive user IDs (never exactly 0xFEED),
    // we use a dedicated sentinel: version 1+ records start with the magic value 0xFEED (65261).
    int? id;
    try {
      final firstInt = reader.readInt();
      if (firstInt == 0xFEED) {
        reader.readInt(); // schema version — reserved for future migrations
        final rawId = reader.readInt();
        id = rawId == -1 ? null : rawId;
      } else {
        // v0 record: firstInt IS the id
        id = firstInt == -1 ? null : firstInt;
      }
    } catch (_) {}

    final name        = reader.readString();
    final dateOfBirth = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final height      = reader.readDouble();

    String? sesso;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) sesso = s;
    } catch (_) {}

    return UserProfile(
      id: id,
      name: name,
      dateOfBirth: dateOfBirth,
      height: height,
      sesso: sesso,
      bmi: _readDoubleNullable(reader),
      bmr: _readIntNullable(reader),
      whr: _readDoubleNullable(reader),
      acquaLitri: _readDoubleNullable(reader),
      proteineMin: _readIntNullable(reader),
      proteineMax: _readIntNullable(reader),
      bodyFatPerc: _readDoubleNullable(reader),
    );
  }

  double? _readDoubleNullable(BinaryReader reader) {
    try {
      final val = reader.readDouble();
      return val == -1.0 ? null : val;
    } catch (_) {
      return null;
    }
  }

  int? _readIntNullable(BinaryReader reader) {
    try {
      final val = reader.readInt();
      return val == -1 ? null : val;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    // Magic marker + schema version for forward-compat detection on read
    writer.writeInt(0xFEED);
    writer.writeInt(_currentSchemaVersion);
    writer.writeInt(obj.id ?? -1);
    writer.writeString(obj.name);
    writer.writeInt(obj.dateOfBirth.millisecondsSinceEpoch);
    writer.writeDouble(obj.height);
    writer.writeString(obj.sesso ?? '');
    writer.writeDouble(obj.bmi ?? -1.0);
    writer.writeInt(obj.bmr ?? -1);
    writer.writeDouble(obj.whr ?? -1.0);
    writer.writeDouble(obj.acquaLitri ?? -1.0);
    writer.writeInt(obj.proteineMin ?? -1);
    writer.writeInt(obj.proteineMax ?? -1);
    writer.writeDouble(obj.bodyFatPerc ?? -1.0);
  }
}
