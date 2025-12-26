// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../Sales/controller.dart';



class DailySalesPage extends StatelessWidget {
  final DailySalesController ctrl = Get.put(DailySalesController());

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'BDT ',
  );

  DailySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Daily Sales", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0C2E69),
        elevation: 2,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filePdf, color: Colors.white),
            tooltip: "Download PDF",
            onPressed: () async {
              final pdfData = await ctrl.generatePDF();
              final blob = html.Blob([pdfData], 'application/pdf');
              final url = html.Url.createObjectUrlFromBlob(blob);
              html.AnchorElement(href: url)
                ..setAttribute(
                    "download",
                    "DailySales-${ctrl.selectedDate.value.toLocal().toString().split(' ')[0]}.pdf")
                ..click();
              html.Url.revokeObjectUrl(url);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildFilterBar(context),
                const SizedBox(height: 16),
                _buildMetricsRow(),
                const SizedBox(height: 16),
                Expanded(child: _buildResponsiveContent(context)),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---------------- Filter Bar ----------------
  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3D85),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: ctrl.selectedDate.value,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) ctrl.changeDate(pickedDate);
          },
          icon: const Icon(Icons.date_range, color: Colors.white),
          label: Obx(() => Text(
                DateFormat('dd MMM yyyy').format(ctrl.selectedDate.value),
                style: const TextStyle(color: Colors.white),
              )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => ctrl.filterQuery.value = v,
                    decoration: const InputDecoration(
                      hintText: "Search by customer, note, or type...",
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                Obx(() => ctrl.filterQuery.value.isNotEmpty
                    ? InkWell(
                        onTap: () => ctrl.filterQuery.value = "",
                        child: const Icon(Icons.clear, color: Colors.blueGrey),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3D85),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const FaIcon(FontAwesomeIcons.fileCsv, color: Colors.white, size: 16),
          label: const Text("Export", style: TextStyle(color: Colors.white)),
          onPressed: () {
            ctrl.generatePDF().then((pdfData) {
              final blob = html.Blob([pdfData], 'application/pdf');
              final url = html.Url.createObjectUrlFromBlob(blob);
              html.AnchorElement(href: url)
                ..setAttribute(
                    "download",
                    "DailySales-${ctrl.selectedDate.value.toLocal().toString().split(' ')[0]}.pdf")
                ..click();
              html.Url.revokeObjectUrl(url);
            });
          },
        ),
      ],
    );
  }

  // ---------------- Metrics Row ----------------
  Widget _buildMetricsRow() {
    return Obx(() {
      final total = ctrl.totalSales.value;
      final paid = ctrl.paidAmount.value;
      final debtor = ctrl.debtorPending.value;
      final orders = ctrl.salesList.length;

      return Row(
        children: [
          Expanded(child: _metricCard("Total Sales", currencyFormat.format(total), Icons.show_chart, Colors.blue.shade700)),
          const SizedBox(width: 12),
          Expanded(child: _metricCard("Paid", currencyFormat.format(paid), Icons.attach_money, Colors.green.shade700)),
          const SizedBox(width: 12),
          Expanded(child: _metricCard("Debtor Pending", currencyFormat.format(debtor), Icons.error_outline, Colors.red.shade700, valueColor: Colors.red)),
          const SizedBox(width: 12),
          Expanded(child: _metricCard("Orders", orders.toString(), Icons.receipt_long, Colors.indigo.shade700)),
        ],
      );
    });
  }

  Widget _metricCard(String title, String value, IconData icon, Color bg, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg.withOpacity(0.95), bg.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------------- Responsive Content ----------------
  Widget _buildResponsiveContent(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 900) {
        return _buildDataTableView();
      } else {
        return _buildCardListView();
      }
    });
  }

  List<Map<String, dynamic>> _filteredSales() {
    final query = ctrl.filterQuery.value.trim().toLowerCase();
    if (query.isEmpty) return List<Map<String, dynamic>>.from(ctrl.salesList);

    return ctrl.salesList.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final note = (s['note'] ?? '').toString().toLowerCase();
      final type = (s['customerType'] ?? '').toString().toLowerCase();
      return name.contains(query) || note.contains(query) || type.contains(query);
    }).toList().cast<Map<String, dynamic>>();
  }

  String _getDateString(Map<String, dynamic> sale) {
    final dynamic ts = sale['timestamp'] ?? sale['date'] ?? sale['time'] ?? sale['createdAt'];
    if (ts == null) return "";

    try {
      if (ts is Timestamp) return DateFormat('dd MMM yyyy').format(ts.toDate());
      if (ts is DateTime) return DateFormat('dd MMM yyyy').format(ts);
      if (ts is String) {
        try {
          return DateFormat('dd MMM yyyy').format(DateTime.parse(ts));
        } catch (_) {
          return ts;
        }
      }
      if ((ts as dynamic).toDate != null) {
        final parsed = (ts as dynamic).toDate();
        if (parsed is DateTime) return DateFormat('dd MMM yyyy').format(parsed);
      }
    } catch (_) {
      return ts.toString();
    }

    return ts.toString();
  }

