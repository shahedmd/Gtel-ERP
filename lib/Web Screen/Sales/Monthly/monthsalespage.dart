// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'details.dart';
import 'salescontroller.dart';

class MonthlySalesPage extends StatelessWidget {
  MonthlySalesPage({super.key});

  final controller = Get.put(MonthlySalesController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monthly Sales", style: TextStyle(color: Colors.white),),
      centerTitle: true,
      backgroundColor: const Color(0xFF0C2E69),),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.monthlyData.isEmpty) {
          return const Center(child: Text("No sales found"));
        }

        final months = controller.monthlyData.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // latest first

        return ListView.builder(
          itemCount: months.length,
          itemBuilder: (context, index) {
            final key = months[index];
            final data = controller.monthlyData[key]!;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                margin:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Get.to(() => MonthlySalesDetailPage(
              monthKey: key,
              summary: data,
                        ));
                  },
                  child: Padding(
                    padding:  EdgeInsets.all(14.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
              children: [
                 FaIcon(
                  FontAwesomeIcons.calendarDays,
                  size: 18.sp,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatMonth(key),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
                        ),
              
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
              
                        Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.sackDollar,
                  size: 18,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Total",
                  style: TextStyle(fontSize: 14),
                ),
                const Spacer(),
                Text(
                  "৳${data.total.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
                        ),
              
                        const SizedBox(height: 12),
              
                        /// PAID + PENDING
                        Row(
              children: [
                /// PAID
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.circleCheck,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Paid",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "৳${data.paid.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
                const SizedBox(width: 10),
              
                /// PENDING
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.clock,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Pending",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "৳${data.pending.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

          },
        );
      }),
    );
  }

  String _formatMonth(String key) {
    final parts = key.split("-");
    final year = parts[0];
    final month = int.parse(parts[1]);

    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    return "${names[month - 1]} $year";
  }
}
