// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';
import 'adddebator.dart';
import 'details.dart';

class Debatorpage extends StatefulWidget {
  const Debatorpage({super.key});

  @override
  State<Debatorpage> createState() => _DebatorpageState();
}

class _DebatorpageState extends State<Debatorpage> {
  final DebatorController controller = Get.put(DebatorController());
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_searchController.text.isEmpty) {
        controller.loadBodies(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(),
          _buildTableHead(),
          Expanded(
            child: Obx(() {
              if (controller.isBodiesLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: activeAccent),
                );
              }
              if (controller.filteredBodies.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
                itemCount:
                    controller.filteredBodies.length +
                    (controller.hasMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == controller.filteredBodies.length) {
                    return Obx(
                      () =>
                          controller.isMoreLoading.value
                              ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: activeAccent,
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    );
                  }
                  final debtor = controller.filteredBodies[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: _buildDebtorRow(debtor),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Debtor Management",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                  Text(
                    "Track outstanding balances and credit history",
                    style: TextStyle(fontSize: 14, color: textMuted),
                  ),
                ],
              ),
              const Spacer(),

              // TOTAL PAYABLE (I Owe Them)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total Payable (Purchases)",
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Obx(
                      () => Text(
                        "${bdCurrency.format(controller.totalMarketPayable.value)} ৳",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Print Payable
              IconButton(
                onPressed: () => controller.downloadAllPayablesReport(),
                icon: Icon(Icons.print, color: Colors.orange.shade900),
                tooltip: "Download Payable Report",
                style: IconButton.styleFrom(
                  backgroundColor: bgGrey,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 15),

              // TOTAL DUE (They Owe Me)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total Market Due",
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Obx(
                      () => Text(
                        "${bdCurrency.format(controller.totalMarketOutstanding.value)} ৳",
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Print Due
              IconButton(
                onPressed: () => controller.downloadAllDebtorsReport(),
                icon: const Icon(Icons.print, color: darkSlate),
                tooltip: "Download Total Due Report",
                style: IconButton.styleFrom(
                  backgroundColor: bgGrey,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      controller.searchDebtors(val);
                    },
                    decoration: const InputDecoration(
                      hintText: "Search by Name, Phone, or NID...",
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => adddebatorDialog(controller),
                icon: const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  "New Debtor",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "Customer Name",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Phone",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Current Due",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text(
                "Address",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Join Date",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDebtorRow(dynamic debtor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap:
            () =>
                Get.to(() => Debatordetails(id: debtor.id, name: debtor.name)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                        fontSize: 14,
                      ),
                    ),
                    if (debtor.des.isNotEmpty)
                      Text(
                        debtor.des,
                        style: const TextStyle(color: textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  debtor.phone,
                  style: const TextStyle(color: darkSlate),
                ),
              ),
              Expanded(
                flex: 2,
                child: StreamBuilder<double>(
                  stream: controller.getLiveBalance(debtor.id),
                  initialData: debtor.balance,
                  builder: (context, snapshot) {
                    double bal = snapshot.data ?? 0.0;
                    return Text(
                      "${bdCurrency.format(bal)} ৳",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color:
                            bal > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    debtor.address,
                    style: const TextStyle(color: textMuted, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  debtor.createdAt != null
                      ? DateFormat('dd MMM yyyy').format(debtor.createdAt)
                      : "-",
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.black12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.userSlash,
            size: 60,
            color: textMuted.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            "No debtors found matching your search.",
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
