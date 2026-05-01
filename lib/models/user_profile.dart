import 'package:hive/hive.dart';

class UserProfile {
  final String name;
  final DateTime dateOfBirth;
  final double height;
  /// 'M' = Maschio, 'F' = Femmina, null = non specificato
  final String? sesso;

  UserProfile({
    required this.name,
    required this.dateOfBirth,
    required this.height,
    this.sesso,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'height': height,
    'sesso': sesso,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? '') ?? DateTime.now(),
    height: (json['height'] as num?)?.toDouble() ?? 0.0,
    sesso: json['sesso'] as String?,
  );
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 3;

  @override
  UserProfile read(BinaryReader reader) {
    final name        = reader.readString();
    final dateOfBirth = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final height      = reader.readDouble();
    // Retrocompatibile: i vecchi profili non hanno il campo sesso
    String? sesso;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) sesso = s;
    } catch (_) {}
    return UserProfile(
      name: name,
      dateOfBirth: dateOfBirth,
      height: height,
      sesso: sesso,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer.writeString(obj.name);
    writer.writeInt(obj.dateOfBirth.millisecondsSinceEpoch);
    writer.writeDouble(obj.height);
    writer.writeString(obj.sesso ?? '');
  }
}
