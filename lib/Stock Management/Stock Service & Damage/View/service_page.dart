import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Pdf/service_pdf_generator.dart';
import '../Service/service_constatnts.dart';
import '../Service_widgets/service_tab.dart';
import '../service_controller.dart';


class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage>
    with SingleTickerProviderStateMixin {
  late final TabController    _tabController;
  late final ServiceController _ctrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ctrl = Get.put(ServiceController());
  }

  @override
  void dispose() {
    _tabController.dispose();
    Get.delete<ServiceController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < AppLayout.mobileBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: _buildAppBar(isMobile),
      body: TabBarView(
        controller: _tabController,
        children: [
          ServiceTabContent(tab: ServiceTab.active, ctrl: _ctrl, isMobile: isMobile),
          ServiceTabContent(tab: ServiceTab.damage, ctrl: _ctrl, isMobile: isMobile),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.darkSlate),
      title: Row(
        children: [
          Icon(Icons.handyman, color: AppColors.darkSlate, size: isMobile ? 22 : 26),
          const SizedBox(width: 10),
          Text(
            'Service & Damage Log',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.darkSlate,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
        ],
      ),
      actions: [
        _PrintMenu(ctrl: _ctrl),
        IconButton(
          onPressed: _ctrl.refresh,
          icon: const Icon(Icons.refresh, color: AppColors.slateGrey),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.activeAccent,
        unselectedLabelColor: AppColors.slateGrey,
        indicatorColor: AppColors.activeAccent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.build_circle_outlined),   text: 'Active Service'),
          Tab(icon: Icon(Icons.broken_image_outlined), text: 'Damage History'),
        ],
      ),
    );
  }
}

// ─── Print popup (extracted to keep build() readable) ────────────────────────
class _PrintMenu extends StatelessWidget {
  const _PrintMenu({required this.ctrl});
  final ServiceController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return PopupMenuButton<String>(
        icon: const Icon(Icons.print, color: AppColors.activeAccent),
        tooltip: 'Download Report',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (type) => ServicePdfGenerator.generate(
          reportType: type,
          logs: ctrl.prodCtrl.serviceLogs,
        ),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'service',
            child: _MenuItem(icon: Icons.build,        color: Colors.orange, label: 'Print Service Report'),
          ),
          PopupMenuItem(
            value: 'damage',
            child: _MenuItem(icon: Icons.broken_image, color: Colors.red,    label: 'Print Damage Report'),
          ),
        ],
      );
    });
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color    color;
  final String   label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      );
}