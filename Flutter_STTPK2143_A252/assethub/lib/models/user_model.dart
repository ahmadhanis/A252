class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse(json["id"].toString()) ?? 0,
      name: (json["name"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      createdAt: (json["created_at"] ?? "").toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "role": role,
      "created_at": createdAt,
    };
  }
}
