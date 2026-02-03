class CustomerAnalyticsModel {
  final String name;
  final String phone;
  final String shopName;
  int orderCount;
  double totalSales;
  double totalProfit;

  CustomerAnalyticsModel({
    required this.name,
    required this.phone,
    required this.shopName,
    this.orderCount = 0,
    this.totalSales = 0.0,
    this.totalProfit = 0.0,
  });
}