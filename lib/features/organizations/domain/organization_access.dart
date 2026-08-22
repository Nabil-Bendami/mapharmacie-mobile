class PharmacyOrganization {
  const PharmacyOrganization({
    required this.id,
    required this.name,
    required this.currency,
    required this.locale,
  });
  final String id;
  final String name;
  final String currency;
  final String locale;

  factory PharmacyOrganization.fromJson(Map<String, dynamic> json) =>
      PharmacyOrganization(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: (json['currency'] as String?) ?? 'MAD',
        locale: (json['locale'] as String?) ?? 'fr-MA',
      );
}

class OrganizationAccess {
  const OrganizationAccess({
    required this.membershipId,
    required this.role,
    required this.organization,
  });
  final String membershipId;
  final String role;
  final PharmacyOrganization organization;
}
