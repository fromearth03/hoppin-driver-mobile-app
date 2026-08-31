class DriverProfile {
  final String id;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? dateOfBirth;
  final String? avatarUrl;

  /// Null until the driver has been rated at all. The server sends null
  /// rather than 5.0 deliberately, so an unrated driver is never shown a
  /// score they did not earn.
  final double? rating;
  final int ratingCount;

  const DriverProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.avatarUrl,
    this.rating,
    this.ratingCount = 0,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        avatarUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      );
}
