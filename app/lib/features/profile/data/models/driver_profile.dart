class DriverProfile {
  final String id;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? dateOfBirth;
  final String? avatarUrl;

  const DriverProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.avatarUrl,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        avatarUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
      );
}
