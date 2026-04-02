// ignore_for_file: avoid_print, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Customer/model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerAnalyticsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- STATE ---
  var isLoading = false.obs;
  var isPdfGenerating = false.obs; // Controls PDF Spinner

  List<CustomerAnalyticsModel> _fetchedData = [];
  List<CustomerAnalyticsModel> _filteredData = [];
  var paginatedList = <CustomerAnalyticsModel>[].obs;

  // Pagination Main Table
  var currentPage = 1.obs;
  var itemsPerPage = 50;
  var totalItems = 0.obs;
  int get totalPages => (totalItems.value / itemsPerPage).ceil();

  var periodTotalSales = 0.0.obs;
  var periodTotalProfit = 0.0.obs;

  final List<String> dateFilterOptions = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'This Year',
    'Custom',
  ];
  var selectedDateFilter = 'This Month'.obs;
  var customStartDate = DateTime.now().obs;
  var customEndDate = DateTime.now().obs;

  final List<String> groupOptions = ['All', 'Wholesale & VIP', 'Agent'];
  var selectedGroup = 'All'.obs;
  var searchQuery = ''.obs;

  // --- CUSTOMER DETAILS PAGE (INVOICE PAGINATION STATE) ---
  var isDetailsLoading = false.obs;
  var isDetailsLoadingMore = false.obs;
  var hasMoreInvoices = true.obs;
  var selectedCustomerInvoices = <Map<String, dynamic>>[].obs;
  var selectedCustomerProfile = Rxn<CustomerAnalyticsModel>();
  DocumentSnapshot? _lastInvoiceDoc;
  final int invoiceLimitPerPage = 20;

  // REPRINTING STATE
  var reprintingInvoiceId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(selectedGroup, (_) => applyLocalFilters());
    ever(searchQuery, (_) => applyLocalFilters());
    generateReport();
  }

  String formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  Future<void> generateReport() async {
    isLoading.value = true;
    _fetchedData.clear();

    try {
      DateTime now = DateTime.now();
      DateTime start;
      DateTime end = now;

      switch (selectedDateFilter.value) {
        case 'Today':
          start = DateTime(now.year, now.month, now.day);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Last 7 Days':
          start = now.subtract(const Duration(days: 7));
          break;
        case 'Last 30 Days':
          start = now.subtract(const Duration(days: 30));
          break;
        case 'This Month':
          start = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          start = DateTime(now.year, 1, 1);
          break;
        case 'Custom':
          start = DateTime(
            customStartDate.value.year,
            customStartDate.value.month,
            customStartDate.value.day,
          );
          end = DateTime(
            customEndDate.value.year,
            customEndDate.value.month,
            customEndDate.value.day,
            23,
            59,
            59,
          );
          break;
        default:
          start = DateTime(now.year, now.month, 1);
      }

      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .get();

      Map<String, CustomerAnalyticsModel> tempMap = {};

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['status'] == 'deleted' || data['status'] == 'cancelled') {
          continue;
        }

        // ==========================================
        // UPDATED: Now grouping by customerName
        // ==========================================
        String name = (data['customerName'] ?? '').toString().trim();
        if (name.isEmpty) name = "Guest";

        String phone = (data['customerPhone'] ?? '').toString().trim();
        if (phone.isEmpty) phone = "Unknown";

        String shop = data['shopName'] ?? '';
        String address =
            data['deliveryAddress'] ?? data['address'] ?? 'No Address';
        String type = data['customerType'] ?? 'WHOLESALE';

        String invoiceId = data['invoiceId'] ?? 'Unknown';
        DateTime docDate = (data['timestamp'] as Timestamp).toDate();

        double saleAmt = double.tryParse(data['grandTotal'].toString()) ?? 0.0;
        double profitAmt = double.tryParse(data['profit'].toString()) ?? 0.0;

        // Group by customerName instead of phone
        if (tempMap.containsKey(name)) {
          var entry = tempMap[name]!;
          entry.totalSales += saleAmt;
          entry.totalProfit += profitAmt;
          entry.orderCount += 1;

          // If a customer was saved without a phone earlier, update if phone is found
          if (entry.phone == 'Unknown' && phone != 'Unknown') {
            entry.phone = phone;
          }

          if (entry.address == 'No Address' && address != 'No Address') {
            entry.address = address;
          }
          if (entry.lastInvoiceDate == null ||
              docDate.isAfter(entry.lastInvoiceDate!)) {
            entry.lastInvoiceId = invoiceId;
            entry.lastInvoiceDate = docDate;
          }
        } else {
          tempMap[name] = CustomerAnalyticsModel(
            name: name,
            phone: phone,
            shopName: shop,
            address: address,
            customerType: type,
            orderCount: 1,
            totalSales: saleAmt,
            totalProfit: profitAmt,
            lastInvoiceId: invoiceId,
            lastInvoiceDate: docDate,
          );
        }
      }

      _fetchedData = tempMap.values.toList();
      applyLocalFilters();
    } catch (e) {
      Get.snackbar("Error", "Analysis Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void applyLocalFilters() {
    String q = searchQuery.value.toLowerCase().trim();

    _filteredData =
        _fetchedData.where((customer) {
          String cType = customer.customerType.toUpperCase();
          if (selectedGroup.value == 'Wholesale & VIP') {
            if (cType != 'WHOLESALE' && cType != 'VIP') return false;
          } else if (selectedGroup.value == 'Agent') {
            if (cType != 'AGENT') return false;
          }

          if (q.isNotEmpty) {
            if (!customer.name.toLowerCase().contains(q) &&
                !customer.phone.toLowerCase().contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

    _filteredData.sort((a, b) => b.totalSales.compareTo(a.totalSales));

    periodTotalSales.value = 0.0;
    periodTotalProfit.value = 0.0;
    for (var item in _filteredData) {
      periodTotalSales.value += item.totalSales;
      periodTotalProfit.value += item.totalProfit;
    }

    totalItems.value = _filteredData.length;
    currentPage.value = 1;
    _updatePagination();
  }

  void _updatePagination() {
    if (_filteredData.isEmpty) {
      paginatedList.clear();
      return;
    }
    int start = (currentPage.value - 1) * itemsPerPage;
    int end = start + itemsPerPage;
    if (end > _filteredData.length) end = _filteredData.length;
    paginatedList.value = _filteredData.sublist(start, end);
  }

  void nextPage() {
    if (currentPage.value < totalPages) {
      currentPage.value++;
      _updatePagination();
    }
  }

  void prevPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
      _updatePagination();
    }
  }

  Future<void> loadCustomerDetails(CustomerAnalyticsModel customer) async {
    isDetailsLoading.value = true;
    selectedCustomerProfile.value = customer;
    selectedCustomerInvoices.clear();
    hasMoreInvoices.value = true;
    _lastInvoiceDoc = null;

    try {
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              // ==========================================
              // UPDATED: Now filtering by customerName
              // ==========================================
              .where('customerName', isEqualTo: customer.name)
              .orderBy('timestamp', descending: true)
              .limit(invoiceLimitPerPage)
              .get();

      if (snap.docs.isNotEmpty) {
        _lastInvoiceDoc = snap.docs.last;
        selectedCustomerInvoices.value =
            snap.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  },
                )
                .toList();
      }

      if (snap.docs.length < invoiceLimitPerPage) {
        hasMoreInvoices.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Could not load invoice history: $e");
    } finally {
      isDetailsLoading.value = false;
    }
  }

  Future<void> loadMoreInvoices() async {
    if (isDetailsLoadingMore.value ||
        !hasMoreInvoices.value ||
        _lastInvoiceDoc == null) {
      return;
    }

    isDetailsLoadingMore.value = true;
    try {
      QuerySnapshot snap =
          await _db
              .collection('sales_orders')
              // ==========================================
              // UPDATED: Now filtering by customerName
              // ==========================================
              .where(
                'customerName',
                isEqualTo: selectedCustomerProfile.value!.name,
              )
              .orderBy('timestamp', descending: true)
              .startAfterDocument(_lastInvoiceDoc!)
              .limit(invoiceLimitPerPage)
              .get();

      if (snap.docs.isNotEmpty) {
        _lastInvoiceDoc = snap.docs.last;
        var newInvoices =
            snap.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  },
                )
                .toList();
        selectedCustomerInvoices.addAll(newInvoices);
      }

      if (snap.docs.length < invoiceLimitPerPage) {
        hasMoreInvoices.value = false;
      }
    } catch (e) {
      print("Error loading more invoices: $e");
    } finally {
      isDetailsLoadingMore.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 1. PDF GENERATION (CUSTOMER DIRECTORY LIST)
  // ----------------------------------------------------------------
  Future<void> downloadPdf() async {
    if (_filteredData.isEmpty) {
      Get.snackbar("Alert", "No data to print. Generate report first.");
      return;
    }

    isPdfGenerating.value = true;

    try {
      final pdf = pw.Document();
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();

      final dataToPrint = _filteredData;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header:
              (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "CUSTOMER DIRECTORY & LATEST ORDER",
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.Text(
                    "G-TEL ERP Solutions",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
              ),
          footer:
              (context) => pw.Column(
                children: [
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "Generated on: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                        style: pw.TextStyle(font: fontRegular, fontSize: 8),
                      ),
                      pw.Text(
                        "Page ${context.pageNumber} of ${context.pagesCount}",
                        style: pw.TextStyle(font: fontRegular, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
          build: (context) {
            return [
              pw.SizedBox(height: 10),

              // TABLE STRUCTURE SHOWING LAST ORDER DATE
              pw.Table.fromTextArray(
                headers: [
                  "Customer Name",
                  "Phone",
                  "Address",
                  "Last Order Date",
                ],
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                },
                data: List<List<dynamic>>.generate(dataToPrint.length, (index) {
                  final item = dataToPrint[index];
                  return [
                    item.name,
                    item.phone,
                    item.address.isEmpty || item.address == 'No Address'
                        ? '-'
                        : item.address,
                    item.lastInvoiceDate != null
                        ? DateFormat(
                          'dd MMM yyyy',
                        ).format(item.lastInvoiceDate!)
                        : 'N/A',
                  ];
                }),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      Get.snackbar("Error", "Could not generate PDF: $e");
    } finally {
      isPdfGenerating.value = false;
    }
  }

  // =================================================================================
  // 3. REPRINT INVOICE FEATURE
  // =================================================================================
  Future<void> reprintInvoice(String invoiceId) async {
    reprintingInvoiceId.value = invoiceId;
    try {
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Error", "Invoice not found in master records.");
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      bool isCond = data['isCondition'] ?? false;
      Map<String, dynamic> payMap = Map<String, dynamic>.from(
        data['paymentDetails'] ?? {},
      );

      if (isCond) {
        payMap['due'] =
            double.tryParse(data['courierDue']?.toString() ?? '0') ?? 0.0;
      } else {
        QuerySnapshot dailySnap =
            await _db
                .collection('daily_sales')
                .where('transactionId', isEqualTo: invoiceId)
                .limit(1)
                .get();

        if (dailySnap.docs.isNotEmpty) {
          var dailyData = dailySnap.docs.first.data() as Map<String, dynamic>;

          double realTimePaid = (dailyData['paid'] as num?)?.toDouble() ?? 0.0;
          List<dynamic> paymentHistory = dailyData['paymentHistory'] ?? [];
          List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
            data['items'] ?? [],
          );
          double subTotal = items.fold(
            0.0,
            (sumv, item) => sumv + (item['subtotal'] ?? 0),
          );
          double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;
          double grandTotal = subTotal - discountVal;
          payMap['paidForInvoice'] = realTimePaid;
          double newDue = grandTotal - realTimePaid;
          payMap['due'] = newDue < 0 ? 0 : newDue;

          payMap.remove('cash');
          payMap.remove('bank');
          payMap.remove('bkash');
          payMap.remove('nagad');
          payMap.remove('bkashNumber');
          payMap.remove('nagadNumber');
          payMap.remove('bankName');
          payMap.remove('accountNumber');

          if (paymentHistory.isNotEmpty) {
            for (var h in paymentHistory) {
              if (h is Map) {
                String type = (h['type'] ?? '').toString().toLowerCase();
                String bankVal = (h['bankName'] ?? '').toString();
                if (type.isEmpty || type == 'cash') {
                  if (bankVal.isNotEmpty) type = 'bank';
                }
                if (type.isEmpty) type = 'cash';

                double amt = (h['amount'] as num?)?.toDouble() ?? 0.0;
                double current =
                    double.tryParse(payMap[type]?.toString() ?? '0') ?? 0.0;
                payMap[type] = current + amt;

                if (h['number'] != null) payMap['${type}Number'] = h['number'];
                if (h['bankName'] != null) payMap['bankName'] = h['bankName'];
                if (h['accountNumber'] != null) {
                  payMap['accountNumber'] = h['accountNumber'];
                }
              }
            }
          } else if (realTimePaid > 0) {
            var pm = dailyData['paymentMethod'];
            if (pm != null && pm is Map) {
              String detectedType = 'cash';
              String valBank = (pm['bankName'] ?? '').toString().trim();
              String valBkash = (pm['bkashNumber'] ?? '').toString().trim();
              String valNagad = (pm['nagadNumber'] ?? '').toString().trim();
              String explicitType =
                  (pm['type'] ?? '').toString().trim().toLowerCase();
              if (valBank.isNotEmpty) {
                detectedType = 'bank';
              } else if (valBkash.isNotEmpty) {
                detectedType = 'bkash';
              } else if (valNagad.isNotEmpty) {
                detectedType = 'nagad';
              } else if (explicitType.isNotEmpty && explicitType != 'cash') {
                detectedType = explicitType;
              }

              payMap[detectedType] = realTimePaid;
              if (pm['number'] != null) {
                payMap['${detectedType}Number'] = pm['number'];
              }
              if (valBank.isNotEmpty) payMap['bankName'] = valBank;
              if (valBkash.isNotEmpty) payMap['bkashNumber'] = valBkash;
              if (valNagad.isNotEmpty) payMap['nagadNumber'] = valNagad;
              if (pm['accountNumber'] != null) {
                payMap['accountNumber'] = pm['accountNumber'];
              }
            } else {
              payMap['cash'] = realTimePaid;
            }
          }
        }
      }

      String name = data['customerName'] ?? "";
      String phone = data['customerPhone'] ?? "";
      String shop = data['shopName'] ?? "";
      String address = data['deliveryAddress'] ?? "";
      String? courier = data['courierName'];
      int cartons = data['cartons'] ?? 0;
      String challan = data['challanNo'] ?? "";
      String packagerName = data['packagerName'] ?? '';
      String savedDiscountNote = data['discountNote'] ?? "";
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        data['items'] ?? [],
      );
      double snapOld = (data['snapshotOldDue'] as num?)?.toDouble() ?? 0.0;
      double snapRun = (data['snapshotRunningDue'] as num?)?.toDouble() ?? 0.0;
      double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;

      DateTime invoiceDate = DateTime.now();
      if (data['timestamp'] != null) {
        try {
          invoiceDate = data['timestamp'].toDate();
        } catch (_) {}
      } else if (data['date'] != null) {
        try {
          invoiceDate = DateTime.parse(data['date'].toString());
        } catch (_) {}
      }

      String sellerName = "Joynal Abedin";
      String sellerPhone = "01720677206";
      if (data['soldBy'] != null) {
        var soldByData = data['soldBy'];
        if (soldByData is Map) {
          sellerName = soldByData['name'] ?? sellerName;
          sellerPhone = soldByData['phone'] ?? sellerPhone;
        } else if (soldByData is String) {
          sellerName = soldByData;
        }
      }

      await _generatePdf(
        data['invoiceId'] ?? invoiceId,
        name,
        phone,
        payMap,
        items,
        isCondition: isCond,
        challan: challan,
        address: address,
        courier: courier,
        cartons: cartons,
        shopName: shop,
        oldDueSnap: snapOld,
        runningDueSnap: snapRun,
        authorizedName: sellerName,
        authorizedPhone: sellerPhone,
        discountNote: savedDiscountNote,
        packagerName: packagerName,
        invoiceDate: invoiceDate,
        discount: discountVal,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not reprint: $e");
    } finally {
      reprintingInvoiceId.value = '';
    }
  }

  // ---------------------------------------------------------------------------
  // ALL PDF BUILDER METHODS NEEDED FOR REPRINTING
  // ---------------------------------------------------------------------------
  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items, {
    required DateTime invoiceDate,
    bool isCondition = false,
    String challan = "",
    String address = "",
    String? courier,
    int? cartons,
    String shopName = "",
    double oldDueSnap = 0.0,
    double runningDueSnap = 0.0,
    required String authorizedName,
    required String authorizedPhone,
    double discount = 0.0,
    String discountNote = "",
    String? packagerName,
  }) async {
    final pdf = pw.Document();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidPrevRun =
        double.tryParse(payMap['paidForPrevRunning'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double totalPaidForInvoice =
        double.tryParse(payMap['paidForInvoice']?.toString() ?? '0') ?? 0.0;

    List<String> methodsUsed = [];
    if ((double.tryParse(payMap['cash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Cash');
    }
    if ((double.tryParse(payMap['bkash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bkash');
    }
    if ((double.tryParse(payMap['nagad']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Nagad');
    }
    if ((double.tryParse(payMap['bank']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bank');
    }

    String paymentMethodsStr =
        methodsUsed.isNotEmpty ? methodsUsed.join(', ') : "None/Credit";

    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );
    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;
    double remainingPrevRunning = runningDueSnap - paidPrevRun;
    if (remainingPrevRunning < 0) remainingPrevRunning = 0;

    double netTotalDue = remainingOldDue + remainingPrevRunning + invDue;
    double totalPreviousBalance = oldDueSnap + runningDueSnap;
    double currentInvTotal = subTotal - discount;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (pw.Context context) => _buildNewFooter(context, regularFont),
        build: (pw.Context context) {
          return [
            _buildNewHeader(
              boldFont,
              regularFont,
              invId,
              "Sales Invoice",
              packagerName,
              authorizedName,
              invDue,
              false,
              null,
              "",
              paymentMethodsStr,
              invoiceDate,
            ),
            _buildNewCustomerBox(
              name,
              address,
              phone,
              shopName,
              regularFont,
              boldFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewTable(items, boldFont, regularFont),
            _buildNewSummary(
              subTotal,
              discount,
              currentInvTotal,
              totalPaidForInvoice,
              paymentMethodsStr,
              items,
              boldFont,
              regularFont,
              discountNote,
            ),
            pw.SizedBox(height: 5),
            _buildNewDues(totalPreviousBalance, netTotalDue, regularFont),
            if (invDue <= 0 && !isCondition)
              _buildPaidStamp(boldFont, regularFont, invoiceDate),
            if (invDue > 0 || isCondition) pw.SizedBox(height: 15),
            _buildWordsBox(currentInvTotal, boldFont),
            pw.SizedBox(height: 40),
            _buildNewSignatures(regularFont),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: (pw.Context context) => _buildNewFooter(context, regularFont),
          build: (context) {
            return [
              _buildNewHeader(
                boldFont,
                regularFont,
                invId,
                "DELIVERY CHALLAN",
                packagerName,
                authorizedName,
                invDue,
                isCondition,
                courier,
                challan,
                paymentMethodsStr,
                invoiceDate,
              ),
              _buildNewCustomerBox(
                name,
                address,
                phone,
                shopName,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 20),
              _buildCourierBox(
                courier,
                challan,
                cartons,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 60),
              _buildChallanCenterBox(boldFont, regularFont, invDue),
              pw.SizedBox(height: 100),
              _buildNewSignatures(regularFont),
            ];
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildNewHeader(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String title,
    String? packager,
    String authorizedName,
    double invDue,
    bool isCondition,
    String? courier,
    String challan,
    String paymentMethodsStr,
    DateTime invoiceDate,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "G TEL",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "6/24A(7th Floor) Gulistan Shopping Complex (Hall Market)\n2 Bangabandu Avenue, Dhaka 1000",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "Cell : 01720677206, 01911026222",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "E-mail : gtel01720677206@gmail.com",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(right: 40),
                child: pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              children: [
                _infoRow("Invoice No.", ": $invId", reg, bold),
                _infoRow(
                  "Date",
                  ": ${DateFormat('dd/MM/yyyy').format(invoiceDate)}",
                  reg,
                  bold,
                ),
                _infoRow("Ref: No", ": ", reg, bold),
                _infoRow(
                  "Prepared/Packged By",
                  ": ${packager ?? 'Admin'}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Entry Time",
                  ": ${DateFormat('h:mm:ss a').format(invoiceDate)}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Bill Type",
                  ": ${invDue <= 0 ? 'PAID' : 'DUE'}",
                  reg,
                  bold,
                ),
                _infoRow("Payment Via", ": $paymentMethodsStr", reg, bold),
                _infoRow("Sales Person", ": $authorizedName", reg, bold),
                if (isCondition) ...[
                  _infoRow("Courier", ": ${courier ?? 'N/A'}", reg, bold),
                  _infoRow("Challan No", ": $challan", reg, bold),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPaidStamp(pw.Font bold, pw.Font reg, DateTime invoiceDate) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 20),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              "P A I D",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              DateFormat('dd MMM yyyy').format(invoiceDate),
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 12,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "G TEL",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildNewCustomerBox(
    String name,
    String address,
    String phone,
    String shopName,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow2("To", ": $name", reg, bold, col1Width: 60),
          _infoRow2("Address", ": $address", reg, bold, col1Width: 60),
          _infoRow2("Contact No.", ": $phone", reg, bold, col1Width: 60),
        ],
      ),
    );
  }

  pw.Widget _infoRow2(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    double col1Width = 75,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: col1Width,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCourierBox(
    String? courier,
    String challan,
    int? cartons,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Courier Information",
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          _infoRow(
            "Courier Name",
            ": ${courier ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Booking/Challan No",
            ": $challan",
            reg,
            bold,
            col1Width: 100,
          ),
          _infoRow(
            "Total Cartons",
            ": ${cartons?.toString() ?? 'N/A'}",
            reg,
            bold,
            col1Width: 100,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNewTable(
    List<Map<String, dynamic>> items,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          children: [
            _th("SL", bold),
            _th("Product Description", bold, align: pw.TextAlign.left),
            _th("Qty", bold),
            _th("Unit Price", bold),
            _th("Amount", bold),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              _td(
                "${item['name']}${item['model'] != null ? ' - ' + item['model'] : ''}",
                reg,
              ),
              _td(item['qty'].toString(), reg, align: pw.TextAlign.center),
              _td(
                double.parse(item['saleRate'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
              _td(
                double.parse(item['subtotal'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildNewSummary(
    double subTotal,
    double discount,
    double currentInvTotal,
    double paidForInvoice,
    String paymentMethodsStr,
    List items,
    pw.Font bold,
    pw.Font reg,
    String discountNote,
  ) {
    int totalQty = items.fold(
      0,
      (sumv, item) => sumv + ((item['qty'] as num?)?.toInt() ?? 0),
    );
    String discountLabel = "Less Discount";
    if (discountNote.isNotEmpty) discountLabel += " ($discountNote)";

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Total Qty : $totalQty",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Narration:",
                    style: pw.TextStyle(font: reg, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                children: [
                  _sumRow(
                    "Total Amount",
                    subTotal.toStringAsFixed(2),
                    bold,
                    reg,
                  ),
                  _sumRow(discountLabel, discount.toStringAsFixed(2), reg, reg),
                  _sumRow("Add VAT", "0.00", reg, reg),
                  _sumRow("Add Extra Charges", "0.00", reg, reg),
                  pw.Divider(thickness: 0.5, height: 8),
                  _sumRow(
                    "Net Payable Amount",
                    currentInvTotal.toStringAsFixed(2),
                    bold,
                    bold,
                  ),
                  pw.SizedBox(height: 2),
                  _sumRow(
                    "Paid Amount",
                    paidForInvoice.toStringAsFixed(2),
                    reg,
                    bold,
                  ),
                  if (paymentMethodsStr != "None/Credit")
                    _sumRow("Payment Method", paymentMethodsStr, reg, reg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNewDues(double prevDue, double netDue, pw.Font reg) {
    return pw.Container(
      width: 200,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        children: [
          _sumRow(
            "Previous Due Amount :",
            prevDue.toStringAsFixed(2),
            reg,
            reg,
          ),
          pw.Divider(thickness: 0.5, height: 5),
          _sumRow("Present Due Amount :", netDue.toStringAsFixed(2), reg, reg),
        ],
      ),
    );
  }

  pw.Widget _buildWordsBox(double currentInvTotal, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        "Taka in word : ${_numberToWords(currentInvTotal)} Only",
        style: pw.TextStyle(font: bold, fontSize: 9),
      ),
    );
  }

  String _numberToWords(double number) {
    if (number == 0) return "Zero";
    int num = number.floor();
    if (num < 0) return "Negative ${_numberToWords(-number)}";

    const units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen",
    ];
    const tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety",
    ];

    String convertLessThanOneThousand(int n) {
      String result = "";
      if (n >= 100) {
        result += "${units[n ~/ 100]} Hundred ";
        n %= 100;
      }
      if (n >= 20) {
        result += "${tens[n ~/ 10]} ";
        n %= 10;
      }
      if (n > 0) result += "${units[n]} ";
      return result;
    }

    String result = "";
    int crore = num ~/ 10000000;
    num %= 10000000;
    int lakh = num ~/ 100000;
    num %= 100000;
    int thousand = num ~/ 1000;
    num %= 1000;
    int remainder = num;

    if (crore > 0) result += "${convertLessThanOneThousand(crore)}Crore ";
    if (lakh > 0) result += "${convertLessThanOneThousand(lakh)}Lakh ";
    if (thousand > 0) {
      result += "${convertLessThanOneThousand(thousand)}Thousand ";
    }
    if (remainder > 0) result += convertLessThanOneThousand(remainder);

    return result.trim();
  }

  pw.Widget _buildNewSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Client Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Goods Delivery/Prepare",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Authorized Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildNewFooter(pw.Context context, pw.Font reg) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            "Terms & Conditions: 1. Goods once sold will not be refunded and changed, 2. Warranty will be void if any sticker removed, physically damaged and burn case, 3. Please keep this invoice/bill for warranty support.",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Sales Billing Software By G TEL : 01720677206",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Print Date & Time : ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildChallanCenterBox(pw.Font bold, pw.Font reg, double due) {
    bool isPaid = due <= 0;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isPaid ? PdfColors.green700 : PdfColors.deepOrange700,
          width: 2,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: isPaid ? PdfColors.green50 : PdfColors.deepOrange50,
      ),
      child: pw.Column(
        children: [
          if (isPaid) ...[
            pw.Text(
              "NON CONDITION",
              style: pw.TextStyle(
                font: bold,
                fontSize: 24,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "+ Courier Charges",
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: PdfColors.green800,
              ),
            ),
          ] else ...[
            pw.Text(
              "CONDITION PAYMENT INSTRUCTION FOR COURIER",
              style: pw.TextStyle(
                font: reg,
                fontSize: 11,
                color: PdfColors.deepOrange800,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "PLEASE COLLECT: ",
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                pw.Text(
                  "BDT ${due.toStringAsFixed(0)}",
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 24,
                    color: PdfColors.deepOrange900,
                  ),
                ),
                pw.Text(
                  " + Courier Charges",
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    double col1Width = 75,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: col1Width,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sumRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(font: labelFont, fontSize: 9),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(value, style: pw.TextStyle(font: valFont, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }
}