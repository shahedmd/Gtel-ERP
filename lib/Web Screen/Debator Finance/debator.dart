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

  // 1. Defined Scroll Controller for Pagination
  final ScrollController _scrollController = ScrollController();

  // 2. Defined Search Controller to check if search is active
  final TextEditingController _searchController = TextEditingController();

  // Professional ERP Theme
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }

  void _onScroll() {
    // If we are at the bottom of the list...
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // FIX: Check our local _searchController.
      // We only load more if the user is NOT searching.
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
              // Initial Loading State
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
                // Add +1 to item count to show the loading spinner at the bottom
                itemCount:
                    controller.filteredBodies.length +
                    (controller.hasMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  // If we are at the very last item...
                  if (index == controller.filteredBodies.length) {
                    // Show Loader if fetching more, or nothing if done
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

  // --- TOP HEADER (Title, Search & Add) ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
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
          // Search Bar
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: bgGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              controller: _searchController, // FIX: Attached Controller Here
              onChanged: (val) {
                controller.searchDebtors(val);
              },
              decoration: const InputDecoration(
                hintText: "Search by Name, Phone, or NID...",
                prefixIcon: Icon(Icons.search, size: 20, color: textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Add Debtor Button
          ElevatedButton.icon(
            onPressed: () => adddebatorDialog(controller),
            icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
            label: const Text(
              "New Debtor",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLE HEADER ---
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
              "NID / Identity",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Address",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
          SizedBox(width: 60), // Space for Actions
        ],
      ),
    );
  }

  // --- DATA ROW ---
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
              // Name & Description
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
              // Phone
              Expanded(
                flex: 2,
                child: Text(
                  debtor.phone,
                  style: const TextStyle(color: darkSlate),
                ),
              ),
              // NID
              Expanded(
                flex: 2,
                child: Text(
                  debtor.nid,
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
              ),
              // Address
              Expanded(
                flex: 3,
                child: Text(
                  debtor.address,
                  style: const TextStyle(color: textMuted, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Created At
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
              // Arrow Icon
              const SizedBox(
                width: 60,
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

  // --- EMPTY STATE ---
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
