// model.dart
class CustomerAnalyticsModel {
  String name;
  String phone;
  String shopName;
  String address;
  String customerType;
  int orderCount;
  double totalSales;
  double totalProfit;
  String? lastInvoiceId;
  DateTime? lastInvoiceDate;

  CustomerAnalyticsModel({
    required this.name,
    required this.phone,
    required this.shopName,
    required this.address,
    required this.customerType,
    required this.orderCount,
    required this.totalSales,
    required this.totalProfit,
    this.lastInvoiceId,
    this.lastInvoiceDate,
  });
}