String _formatPaymentMethodSafe(dynamic pmField) {
  if (pmField == null) return "";
  try {
    if (pmField is Map) {
      final type = (pmField['type'] ?? '').toString().toLowerCase();

      if (type == 'bkash' || type == 'nagad') {
        final number = pmField['number'] ?? '';
        return "${type[0].toUpperCase()}${type.substring(1)}: $number";
      } else if (type == 'bank') {
        final bankName = pmField['bankName'] ?? '';
        final branch = pmField['branch'] ?? '';
        final acc = pmField['accountNumber'] ?? '';
        return "Bank: $bankName${branch.isNotEmpty ? ', $branch' : ''}${acc.isNotEmpty ? ', A/C: $acc' : ''}";
      } else if (type == 'cash') {
        return "Cash";
      } else {
        return pmField['type']?.toString() ?? pmField.toString();
      }
    } else if (pmField is String) {
      return pmField;
    } else {
      return pmField.toString();
    }
  } catch (e) {
    return pmField.toString();
  }
}


 Widget _buildDataTableView() {
  final ScrollController hController = ScrollController();

  return Obx(() {
    final rows = _filteredSales();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: Get.height * 0.64,
          child: Scrollbar(
            controller: hController, // ✅ attach controller
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: hController, // ✅ same controller
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFF0C2E69)),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                dataRowHeight: 64,
                columns: const [
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Customer")),
                  DataColumn(label: Text("Type")),
                  DataColumn(label: Text("Amount")),
                  DataColumn(label: Text("Paid")),
                  DataColumn(label: Text("Pending")),
                  DataColumn(label: Text("Payment")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: rows.map((sale) {
                  final amount = (sale['amount'] as num?)?.toDouble() ?? 0.0;
                  final paid = (sale['paid'] as num?)?.toDouble() ?? 0.0;
                  final pending = amount - paid;
                  final pmStr = _formatPaymentMethodSafe(sale['paymentMethod']);

                  return DataRow(cells: [
                    DataCell(Text(_getDateString(sale))),
                    DataCell(Text("${sale['name'] ?? ''} (${sale['customerType'] ?? ''})")),
                    DataCell(Text(sale['customerType'] == 'debtor' ? 'Debtor Sale' : 'Cash Sale')),
                    DataCell(Text(currencyFormat.format(amount))),
                    DataCell(Text(currencyFormat.format(paid))),
                    DataCell(
                      Text(
                        currencyFormat.format(pending),
                        style: TextStyle(color: pending > 0 ? Colors.red : Colors.green),
                      ),
                    ),
                    DataCell(SizedBox(width: 300, child: Text(pmStr, overflow: TextOverflow.ellipsis))),
                    DataCell(Row(children: [
                      IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () {}),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  });
}


  // ---------------- Card List View ----------------
  Widget _buildCardListView() {
    return Obx(() {
      final rows = _filteredSales();

      return Scrollbar(
        thumbVisibility: true,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final sale = rows[i];
            final amount = (sale['amount'] as num?)?.toDouble() ?? 0.0;
            final paid = (sale['paid'] as num?)?.toDouble() ?? 0.0;
            final pending = amount - paid;
            final pmStr = _formatPaymentMethodSafe(sale['paymentMethod']);
            final dateStr = _getDateString(sale);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: sale['customerType'] == 'debtor'
                    ? LinearGradient(colors: [Colors.orange.shade50, Colors.orange.shade100])
                    : LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100]),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                title: Text("${sale['name'] ?? ''} • $dateStr", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 6),
                  Text("Amount: ${currencyFormat.format(amount)}  •  Paid: ${currencyFormat.format(paid)}"),
                  const SizedBox(height: 6),
                  if (pmStr.isNotEmpty) Text("Payment: $pmStr", style: const TextStyle(color: Colors.blueGrey)),
                ]),
                trailing: pending > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text(currencyFormat.format(pending), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      )
                    : null,
                onTap: () {
                  if (sale['customerType'] == 'debtor' && pending > 0) {
                    _showDebtorPaymentDialog(context, sale['name'], pending, sale['paymentMethod']);
                  }
                },
              ),
            );
          },
        ),
      );
    });
  }

  // ---------------- Debtor Payment Dialog ----------------
  void _showDebtorPaymentDialog(BuildContext context, String debtorName, double remaining, Map<String, dynamic>? defaultPayment) {
    final TextEditingController paymentCtrl = TextEditingController();
    final TextEditingController detailsCtrl = TextEditingController();

    final selectedPayment = RxString(defaultPayment != null ? (defaultPayment['type'] ?? "bkash") : "bkash");

    if (defaultPayment != null) {
      if (defaultPayment['type'] == 'bank') {
        detailsCtrl.text = "Bank: ${defaultPayment['bankName'] ?? ''}, Branch: ${defaultPayment['branch'] ?? ''}, A/C: ${defaultPayment['accountNumber'] ?? ''}";
      } else if (defaultPayment['type'] == 'bkash') {
        detailsCtrl.text = defaultPayment['number'] ?? defaultPayment['account'] ?? '';
      } else {
        detailsCtrl.text = defaultPayment['details'] ?? '';
      }
    }

    Get.defaultDialog(
      title: "Debtor Payment",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Remaining: ${currencyFormat.format(remaining)}"),
          const SizedBox(height: 8),
          TextField(
            controller: paymentCtrl,
            decoration: const InputDecoration(
              labelText: "Payment Amount",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Obx(
            () => DropdownButton<String>(
              isExpanded: true,
              value: selectedPayment.value,
              items: ["bkash", "bank", "cash"]
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) selectedPayment.value = v;
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: detailsCtrl,
            decoration: InputDecoration(labelText: "${selectedPayment.value.toUpperCase()} Details"),
          ),
        ],
      ),
      textConfirm: "Pay",
      confirmTextColor: Colors.white,
      onConfirm: () async {
        final payment = double.tryParse(paymentCtrl.text) ?? 0.0;
        if (payment <= 0) return;

        final paymentMethod = <String, dynamic>{};
        paymentMethod['type'] = selectedPayment.value;

        switch (selectedPayment.value.toLowerCase()) {
          case 'bank':
            final parts = detailsCtrl.text.split(',');
            if (parts.length >= 3) {
              paymentMethod['bankName'] = parts[0].replaceAll("Bank:", "").trim();
              paymentMethod['branch'] = parts[1].replaceAll("Branch:", "").trim();
              paymentMethod['accountNumber'] = parts[2].replaceAll("A/C:", "").trim();
            } else {
              paymentMethod['details'] = detailsCtrl.text.trim();
            }
            break;
          case 'bkash':
            paymentMethod['number'] = detailsCtrl.text.trim();
            break;
          case 'cash':
            paymentMethod['details'] = detailsCtrl.text.trim();
            break;
        }

        await ctrl.applyDebtorPayment(debtorName, payment, paymentMethod, date: ctrl.selectedDate.value);
        Get.back();
      },
    );
  }
}
