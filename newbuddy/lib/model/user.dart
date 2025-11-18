class UserModel {
  final String id;
  final String name;
  final String gender;
  final int age;
  final String preference;

  const UserModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.preference,
  });

  factory UserModel.fromJson (Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    gender: json['gender'] ?? '',
    age: json['age'] ?? 0,
    preference: json['preference'] ?? '',
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'age': age,
    'preference': preference,
  };
}
