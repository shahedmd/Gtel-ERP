import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import '../stock_controller.dart';
import 'Service/service_constatnts.dart';

enum ServiceTab { active, damage }
class ServiceController extends GetxController {
  final ProductController prodCtrl = Get.find<ProductController>();

  // ── Pagination ─────────────────────────────────────────────────────────────
  final RxInt activePage = 1.obs;
  final RxInt damagePage = 1.obs;

  // ── Loading proxy (avoids leaking ProductController into widgets) ──────────
  bool get isLoading => prodCtrl.isActionLoading.value;

  // ── Derived lists (recomputed only when serviceLogs changes) ───────────────
  List<Map<String, dynamic>> get activeServices =>
      prodCtrl.serviceLogs.where((e) => e['type'] == 'service').toList();

  List<Map<String, dynamic>> get damageLogs =>
      prodCtrl.serviceLogs.where((e) => e['type'] == 'damage').toList();

  // ── Paginated slices ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> paginatedList(ServiceTab tab) =>
      _slice(_source(tab), _page(tab).value);

  List<Map<String, dynamic>> _slice(List<Map<String, dynamic>> src, int page) {
    final start = (page - 1) * AppLayout.pageSize;
    if (start >= src.length) return [];
    return src.sublist(
      start,
      (start + AppLayout.pageSize).clamp(0, src.length),
    );
  }

  // ── Pagination helpers ─────────────────────────────────────────────────────
  int totalPages(ServiceTab tab) =>
      ((_source(tab).length / AppLayout.pageSize).ceil()).clamp(1, 9999);

  int currentPage(ServiceTab tab) => _page(tab).value;

  int totalCount(ServiceTab tab) => _source(tab).length;

  void nextPage(ServiceTab tab) {
    final p = _page(tab);
    if (p.value < totalPages(tab)) p.value++;
  }

  void prevPage(ServiceTab tab) {
    final p = _page(tab);
    if (p.value > 1) p.value--;
  }

  // ── Aggregate stats ────────────────────────────────────────────────────────
  int get activePendingQty => activeServices
      .where((e) => e['status'] == 'active')
      .fold(0, (sum, e) => sum + _parseInt(e['qty']));

  double get totalDamageLoss => damageLogs.fold(0.0, (sum, e) {
    final qty = _parseInt(e['qty']);
    final cost = _parseDouble(e['return_cost']);
    return sum + qty * cost;
  });

  // ── Actions ────────────────────────────────────────────────────────────────
  @override
  Future<void> refresh() => prodCtrl.fetchServiceLogs();

  Future<void> returnStock(int logId, int qty) =>
      prodCtrl.returnFromService(logId, qty);

  // ── Private helpers ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _source(ServiceTab tab) =>
      tab == ServiceTab.active ? activeServices : damageLogs;

  RxInt _page(ServiceTab tab) =>
      tab == ServiceTab.active ? activePage : damagePage;

  static int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _parseDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Defer until the first frame so the widget tree is ready.
    SchedulerBinding.instance.addPostFrameCallback((_) => refresh());
  }
}
