class Customer {
  final int id;
  final String name;
  final String phone;
  final String facebookLink;
  final String note;
  final String? createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.facebookLink = '',
    this.note = '',
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        facebookLink: json['facebook_link'] ?? '',
        note: json['note'] ?? '',
        createdAt: json['created_at'],
      );
}
