class LoanRequestModel {
  final int id;
  final int userId;
  final int assetId;
  final int quantity;
  final String purpose;
  final String loanDate;
  final String dueDate;
  final String status;
  final String adminNotes;
  final String createdAt;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String userProfileImage;
  final String assetName;
  final String assetCategory;
  final String approvedByName;
  final String approvedAt;
  final String returnedAt;

  const LoanRequestModel({
    required this.id,
    required this.userId,
    required this.assetId,
    required this.quantity,
    required this.purpose,
    required this.loanDate,
    required this.dueDate,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userProfileImage,
    required this.assetName,
    required this.assetCategory,
    required this.approvedByName,
    required this.approvedAt,
    required this.returnedAt,
  });

  factory LoanRequestModel.fromJson(Map<String, dynamic> json) {
    return LoanRequestModel(
      id: int.tryParse(json["id"].toString()) ?? 0,
      userId: int.tryParse(json["user_id"].toString()) ?? 0,
      assetId: int.tryParse(json["asset_id"].toString()) ?? 0,
      quantity: int.tryParse(json["quantity"].toString()) ?? 0,
      purpose: (json["purpose"] ?? "").toString(),
      loanDate: (json["loan_date"] ?? "").toString(),
      dueDate: (json["due_date"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
      adminNotes: (json["admin_notes"] ?? "").toString(),
      createdAt: (json["created_at"] ?? "").toString(),
      userName: (json["user_name"] ?? "").toString(),
      userEmail: (json["user_email"] ?? "").toString(),
      userPhone: (json["user_phone"] ?? "").toString(),
      userProfileImage: (json["user_profile_image"] ?? "").toString(),
      assetName: (json["asset_name"] ?? "").toString(),
      assetCategory: (json["asset_category"] ?? "").toString(),
      approvedByName: (json["approved_by_name"] ?? "").toString(),
      approvedAt: (json["approved_at"] ?? "").toString(),
      returnedAt: (json["returned_at"] ?? "").toString(),
    );
  }
}
