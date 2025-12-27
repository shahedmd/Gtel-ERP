import '../Stock/model.dart';

class SalesCartItem {
  final Product product;
  int quantity;
  double priceAtSale;

  SalesCartItem({
    required this.product,
    required this.quantity,
    required this.priceAtSale,
  });

  double get subtotal => priceAtSale * quantity;
}

