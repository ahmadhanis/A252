class ServiceRequestModel {
  final int id;
  final int userId;
  final String serviceType;
  final String title;
  final String details;
  final String preferredDate;
  final String status;
  final String adminNotes;
  final String createdAt;
  final String updatedAt;
  final String userName;
  final String userEmail;
  final String userPhone;

  const ServiceRequestModel({
    required this.id,
    required this.userId,
    required this.serviceType,
    required this.title,
    required this.details,
    required this.preferredDate,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      serviceType: (json['service_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      preferredDate: (json['preferred_date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      adminNotes: (json['admin_notes'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      userName: (json['user_name'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      userPhone: (json['user_phone'] ?? '').toString(),
    );
  }
}
