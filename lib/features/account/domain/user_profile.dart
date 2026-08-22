class UserProfile {
  const UserProfile({required this.fullName, required this.phone});
  final String? fullName;
  final String? phone;
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
  );
}
