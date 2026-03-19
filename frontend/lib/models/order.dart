class OrderItem {
  final int? id;
  final int productId;
  final String productName;
  final double price;
  final int quantity;

  OrderItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'],
        productId: json['product_id'],
        productName: json['product_name'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
      );
}

class Order {
  final int id;
  final String customerName;
  final String customerPhone;
  final String? customerFb;
  final String status;
  final double total;
  final String? note;
  final List<OrderItem> items;
  final String? createdAt;
  final String? updatedAt;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.customerFb,
    required this.status,
    required this.total,
    this.note,
    required this.items,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        customerName: json['customer_name'] ?? '',
        customerPhone: json['customer_phone'] ?? '',
        customerFb: json['customer_fb'],
        status: json['status'] ?? 'chua_tao_don',
        total: (json['total'] ?? 0).toDouble(),
        note: json['note'],
        items: (json['items'] as List?)
                ?.map((i) => OrderItem.fromJson(i))
                .toList() ??
            [],
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
      );

  String get statusLabel {
    switch (status) {
      case 'chua_tao_don':
        return 'Chưa tạo đơn';
      case 'da_tao_don':
        return 'Đã tạo đơn';
      case 'da_hoan_thanh':
        return 'Đã hoàn thành';
      default:
        return status;
    }
  }
}
