class AssetModel {
  final int id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String description;
  final String image;
  final String createdAt;

  const AssetModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.description,
    required this.image,
    required this.createdAt,
  });

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: int.tryParse(json["id"].toString()) ?? 0,
      name: (json["name"] ?? "").toString(),
      category: (json["category"] ?? "").toString(),
      quantity: int.tryParse(json["quantity"].toString()) ?? 0,
      price: double.tryParse(json["price"].toString()) ?? 0,
      description: (json["description"] ?? "").toString(),
      image: (json["image"] ?? "").toString(),
      createdAt: (json["created_at"] ?? "").toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "category": category,
      "quantity": quantity,
      "price": price,
      "description": description,
      "image": image,
      "created_at": createdAt,
    };
  }
}
