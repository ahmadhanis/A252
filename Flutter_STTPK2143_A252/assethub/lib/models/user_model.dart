class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String profileImage;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.profileImage,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse(json["id"].toString()) ?? 0,
      name: (json["name"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      profileImage: (json["profile_image"] ?? "").toString(),
      createdAt: (json["created_at"] ?? "").toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "role": role,
      "profile_image": profileImage,
      "created_at": createdAt,
    };
  }
}
