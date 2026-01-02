import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class SaleInvoice {
  final String invoiceId;
  final double sale;
  final double cost;
  final double profit;
  final DateTime date;

  SaleInvoice({
    required this.invoiceId,
    required this.sale,
    required this.cost,
    required this.profit,
    required this.date,
  });
}

class GroupedEntity {
  final String id;
  final String name;
  final String phone;
  final bool isDebtor;
  List<SaleInvoice> invoices = [];

  GroupedEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.isDebtor,
  });

  double get totalSale => invoices.fold(0, (sum, item) => sum + item.sale);
  double get totalProfit => invoices.fold(0, (sum, item) => sum + item.profit);
}

class ProfitLossController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = false.obs;
  var selectedDate = DateTime.now().obs;

  var customerList = <GroupedEntity>[].obs;
  var debtorList = <GroupedEntity>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchMonthlyData();
  }

  void changeMonth(int increment) {
    selectedDate.value = DateTime(
      selectedDate.value.year,
      selectedDate.value.month + increment,
      1,
    );
    fetchMonthlyData();
  }

  Future<void> fetchMonthlyData() async {
    isLoading.value = true;

    DateTime start = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      1,
    );
    DateTime end = DateTime(
      selectedDate.value.year,
      selectedDate.value.month + 1,
      0,
      23,
      59,
      59,
    );

    try {
      // 1. Fetch Customer Orders (Sub-collections)
      QuerySnapshot custSnap =
          await _db
              .collectionGroup('orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      // 2. Fetch Debtor Orders
      QuerySnapshot debtSnap =
          await _db
              .collection('debtorProfitLoss')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      Map<String, GroupedEntity> cMap = {};
      Map<String, GroupedEntity> dMap = {};

      // PROCESS CUSTOMERS
      for (var doc in custSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // This is the trick: Get the Phone number from the document path
        // Path is: customers/{PHONE}/orders/{ORDER_ID}
        String customerIdFromPath = doc.reference.parent.parent!.id;

        // If 'customerName' is not inside the order, use the Phone as the name
        String displayName =
            data['customerName'] ?? "Customer: $customerIdFromPath";

        cMap.putIfAbsent(
          customerIdFromPath,
          () => GroupedEntity(
            id: customerIdFromPath,
            name: displayName,
            phone: customerIdFromPath,
            isDebtor: false,
          ),
        );

        cMap[customerIdFromPath]!.invoices.add(
          SaleInvoice(
            invoiceId: data['invoiceId'] ?? 'N/A',
            sale: (data['totalAmount'] ?? 0).toDouble(),
            cost: (data['costAmount'] ?? 0).toDouble(),
            profit: (data['profit'] ?? 0).toDouble(),
            date: (data['timestamp'] as Timestamp).toDate(),
          ),
        );
      }

      // PROCESS DEBTORS
      for (var doc in debtSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String dId = data['debtorId'] ?? "Unknown";

        dMap.putIfAbsent(
          dId,
          () => GroupedEntity(
            id: dId,
            name: data['debtorName'] ?? "Agent: $dId",
            phone: data['debtorPhone'] ?? "",
            isDebtor: true,
          ),
        );

        dMap[dId]!.invoices.add(
          SaleInvoice(
            invoiceId: data['invoiceId'] ?? 'N/A',
            sale: (data['saleAmount'] ?? 0).toDouble(),
            cost: (data['costAmount'] ?? 0).toDouble(),
            profit: (data['profit'] ?? 0).toDouble(),
            date: (data['timestamp'] as Timestamp).toDate(),
          ),
        );
      }

      customerList.assignAll(cMap.values.toList());
      debtorList.assignAll(dMap.values.toList());
    } catch (e) {
      print("Error fetching data: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
