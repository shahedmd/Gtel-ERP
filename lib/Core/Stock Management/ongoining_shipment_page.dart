import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import '../../Menubar and Navigation/app_pages.dart';
import '../../Permission/permission_button.dart';
import '../Core Utils/activity_logger.dart';

class _ShipmentScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class OnGoingShipmentsPage extends StatelessWidget {
  OnGoingShipmentsPage({super.key});

  final ShipmentController _ctrl = Get.find<ShipmentController>();

  // Local state — page-level only, no StatefulWidget needed
  final RxInt _currentPage = 1.obs;
  final RxString _searchQuery = ''.obs;
  static const int _pageSize = 15;

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _ShipmentAppBar(),
      floatingActionButton: _ExportPdfButton(ctrl: _ctrl),
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }

        if (_ctrl.aggregatedList.isEmpty) {
          return const _EmptyState();
        }

        // Search filter
        final filtered =
            _searchQuery.value.isEmpty
                ? _ctrl.aggregatedList
                : _ctrl.aggregatedList.where((p) {
                  final q = _searchQuery.value.toLowerCase();
                  return p.model.toLowerCase().contains(q) ||
                      p.name.toLowerCase().contains(q);
                }).toList();

        // Pagination
        final total = filtered.length;
        final totalPages = (total / _pageSize).ceil().clamp(1, 999);

        if (_currentPage.value > totalPages) {
          _currentPage.value = totalPages;
        }

        final start = (_currentPage.value - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, total);
        final paged = filtered.isEmpty ? [] : filtered.sublist(start, end);

        return Column(
          children: [
            // Search bar
            _SearchBar(
              isMobile: isMobile,
              onChanged: (v) {
                _searchQuery.value = v;
                _currentPage.value = 1;
              },
            ),

            // Table / Cards
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 12 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    paged.isEmpty
                        ? _NoSearchResults(query: _searchQuery.value)
                        : isMobile
                        ? _MobileCards(products: paged)
                        : _DesktopTable(
                          products: paged,
                          vScroll: _vScroll,
                          hScroll: _hScroll,
                        ),
              ),
            ),

            // Pagination
            if (total > 0)
              _PaginationFooter(
                isMobile: isMobile,
                total: total,
                start: start,
                end: end,
                currentPage: _currentPage,
                totalPages: totalPages,
                onPrev: () {
                  if (_currentPage.value > 1) _currentPage.value--;
                },
                onNext: () {
                  if (_currentPage.value < totalPages) _currentPage.value++;
                },
              ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AppBar
// ─────────────────────────────────────────────────────────────
class _ShipmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.inventory_rounded, color: Color(0xFF0F172A), size: 24),
          SizedBox(width: 10),
          Text(
            'Incoming Inventory',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Export PDF Button — canView permission লাগবে
// ─────────────────────────────────────────────────────────────
class _ExportPdfButton extends StatelessWidget {
  final ShipmentController ctrl;

  const _ExportPdfButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return PermissionButton(
      route: Routes.shipment,
      type: PermissionType.canView,
      child: FloatingActionButton.extended(
        onPressed: () async {
          await ctrl.generateAggregatedOnWayPdf();
          await ActivityLogger.log(
            action: 'EXPORT_SHIPMENT_PDF',
            module: 'Shipment',
            details: 'Exported incoming inventory PDF',
          );
        },
        icon: const Icon(Icons.picture_as_pdf, size: 22, color: Colors.white),
        label: const Text(
          'Export PDF',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        elevation: 4,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final bool isMobile;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.isMobile, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        0,
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search by model or product name...',
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Table
// ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List products;
  final ScrollController vScroll;
  final ScrollController hScroll;

  const _DesktopTable({
    required this.products,
    required this.vScroll,
    required this.hScroll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 960 ? constraints.maxWidth : 960.0;

        return ScrollConfiguration(
          behavior: _ShipmentScrollBehavior(),
          child: Scrollbar(
            controller: vScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: vScroll,
              child: Scrollbar(
                controller: hScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: _HeaderText('MODEL')),
                              Expanded(
                                flex: 4,
                                child: _HeaderText('PRODUCT NAME'),
                              ),
                              Expanded(
                                flex: 2,
                                child: _HeaderText('TOTAL QTY'),
                              ),
                              Expanded(
                                flex: 4,
                                child: _HeaderText('SHIPMENT BREAKDOWN'),
                              ),
                            ],
                          ),
                        ),
                        // Rows
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return _DesktopRow(product: p);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopRow extends StatelessWidget {
  final dynamic product;

  const _DesktopRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              product.model,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                product.name,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
          Expanded(flex: 2, child: _TotalQtyBadge(qty: product.totalQty)),
          Expanded(
            flex: 4,
            child: _BreakdownList(details: product.incomingDetails),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mobile Cards
// ─────────────────────────────────────────────────────────────
class _MobileCards extends StatelessWidget {
  final List products;

  const _MobileCards({required this.products});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = products[index];
        return _MobileCard(product: p);
      },
    );
  }
}

class _MobileCard extends StatelessWidget {
  final dynamic product;

  const _MobileCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                _TotalQtyBadge(qty: product.totalQty),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                const Text(
                  'SHIPMENT BREAKDOWN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _BreakdownList(details: product.incomingDetails),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pagination Footer
// ─────────────────────────────────────────────────────────────
class _PaginationFooter extends StatelessWidget {
  final bool isMobile;
  final int total;
  final int start;
  final int end;
  final RxInt currentPage;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PaginationFooter({
    required this.isMobile,
    required this.total,
    required this.start,
    required this.end,
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            if (!isMobile)
              Text(
                'Showing ${start + 1} to $end of $total shipments',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentPage.value > 1 ? onPrev : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Page ${currentPage.value} of $totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentPage.value < totalPages ? onNext : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets — const করা
// ─────────────────────────────────────────────────────────────
class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TotalQtyBadge extends StatelessWidget {
  final int qty;

  const _TotalQtyBadge({required this.qty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '$qty',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
          fontSize: 14,
        ),
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  final List details;

  const _BreakdownList({required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          details.map<Widget>((detail) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail.shipmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 12,
                    width: 1,
                    color: const Color(0xFFCBD5E1),
                  ),
                  Text(
                    DateFormat('MMM dd').format(detail.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 12,
                    width: 1,
                    color: const Color(0xFFCBD5E1),
                  ),
                  Text(
                    '${detail.qty} pcs',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty / No Results states
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Shipments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All incoming inventory has been received.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  final String query;

  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No shipments match "$query"',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}