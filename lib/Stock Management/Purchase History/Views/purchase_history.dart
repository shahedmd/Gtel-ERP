import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Widgets/ph_header.dart';
import '../Widgets/ph_records.dart';
import '../Widgets/ph_summary_stripe.dart';
import '../purchase_controller.dart';
import '../widgets/ph_filter_bar.dart';
import '../widgets/ph_pagination_bar.dart';
import 'ph_tokens.dart';


class GlobalPurchasePage extends StatelessWidget {
  GlobalPurchasePage({super.key});

  final _ctrl = Get.put(GlobalPurchaseHistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PHTokens.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          PHFilterBar(ctrl: _ctrl),
          PHSummaryStrip(ctrl: _ctrl),
          const PHTableHeader(),
          const Divider(height: 1, color: PHTokens.slate200),
          Expanded(child: PHRecordsList(ctrl: _ctrl)),
          PHPaginationBar(ctrl: _ctrl),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: PHTokens.slate900,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Row(
        children: [
          Icon(Icons.history_edu_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text(
            'Purchase & Payment History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        Obx(() {
          if (_ctrl.isPdfLoading.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return TextButton.icon(
            onPressed: _ctrl.downloadBulkPdf,
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.white70,
              size: 17,
            ),
            label: const Text(
              'Export PDF',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          );
        }),
        const SizedBox(width: 8),
      ],
    );
  }
}
