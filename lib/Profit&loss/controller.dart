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
  final String id; // Phone for Customers, Name/ID for Debtors
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

  double get totalSale => invoices.fold(0, (sumv, item) => sumv + item.sale);
  double get totalProfit => invoices.fold(0, (sumv, item) => sumv + item.profit);
}

class ProfitLossController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = false.obs;
  var selectedDate = DateTime.now().obs;

  // Master Lists (All Data)
  var allCustomers = <GroupedEntity>[];
  var allDebtors = <GroupedEntity>[];

  // Filtered Lists (For Display)
  var customerList = <GroupedEntity>[].obs;
  var debtorList = <GroupedEntity>[].obs;

  var searchText = "".obs;

  @override
  void onInit() {
    super.onInit();
    fetchMonthlyData();

    // Listen to search changes with debounce
    debounce(
      searchText,
      (_) => _applySearch(),
      time: const Duration(milliseconds: 500),
    );
  }

  void search(String query) {
    searchText.value = query;
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
    allCustomers.clear();
    allDebtors.clear();

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
      // ---------------------------------------------
      // 1. FETCH CUSTOMER ORDERS (Collection Group)
      // ---------------------------------------------
      // Path: customers/{PHONE}/orders/{INVOICE_ID}
      QuerySnapshot custSnap =
          await _db
              .collectionGroup('orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      Map<String, GroupedEntity> cMap = {};

      for (var doc in custSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // 1. EXTRACT PHONE FROM PATH
        // doc.reference.parent.parent?.id gives the Customer Phone Number
        String phoneId = doc.reference.parent.parent?.id ?? "Unknown";

        // 2. CALCULATE SALE AMOUNT (Crucial Fix)
        // Check 'paymentDetails' first, then fallback to 'totalAmount'
        double saleAmount = 0.0;
        if (data['paymentDetails'] != null && data['paymentDetails'] is Map) {
          double paid =
              double.tryParse(data['paymentDetails']['totalPaid'].toString()) ??
              0.0;
          double due =
              double.tryParse(data['paymentDetails']['due'].toString()) ?? 0.0;
          saleAmount = paid + due;
        } else {
          // Fallback if structure differs
          saleAmount = double.tryParse(data['totalAmount'].toString()) ?? 0.0;
        }

        // 3. NAME RESOLUTION
        // If name isn't in the order doc, use the Phone ID as a placeholder
        String name = data['customerName'] ?? "Customer: $phoneId";

        if (!cMap.containsKey(phoneId)) {
          cMap[phoneId] = GroupedEntity(
            id: phoneId,
            name: name,
            phone: phoneId,
            isDebtor: false,
          );
        }

        cMap[phoneId]!.invoices.add(
          SaleInvoice(
            invoiceId: data['invoiceId'] ?? doc.id,
            sale: saleAmount,
            cost: double.tryParse(data['costAmount'].toString()) ?? 0.0,
            profit: double.tryParse(data['profit'].toString()) ?? 0.0,
            date: (data['timestamp'] as Timestamp).toDate(),
          ),
        );
      }
      allCustomers = cMap.values.toList();

      // ---------------------------------------------
      // 2. FETCH DEBTOR ORDERS
      // ---------------------------------------------
      QuerySnapshot debtSnap =
          await _db
              .collection('debtorProfitLoss')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      Map<String, GroupedEntity> dMap = {};

      for (var doc in debtSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Use debtorName as Key if ID is missing
        String dName = data['debtorName'] ?? "Unknown Debtor";
        String dId =
            data['debtorId'] ?? dName; // Fallback to name if ID missing
        String dPhone = data['debtorPhone'] ?? "N/A"; // Handle missing phone

        if (!dMap.containsKey(dId)) {
          dMap[dId] = GroupedEntity(
            id: dId,
            name: dName,
            phone: dPhone,
            isDebtor: true,
          );
        }

        dMap[dId]!.invoices.add(
          SaleInvoice(
            invoiceId: data['invoiceId'] ?? doc.id,
            // For debtors, your structure HAS 'saleAmount' top-level
            sale: double.tryParse(data['saleAmount'].toString()) ?? 0.0,
            cost: double.tryParse(data['costAmount'].toString()) ?? 0.0,
            profit: double.tryParse(data['profit'].toString()) ?? 0.0,
            date: (data['timestamp'] as Timestamp).toDate(),
          ),
        );
      }
      allDebtors = dMap.values.toList();

      // Apply initial lists
      _applySearch();
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch data: $e");
      print(e);
    } finally {
      isLoading.value = false;
    }
  }

  void _applySearch() {
    String q = searchText.value.toLowerCase();

    if (q.isEmpty) {
      customerList.assignAll(allCustomers);
      debtorList.assignAll(allDebtors);
    } else {
      customerList.assignAll(
        allCustomers
            .where(
              (e) =>
                  e.name.toLowerCase().contains(q) ||
                  e.phone.contains(q) ||
                  e.id.contains(q),
            )
            .toList(),
      );

      debtorList.assignAll(
        allDebtors
            .where(
              (e) =>
                  e.name.toLowerCase().contains(q) ||
                  e.phone.contains(q) ||
                  e.id.toLowerCase().contains(q),
            )
            .toList(),
      );
    }
  }
}
