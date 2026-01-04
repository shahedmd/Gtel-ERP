// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller.dart';

class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  // We use ProductController because it holds the 'serviceLogs' and API logic
  // based on the previous update.
  final ProductController controller = Get.find<ProductController>();

  @override
  void initState() {
    super.initState();
    // Fetch fresh logs when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchServiceLogs();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Service Center & Damage Log",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () => controller.fetchServiceLogs(),
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Logs",
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.build_circle_outlined),
                    text: "Active Service",
                  ),
                  Tab(
                    icon: Icon(Icons.broken_image_outlined),
                    text: "Damage History",
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_buildServiceList(), _buildDamageList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // TAB 1: SERVICE LIST
  // ==================================================
  Widget _buildServiceList() {
    return Obx(() {
      if (controller.isActionLoading.value && controller.serviceLogs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Filter for 'service' type
      final services =
          controller.serviceLogs.where((e) => e['type'] == 'service').toList();

      if (services.isEmpty) {
        return _buildEmptyState(
          Icons.check_circle_outline,
          "All Clear",
          "No products currently in service.",
        );
      }

      // Calculate Summary
      final totalQty = services.fold<int>(0, (sum, item) {
        return item['status'] == 'active'
            ? sum + (int.tryParse(item['qty'].toString()) ?? 0)
            : sum;
      });

      return Column(
        children: [
          _buildSummaryHeader("Items currently pending repair", totalQty),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final item = services[index];
                final bool isActive = item['status'] == 'active';
                final int id = item['id'];
                final int qty = int.tryParse(item['qty'].toString()) ?? 0;
                final double cost =
                    double.tryParse(item['return_cost'].toString()) ?? 0.0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          isActive
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      isActive
                                          ? Colors.orange.shade100
                                          : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.build,
                                    color:
                                        isActive
                                            ? Colors.orange[800]
                                            : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['model'] ?? 'Unknown Model',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(item['created_at']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isActive
                                          ? Colors.orange.shade200
                                          : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                isActive ? "Pending" : "Returned",
                                style: TextStyle(
                                  color:
                                      isActive
                                          ? Colors.orange[800]
                                          : Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Quantity: $qty",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Unit Value: ${cost.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (isActive)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Get.defaultDialog(
                                    title: "Confirm Return",
                                    middleText:
                                        "Return ${item['model']} (Qty: $qty) back to Local Stock?",
                                    textConfirm: "Yes, Return",
                                    textCancel: "Cancel",
                                    confirmTextColor: Colors.white,
                                    buttonColor: Colors.green,
                                    onConfirm: () {
                                      Get.back(); // Close dialog
                                      controller.returnFromService(id);
                                    },
                                  );
                                },
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text("Return Stock"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  // ==================================================
  // TAB 2: DAMAGE LIST
  // ==================================================
  Widget _buildDamageList() {
    return Obx(() {
      if (controller.isActionLoading.value && controller.serviceLogs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Filter for 'damage' type
      final damages =
          controller.serviceLogs.where((e) => e['type'] == 'damage').toList();

      if (damages.isEmpty) {
        return _buildEmptyState(
          Icons.sentiment_satisfied_alt,
          "No Damage",
          "Great! No damaged items recorded.",
        );
      }

      // Calculate Total Loss
      final totalLoss = damages.fold<double>(0.0, (sum, item) {
        int q = int.tryParse(item['qty'].toString()) ?? 0;
        double c = double.tryParse(item['return_cost'].toString()) ?? 0.0;
        return sum + (q * c);
      });

      return Column(
        children: [
          _buildSummaryHeader(
            "Total Loss Value: ${totalLoss.toStringAsFixed(2)} BDT",
            null,
            isError: true,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: damages.length,
              itemBuilder: (context, index) {
                final item = damages[index];
                final int qty = int.tryParse(item['qty'].toString()) ?? 0;
                final double cost =
                    double.tryParse(item['return_cost'].toString()) ?? 0.0;
                final double totalItemLoss = qty * cost;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    tileColor: Colors.red.shade50.withOpacity(0.3),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Icon(Icons.delete_forever, color: Colors.red[800]),
                    ),
                    title: Text(
                      item['model'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(item['created_at'])),
                          const SizedBox(height: 2),
                          Text(
                            "Loss: $qty x $cost = ${totalItemLoss.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "-$qty",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  // ==================================================
  // HELPER WIDGETS
  // ==================================================
  Widget _buildSummaryHeader(String title, int? count, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: isError ? Colors.red[50] : Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.warning_amber : Icons.info_outline,
            size: 18,
            color: isError ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            count != null ? "$title: $count" : title,
            style: TextStyle(
              color: isError ? Colors.red[900] : Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
