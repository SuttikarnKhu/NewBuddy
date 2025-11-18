class UserModel {
  final String uid;
  final String name;
  final String email;
  final String token;
  final String createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.token,
    required this.createdAt,
  });

  factory UserModel.fromJson (Map<String, dynamic> json) => UserModel(
    uid: json['uid'],
    name: json['name'],
    email: json['email'],
    token: json['token'],
    createdAt: json['createdAt'],
  );
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'token': token,
    'createdAt': createdAt,
  };
}
