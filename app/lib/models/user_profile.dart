import 'dart:convert';

/// 사용자 프로필 (첫 실행 시 입력)
class UserProfile {
  final String name;
  final double heightCm;
  final double weightKg;
  final int age;
  final String gender; // 'M' / 'F' / ''

  const UserProfile({
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    this.gender = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'gender': gender,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        heightCm: (json['heightCm'] as num).toDouble(),
        weightKg: (json['weightKg'] as num).toDouble(),
        age: json['age'] as int,
        gender: (json['gender'] as String?) ?? '',
      );

  String encode() => jsonEncode(toJson());
  static UserProfile decode(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
