/// 사용자 프로필
/// REST: GET/PUT /users/me/profile (API-04, API-05)
class UserProfile {
  final String? userId;
  final String nickname;
  final int age;
  final String gender; // MALE / FEMALE / OTHER
  final double heightCm; // 50.0 ~ 300.0
  final double weightKg; // 10.0 ~ 500.0
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    this.userId,
    required this.nickname,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'age': age,
        'gender': gender,
        'heightCm': heightCm,
        'weightKg': weightKg,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String?,
        nickname: json['nickname'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String? ?? '',
        heightCm: (json['heightCm'] as num).toDouble(),
        weightKg: (json['weightKg'] as num).toDouble(),
        profileImageUrl: json['profileImageUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  UserProfile copyWith({
    String? nickname,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
  }) =>
      UserProfile(
        userId: userId,
        nickname: nickname ?? this.nickname,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        profileImageUrl: profileImageUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
