// ignore_for_file: deprecated_member_use, file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'addstaff.dart';
import 'details.dart';
import 'model.dart';

// ── Theme Constants ───────────────────────────────────────────────────────────
const Color kDarkSlate = Color(0xFF111827);
const Color kBlue = Color(0xFF3B82F6);
const Color kBgGrey = Color(0xFFF9FAFB);
const Color kTextMuted = Color(0xFF6B7280);
const Color kBonusGold = Color(0xFFF59E0B);
const Color kGreen = Color(0xFF10B981);
const Color kRed = Color(0xFFEF4444);
const Color kOrange = Color(0xFFF97316);

bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 720;

class StaffListPage extends StatelessWidget {
  final StaffController controller = Get.put(StaffController());

  StaffListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Scaffold(
      backgroundColor: kBgGrey,
      body: Column(
        children: [
          _Header(controller: controller, mobile: mobile),
          _FilterBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: kBlue),
                );
              }
              if (controller.filteredStaffList.isEmpty) {
                return _EmptyState();
              }
              return mobile
                  ? _MobileList(controller: controller)
                  : _DesktopTable(controller: controller);
            }),
          ),
        ],
      ),
      floatingActionButton:
          mobile
              ? FloatingActionButton.extended(
                backgroundColor: kBlue,
                onPressed: () => addStaffDialog(controller),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Member',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : null,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final StaffController controller;
  final bool mobile;
  const _Header({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 24),
      color: Colors.white,
      child: mobile ? _mobileHeader(context) : _desktopHeader(context),
    );
  }

  Widget _desktopHeader(BuildContext context) {
    return Row(
      children: [
        _titleBlock(),
        const Spacer(),
        _reportButtons(context),
        const SizedBox(width: 16),
        _searchBox(),
        const SizedBox(width: 16),
        _addButton(),
      ],
    );
  }

  Widget _mobileHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleBlock(),
        const SizedBox(height: 12),
        _searchBox(fullWidth: true),
        const SizedBox(height: 10),
        Row(
          children: [
            _reportBtn(context, isBonus: false),
            const SizedBox(width: 8),
            _reportBtn(context, isBonus: true),
          ],
        ),
      ],
    );
  }

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Directory',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: kDarkSlate,
          ),
        ),
        Obx(() {
          final total = controller.staffList.fold<int>(
            0,
            (sum, item) => sum + item.salary,
          );
          return Text(
            'Monthly Payroll: Tk ${NumberFormat.decimalPattern().format(total)}',
            style: const TextStyle(
              fontSize: 13,
              color: kBlue,
              fontWeight: FontWeight.bold,
            ),
          );
        }),
      ],
    );
  }

  Widget _reportButtons(BuildContext context) {
    return Row(
      children: [
        _reportBtn(context, isBonus: false),
        const SizedBox(width: 8),
        _reportBtn(context, isBonus: true),
      ],
    );
  }

  // ── আগের code (replace করো) ──
  Widget _reportBtn(BuildContext context, {required bool isBonus}) {
    final color = isBonus ? kBonusGold : Colors.redAccent;
    final icon = isBonus ? FontAwesomeIcons.gift : FontAwesomeIcons.filePdf;
    final label = isBonus ? 'Bonus Report' : 'Payroll Report';
    return OutlinedButton.icon(
      onPressed:
          () =>
              isBonus
                  ? _showBonusPickerDialog(context) // ← bonus-এর নতুন flow
                  : _pickMonthAndDownload(
                    context,
                    false,
                  ), // ← payroll আগের মতোই
      icon: FaIcon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _searchBox({bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 220,
      decoration: BoxDecoration(
        color: kBgGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        onChanged: (val) => controller.searchQuery.value = val,
        decoration: const InputDecoration(
          hintText: 'Search staff...',
          prefixIcon: Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _addButton() {
    return ElevatedButton.icon(
      onPressed: () => addStaffDialog(controller),
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: const Text(
        'Add Member',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kBlue,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _pickMonthAndDownload(BuildContext context, bool isBonus) async {
    DateTime selectedDate = DateTime.now();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isBonus ? 'Select Bonus Month' : 'Select Payroll Month'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBonus
                    ? 'Report includes all bonuses given in selected month.'
                    : 'Report includes all salary payments for selected month.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 280,
                height: 280,
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  onDateChanged: (d) => selectedDate = d,
                  initialCalendarMode: DatePickerMode.year,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBonus ? kBonusGold : kBlue,
              ),
              onPressed: () {
                Get.back();
                final month = DateFormat('MMMM yyyy').format(selectedDate);
                if (isBonus) {
                  controller.downloadMonthlyBonusReport(month);
                } else {
                  controller.downloadMonthlyPayroll(month);
                }
              },
              child: const Text(
                'Download',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBonusPickerDialog(BuildContext context) async {
    // ── Loading দেখাও ──────────────────────────────────────────────────────
    Get.dialog(
      const Center(
        child: Material(
          color: Colors.transparent,
          child: CircularProgressIndicator(color: kBonusGold),
        ),
      ),
      barrierDismissible: false,
    );

    final List<Map<String, dynamic>> months =
        await controller.fetchBonusMonthsSummary();
    Get.back(); // loading বন্ধ

    if (months.isEmpty) {
      Get.snackbar(
        'কোনো Bonus নেই',
        '${DateTime.now().year} সালে কোনো bonus record পাওয়া যায়নি',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final double yearTotal = months.fold(
      0.0,
      (sum, m) => sum + (m['total'] as double),
    );

    // ── Month selection dialog ─────────────────────────────────────────────
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                decoration: const BoxDecoration(
                  color: kBonusGold,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.gift,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bonus Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${DateTime.now().year}  ·  Year Total: Tk ${NumberFormat.decimalPattern().format(yearTotal)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // ─── Subtitle ─────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: kTextMuted),
                    SizedBox(width: 6),
                    Text(
                      'যে মাসের রিপোর্ট চান সেটায় tap করুন',
                      style: TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // ─── Month List ───────────────────────────────────────────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: months.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final Map<String, dynamic> m = months[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Get.back();
                          controller.downloadMonthlyBonusReport(
                            m['month'] as String,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: kBgGrey,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              // ── Icon ────────────────────────────────────
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: kBonusGold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.gift,
                                    size: 16,
                                    color: kBonusGold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // ── Month Name ───────────────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['month'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: kDarkSlate,
                                      ),
                                    ),
                                    const Text(
                                      'PDF download করতে tap করুন',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ── Amount ───────────────────────────────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Tk ${NumberFormat.decimalPattern().format(m['total'])}',
                                    style: const TextStyle(
                                      color: kGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'মোট bonus',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: kTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.download_rounded,
                                color: kBonusGold,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter Bar ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final StaffController controller;
  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip('All', 'all', controller.staffList.length),
              const SizedBox(width: 8),
              _chip('Active', 'active', controller.activeCount, color: kGreen),
              const SizedBox(width: 8),
              _chip(
                'Suspended',
                'suspended',
                controller.suspendedCount,
                color: kOrange,
              ),
              const SizedBox(width: 8),
              _chip(
                'Resigned',
                'resigned',
                controller.resignedCount,
                color: kRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, int count, {Color? color}) {
    return Obx(() {
      final selected = controller.statusFilter.value == value;
      final chipColor = color ?? kDarkSlate;
      return GestureDetector(
        onTap: () => controller.statusFilter.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? chipColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? chipColor : Colors.black12,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : kTextMuted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? Colors.white.withOpacity(0.25)
                          : chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : chipColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Desktop Table ──────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final StaffController controller;
  const _DesktopTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table header
        Container(
          margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: const BoxDecoration(
            color: kDarkSlate,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: _HTxt('Employee')),
              Expanded(flex: 2, child: _HTxt('Designation')),
              Expanded(flex: 2, child: _HTxt('Phone')),
              Expanded(flex: 2, child: _HTxt('Joining Date')),
              Expanded(flex: 1, child: _HTxt('Salary')),
              Expanded(flex: 1, child: _HTxt('Status')),
              SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            itemCount: controller.filteredStaffList.length,
            itemBuilder: (context, i) {
              return _DesktopRow(
                staff: controller.filteredStaffList[i],
                controller: controller,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopRow extends StatelessWidget {
  final StaffModel staff;
  final StaffController controller;
  const _DesktopRow({required this.staff, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isResigned = staff.isResigned;
    return InkWell(
      onTap:
          () => Get.to(
            () => StaffDetailsPage(staffId: staff.id, name: staff.name),
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: isResigned ? const Color(0xFFFFF7F7) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            // Name + avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _Avatar(name: staff.name, status: staff.status),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      staff.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isResigned ? kTextMuted : kDarkSlate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Designation
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  staff.des,
                  style: const TextStyle(
                    color: kBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Phone
            Expanded(
              flex: 2,
              child: Text(
                staff.phone,
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ),
            // Joining date
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd MMM yyyy').format(staff.joiningDate),
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ),
            // Salary
            Expanded(
              flex: 1,
              child: Text(
                'Tk ${staff.salary}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                  fontSize: 13,
                ),
              ),
            ),
            // Status badge
            Expanded(flex: 1, child: _StatusBadge(status: staff.status)),
            // Arrow / menu
            SizedBox(
              width: 48,
              child: _StaffPopupMenu(staff: staff, controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile List ────────────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final StaffController controller;
  const _MobileList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: controller.filteredStaffList.length,
      itemBuilder: (ctx, i) {
        return _MobileCard(
          staff: controller.filteredStaffList[i],
          controller: controller,
        );
      },
    );
  }
}

class _MobileCard extends StatelessWidget {
  final StaffModel staff;
  final StaffController controller;
  const _MobileCard({required this.staff, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            () => Get.to(
              () => StaffDetailsPage(staffId: staff.id, name: staff.name),
            ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(name: staff.name, status: staff.status, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            staff.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kDarkSlate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(status: staff.status, small: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      staff.des,
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff.phone,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tk ${staff.salary} / month',
                      style: const TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StaffPopupMenu(staff: staff, controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String status;
  final double size;
  const _Avatar({required this.name, required this.status, this.size = 38});

  @override
  Widget build(BuildContext context) {
    Color bgColor = kBlue.withOpacity(0.12);
    Color textColor = kBlue;
    if (status == 'suspended') {
      bgColor = kOrange.withOpacity(0.12);
      textColor = kOrange;
    } else if (status == 'resigned') {
      bgColor = kRed.withOpacity(0.10);
      textColor = kRed;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool small;
  const _StatusBadge({required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'suspended':
        color = kOrange;
        label = 'Suspended';
        break;
      case 'resigned':
        color = kRed;
        label = 'Resigned';
        break;
      default:
        color = kGreen;
        label = 'Active';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StaffPopupMenu extends StatelessWidget {
  final StaffModel staff;
  final StaffController controller;
  const _StaffPopupMenu({required this.staff, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: kTextMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (val) => _onAction(context, val),
      itemBuilder:
          (_) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: kBlue),
                  SizedBox(width: 10),
                  Text('View Profile', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (staff.isSuspended)
              const PopupMenuItem(
                value: 'lift',
                child: Row(
                  children: [
                    Icon(Icons.lock_open, size: 16, color: kGreen),
                    SizedBox(width: 10),
                    Text('Lift Suspension', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            if (!staff.isResigned && !staff.isSuspended)
              const PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle_outline, size: 16, color: kOrange),
                    SizedBox(width: 10),
                    Text('Suspend', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            if (!staff.isResigned)
              const PopupMenuItem(
                value: 'resign',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 16, color: kRed),
                    SizedBox(width: 10),
                    Text('Mark as Resigned', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: kRed),
                  SizedBox(width: 10),
                  Text(
                    'Delete Staff',
                    style: TextStyle(fontSize: 13, color: kRed),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  void _onAction(BuildContext context, String action) {
    switch (action) {
      case 'view':
        Get.to(() => StaffDetailsPage(staffId: staff.id, name: staff.name));
        break;
      case 'suspend':
        _showSuspendDialog(context);
        break;
      case 'lift':
        controller.liftSuspension(staff.id, staff.name);
        break;
      case 'resign':
        _showResignDialog(context);
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  void _showSuspendDialog(BuildContext context) =>
      showSuspendDialog(controller, staff.id, staff.name, staff.salary);

  void _showResignDialog(BuildContext context) =>
      showResignDialog(controller, staff.id, staff.name);

  void _showDeleteDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Delete Staff',
      titleStyle: const TextStyle(color: kRed, fontWeight: FontWeight.bold),
      middleText:
          'Are you sure you want to permanently remove ${staff.name} from the system?\n\nThis action cannot be undone.',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: kRed,
      onConfirm: () => controller.deleteStaff(staff.id, staff.name),
    );
  }
}

// ── Resign Dialog ─────────────────────────────────────────────────────────────
void showResignDialog(StaffController controller, String staffId, String name) {
  final reasonC = TextEditingController();
  final Rx<DateTime> resignDate = DateTime.now().obs;

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader('Mark as Resigned', Icons.exit_to_app, kRed, name),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dlgLabel('Resignation Date'),
                    Obx(
                      () => InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: Get.context!,
                            initialDate: resignDate.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) resignDate.value = picked;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kBgGrey,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: kBlue,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat(
                                  'dd MMMM yyyy',
                                ).format(resignDate.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.edit, size: 14, color: kBlue),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _dlgLabel('Reason (Optional)'),
                    TextField(
                      controller: reasonC,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for resignation...',
                        filled: true,
                        fillColor: kBgGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _dialogFooter(
              onCancel: () => Get.back(),
              onConfirm:
                  () => controller.resignStaff(
                    staffId: staffId,
                    name: name,
                    resignDate: resignDate.value,
                    reason: reasonC.text,
                  ),
              confirmLabel: 'Confirm Resignation',
              confirmColor: kRed,
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Suspend Dialog ────────────────────────────────────────────────────────────
void showSuspendDialog(
  StaffController controller,
  String staffId,
  String name,
  int salary,
) {
  final daysC = TextEditingController();
  final reasonC = TextEditingController();
  final selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now()).obs;
  final previewSalary = RxDouble(salary.toDouble());

  void recalc() {
    final d = int.tryParse(daysC.text) ?? 0;
    if (d > 0) {
      try {
        final monthDate = DateFormat('MMMM yyyy').parse(selectedMonth.value);
        final dim = DateTime(monthDate.year, monthDate.month + 1, 0).day;
        previewSalary.value = salary - (salary / dim * d);
      } catch (_) {}
    } else {
      previewSalary.value = salary.toDouble();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(
              'Suspend Staff',
              Icons.pause_circle_outline,
              kOrange,
              name,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dlgLabel('Apply to Month'),
                    InkWell(
                      onTap: () async {
                        DateTime sel = DateTime.now();
                        await showDialog(
                          context: Get.context!,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Select Month'),
                                content: SizedBox(
                                  width: 280,
                                  height: 260,
                                  child: CalendarDatePicker(
                                    initialDate: sel,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    onDateChanged: (d) => sel = d,
                                    initialCalendarMode: DatePickerMode.year,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kOrange,
                                    ),
                                    onPressed: () {
                                      selectedMonth.value = DateFormat(
                                        'MMMM yyyy',
                                      ).format(sel);
                                      recalc();
                                      Get.back();
                                    },
                                    child: const Text(
                                      'Select',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: Obx(
                        () => Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kBgGrey,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: kOrange,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedMonth.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.edit, size: 14, color: kOrange),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dlgLabel('Number of Days Suspended'),
                    TextField(
                      controller: daysC,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => recalc(),
                      decoration: InputDecoration(
                        hintText: 'e.g. 15',
                        prefixIcon: const Icon(
                          Icons.numbers,
                          size: 16,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: kBgGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dlgLabel('Reason'),
                    TextField(
                      controller: reasonC,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Reason for suspension...',
                        filled: true,
                        fillColor: kBgGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Salary preview
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kOrange.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kOrange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Salary Impact Preview',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kTextMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _previewRow(
                              'Base Salary',
                              'Tk ${NumberFormat.decimalPattern().format(salary)}',
                            ),
                            _previewRow(
                              'Deduction (${daysC.text.isEmpty ? '0' : daysC.text} days)',
                              '- Tk ${NumberFormat.decimalPattern().format((salary - previewSalary.value).abs().ceil())}',
                              color: kRed,
                            ),
                            const Divider(height: 16),
                            _previewRow(
                              'Payable This Month',
                              'Tk ${NumberFormat.decimalPattern().format(previewSalary.value.ceil())}',
                              bold: true,
                              color: kGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _dialogFooter(
              onCancel: () => Get.back(),
              onConfirm: () {
                final d = int.tryParse(daysC.text) ?? 0;
                if (d <= 0) {
                  Get.snackbar(
                    'Invalid',
                    'Enter valid suspension days',
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                controller.suspendStaff(
                  staffId: staffId,
                  staffName: name,
                  days: d,
                  month: selectedMonth.value,
                  reason: reasonC.text,
                );
              },
              confirmLabel: 'Apply Suspension',
              confirmColor: kOrange,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _previewRow(
  String label,
  String value, {
  bool bold = false,
  Color? color,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: kTextMuted,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? kDarkSlate,
          ),
        ),
      ],
    ),
  );
}

// ── Shared Dialog Helpers ────────────────────────────────────────────────────
Widget _dialogHeader(
  String title,
  IconData icon,
  Color color,
  String subtitle,
) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Staff: $subtitle',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.white54),
        ),
      ],
    ),
  );
}

Widget _dlgLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: kTextMuted,
        letterSpacing: 0.8,
      ),
    ),
  );
}

Widget _dialogFooter({
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  required String confirmLabel,
  required Color confirmColor,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: kBgGrey)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel', style: TextStyle(color: kTextMuted)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.usersSlash,
            size: 48,
            color: kTextMuted.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No staff members found',
            style: TextStyle(color: kTextMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _HTxt extends StatelessWidget {
  final String text;
  const _HTxt(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    ),
  );
}
