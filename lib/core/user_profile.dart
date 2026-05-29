class UserProfile {
  final String name;
  final String city;
  final String bio;
  final int age;
  final String favoriteCategory;
  final String telegram;
  final String avatarUrl;

  UserProfile({
    required this.name,
    required this.city,
    required this.bio,
    required this.age,
    required this.favoriteCategory,
    required this.telegram,
    this.avatarUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'bio': bio,
      'age': age,
      'favoriteCategory': favoriteCategory,
      'telegram': telegram,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Новый пользователь',
      city: map['city'] ?? '',
      bio: map['bio'] ?? '',
      age: map['age'] ?? 0,
      favoriteCategory: map['favoriteCategory'] ?? 'LEGO',
      telegram: map['telegram'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }
}