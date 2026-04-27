// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';

import 'addsalary.dart';
import 'controller.dart';
import 'model.dart';
import 'Staffpage.dart'
    show
        showResignDialog,
        showSuspendDialog,
        kBlue,
        kDarkSlate,
        kGreen,
        kOrange,
        kRed,
        kTextMuted,
        kBonusGold;

class StaffDetailsPage extends StatelessWidget {
  final String staffId;
  final String name;

  StaffDetailsPage({super.key, required this.staffId, required this.name});

  final controller = Get.find<StaffController>();


  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 720;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(context, mobile),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBlue,
        onPressed: () => addSalaryDialog(controller, staffId, name),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Transaction',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context, mobile),
            const SizedBox(height: 20),
            _buildStatusCard(context),
            const SizedBox(height: 24),
            const Text(
              'Ledger History',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            _buildSuspensionHistory(),
            const SizedBox(height: 14),
            _buildHistoryTable(mobile),
            const SizedBox(height: 80), // FAB clearance
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool mobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'Employee: $name',
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _showEditDialog(context),
          icon: const Icon(Icons.edit, color: kBlue),
          tooltip: 'Edit',
        ),
        if (!mobile)
          TextButton.icon(
            onPressed: () => _handlePdfDownload(staffId),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              size: 14,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Export',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        // Actions menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF111827)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onSelected: (val) => _onMenuAction(context, val),
          itemBuilder: (_) {
            final staff = controller.staffList.firstWhereOrNull(
              (s) => s.id == staffId,
            );
            return [
              if (mobile)
                const PopupMenuItem(
                  value: 'export',
                  child: _MenuRow(
                    Icons.picture_as_pdf,
                    'Export PDF',
                    Colors.redAccent,
                  ),
                ),
              if (staff?.isSuspended == true)
                const PopupMenuItem(
                  value: 'lift',
                  child: _MenuRow(Icons.lock_open, 'Lift Suspension', kGreen),
                ),
              if (staff?.isActive == true)
                const PopupMenuItem(
                  value: 'suspend',
                  child: _MenuRow(
                    Icons.pause_circle_outline,
                    'Suspend Staff',
                    kOrange,
                  ),
                ),
              if (staff?.isActive == true || staff?.isSuspended == true)
                const PopupMenuItem(
                  value: 'resign',
                  child: _MenuRow(Icons.exit_to_app, 'Mark as Resigned', kRed),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: _MenuRow(Icons.delete_outline, 'Delete Staff', kRed),
              ),
            ];
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _onMenuAction(BuildContext context, String val) {
    final staff = controller.staffList.firstWhereOrNull((s) => s.id == staffId);
    switch (val) {
      case 'export':
        _handlePdfDownload(staffId);
        break;
      case 'lift':
        controller.liftSuspension(staffId, name);
        break;
      case 'suspend':
        showSuspendDialog(controller, staffId, name, staff?.salary ?? 0);
        break;
      case 'resign':
        showResignDialog(controller, staffId, name);
        break;
      case 'delete':
        Get.defaultDialog(
          title: 'Delete Staff',
          titleStyle: const TextStyle(color: kRed, fontWeight: FontWeight.bold),
          middleText: 'Permanently remove $name? This cannot be undone.',
          textConfirm: 'Delete',
          textCancel: 'Cancel',
          confirmTextColor: Colors.white,
          buttonColor: kRed,
          onConfirm: () => controller.deleteStaff(staffId, name),
        );
        break;
    }
  }

  // ── Info + Stat Cards ───────────────────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, bool mobile) {
    return Obx(() {
      final staff = controller.staffList.firstWhereOrNull(
        (s) => s.id == staffId,
      );
      if (staff == null) return const SizedBox.shrink();

      return StreamBuilder<List<SalaryModel>>(
        stream: controller.streamSalaries(staffId),
        builder: (context, snapshot) {
          double totalPaid = 0;
          double totalBonus = 0;
          if (snapshot.hasData) {
            for (var item in snapshot.data!) {
              if (item.type == 'SALARY' || item.type == null) {
                totalPaid += item.amount;
              } else if (item.type == 'BONUS') {
                totalBonus += item.amount;
              }
            }
          }

          final stats = [
            _StatData(
              'Base Salary',
              'Tk ${staff.salary}',
              FontAwesomeIcons.moneyBillWave,
              kBlue,
            ),
            _StatData(
              'Current Debt',
              'Tk ${staff.currentDebt.toStringAsFixed(0)}',
              FontAwesomeIcons.handHoldingDollar,
              staff.currentDebt > 0 ? kRed : kGreen,
            ),
            _StatData(
              'Total Salary Paid',
              'Tk ${totalPaid.toStringAsFixed(0)}',
              FontAwesomeIcons.wallet,
              Colors.orange,
            ),
            _StatData(
              'Total Bonus Paid',
              'Tk ${totalBonus.toStringAsFixed(0)}',
              FontAwesomeIcons.gift,
              kBonusGold,
            ),
          ];

          if (mobile) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: stats.map((s) => _StatCard(data: s)).toList(),
            );
          }
          return Row(
            children:
                stats
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _StatCard(data: s),
                        ),
                      ),
                    )
                    .toList()
                  ..last = Expanded(child: _StatCard(data: stats.last)),
          );
        },
      );
    });
  }

  Widget _buildStatusCard(BuildContext context) {
    return Obx(() {
      final staff = controller.staffList.firstWhereOrNull(
        (s) => s.id == staffId,
      );
      if (staff == null || staff.isActive) return const SizedBox.shrink();

      Color color;
      IconData icon;
      String title;
      String subtitle;

      if (staff.isResigned) {
        color = kRed;
        icon = Icons.exit_to_app;
        title = 'Staff has Resigned';
        subtitle =
            staff.resignDate != null
                ? 'Effective: ${DateFormat("dd MMM yyyy").format(staff.resignDate!)}'
                : '';
        if (staff.resignReason?.isNotEmpty == true) {
          subtitle += '\nReason: ${staff.resignReason}';
        }
      } else {
        color = kOrange;
        icon = Icons.pause_circle_outline;
        title = 'Staff is Currently Suspended';
        subtitle =
            'Salary deductions will be applied for suspension months. Check suspension history below.';
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (staff.isSuspended)
              TextButton(
                onPressed: () => controller.liftSuspension(staffId, name),
                child: Text(
                  'Lift Suspension',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    });
  }

  // ── Suspension History ──────────────────────────────────────────────────────
  Widget _buildSuspensionHistory() {
    return StreamBuilder<List<SuspensionModel>>(
      stream: controller.streamSuspensions(staffId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final suspensions = snapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kOrange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pause_circle_outline,
                      color: kOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Suspension Records',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: kOrange,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${suspensions.length} record(s)',
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ...suspensions.map((s) => _buildSuspensionRow(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuspensionRow(SuspensionModel s) {
    return Obx(() {
      final staff = controller.staffList.firstWhereOrNull(
        (st) => st.id == staffId,
      );
      final base = staff?.salary ?? 0;
      final adjusted = s.adjustedSalary(base);
      final deduction = s.deductionAmount(base);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.month,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kDarkSlate,
                    ),
                  ),
                  Text(
                    s.reason.isEmpty ? 'No reason provided' : s.reason,
                    style: const TextStyle(color: kTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${s.days} day(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kOrange,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '-Tk ${NumberFormat.decimalPattern().format(deduction.ceil())}',
                  style: const TextStyle(color: kRed, fontSize: 11),
                ),
                Text(
                  'Payable: Tk ${NumberFormat.decimalPattern().format(adjusted.ceil())}',
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ── Transaction History Table ───────────────────────────────────────────────
  Widget _buildHistoryTable(bool mobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          if (!mobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: const BoxDecoration(
                color: kDarkSlate,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: _HTxt('Date')),
                  Expanded(flex: 2, child: _HTxt('Type')),
                  Expanded(flex: 2, child: _HTxt('Month/Ref')),
                  Expanded(flex: 3, child: _HTxt('Note')),
                  Expanded(flex: 2, child: _HTxt('Amount')),
                  SizedBox(width: 80),
                ],
              ),
            ),
          StreamBuilder<List<SalaryModel>>(
            stream: controller.streamSalaries(staffId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No transaction history found.')),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (context, index) {
                  final t = snapshot.data![index];
                  return mobile
                      ? _MobileTransactionCard(
                        t: t,
                        onDelete: () => _confirmDelete(t),
                      )
                      : _DesktopTransactionRow(
                        t: t,
                        staffId: staffId,
                        controller: controller,
                        onDelete: () => _confirmDelete(t),
                      );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SalaryModel t) {
    Get.defaultDialog(
      title: 'Confirm Deletion',
      middleText:
          'Delete this record?\n\nAdvance/Repayment deletions will automatically reverse the debt balance.',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        try {
          final staffRef = controller.db.collection('staff').doc(staffId);
          await controller.db.runTransaction((transaction) async {
            final snap = await transaction.get(staffRef);
            if (snap.exists) {
              double debt =
                  (snap.data() as Map)['currentDebt']?.toDouble() ?? 0.0;
              if (t.type == 'ADVANCE') {
                transaction.update(staffRef, {'currentDebt': debt - t.amount});
              } else if (t.type == 'REPAYMENT') {
                transaction.update(staffRef, {'currentDebt': debt + t.amount});
              }
            }
            transaction.delete(staffRef.collection('salaries').doc(t.id));
          });
          await controller.loadStaff();
          Get.back();
          Get.snackbar(
            'Deleted',
            'Record removed successfully.',
            snackPosition: SnackPosition.BOTTOM,
          );
        } catch (e) {
          Get.back();
          Get.snackbar('Error', 'Failed to delete: $e');
        }
      },
    );
  }

  Future<void> _handlePdfDownload(String staffId) async {
    try {
      final staff = controller.staffList.firstWhere((s) => s.id == staffId);
      final transactions = await controller.streamSalaries(staffId).first;
      final Uint8List pdfData = await controller.generateProfessionalPDF(
        staff,
        transactions,
      );
      final ts = DateTime.now().millisecondsSinceEpoch;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'Ledger_${staff.name.replaceAll(' ', '_')}_$ts.pdf',
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not generate PDF: $e');
    }
  }

  void _showEditDialog(BuildContext context) {
    final staff = controller.staffList.firstWhereOrNull((s) => s.id == staffId);
    if (staff == null) return;

    final nameC = TextEditingController(text: staff.name);
    final phoneC = TextEditingController(text: staff.phone);
    final nidC = TextEditingController(text: staff.nid);
    final desC = TextEditingController(text: staff.des);
    final salaryC = TextEditingController(text: staff.salary.toString());
    final selectedDate = staff.joiningDate.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: kDarkSlate,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Edit Staff Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _editField(nameC, 'Full Name'),
                      const SizedBox(height: 10),
                      _editField(phoneC, 'Phone'),
                      const SizedBox(height: 10),
                      _editField(nidC, 'NID Number'),
                      const SizedBox(height: 10),
                      _editField(desC, 'Designation'),
                      const SizedBox(height: 10),
                      _editField(
                        salaryC,
                        'Base Salary',
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate.value,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) selectedDate.value = d;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 15,
                                  color: kBlue,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Joining: ${DateFormat("dd MMM yyyy").format(selectedDate.value)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const Spacer(),
                                const Icon(Icons.edit, size: 14, color: kBlue),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        if (nameC.text.isEmpty) return;
                        controller.updateStaff(
                          id: staffId,
                          name: nameC.text,
                          phone: phoneC.text,
                          nid: nidC.text,
                          des: desC.text,
                          salary: int.tryParse(salaryC.text) ?? 0,
                          joinDate: selectedDate.value,
                        );
                      },
                      child: const Text(
                        'Update Details',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _editField(
  TextEditingController c,
  String label, {
  TextInputType type = TextInputType.text,
}) {
  return TextField(
    controller: c,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kBlue, width: 1.5),
      ),
    ),
  );
}

// ── Transaction rows ───────────────────────────────────────────────────────────
class _DesktopTransactionRow extends StatelessWidget {
  final SalaryModel t;
  final String staffId;
  final StaffController controller;
  final VoidCallback onDelete;
  const _DesktopTransactionRow({
    required this.t,
    required this.staffId,
    required this.controller,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = t.type ?? 'SALARY';
    Color typeColor = kBlue;
    Color bgColor = kBlue.withOpacity(0.08);

    if (typeLabel == 'ADVANCE') {
      typeColor = kRed;
      bgColor = kRed.withOpacity(0.08);
    } else if (typeLabel == 'REPAYMENT') {
      typeColor = kGreen;
      bgColor = kGreen.withOpacity(0.08);
    } else if (typeLabel == 'BONUS') {
      typeColor = kBonusGold;
      bgColor = kBonusGold.withOpacity(0.08);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yy').format(t.date),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              t.month,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              t.note.isEmpty ? '-' : t.note,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Tk ${t.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: typeColor,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (typeLabel == 'BONUS')
                  IconButton(
                    icon: const Icon(
                      Icons.download,
                      color: kBonusGold,
                      size: 18,
                    ),
                    tooltip: 'Download Bonus Slip',
                    onPressed: () {
                      final staff = controller.staffList.firstWhere(
                        (s) => s.id == staffId,
                      );
                      controller.downloadBonusSlip(
                        staff,
                        t.amount,
                        t.month,
                        t.note,
                        t.date,
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTransactionCard extends StatelessWidget {
  final SalaryModel t;
  final VoidCallback onDelete;
  const _MobileTransactionCard({required this.t, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final typeLabel = t.type ?? 'SALARY';
    Color typeColor = kBlue;
    if (typeLabel == 'ADVANCE') typeColor = kRed;
    if (typeLabel == 'REPAYMENT') typeColor = kGreen;
    if (typeLabel == 'BONUS') typeColor = kBonusGold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                color: typeColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.month,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  t.note.isEmpty
                      ? DateFormat('dd MMM yy').format(t.date)
                      : t.note,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            'Tk ${t.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: typeColor,
              fontSize: 14,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 18,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: data.color.withOpacity(0.1),
            radius: 18,
            child: FaIcon(data.icon, size: 14, color: data.color),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kDarkSlate,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuRow(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
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
