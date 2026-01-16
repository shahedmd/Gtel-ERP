// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccountOverviewPage extends StatefulWidget {
  const AccountOverviewPage({super.key});

  @override
  State<AccountOverviewPage> createState() => AccountOverviewPageState();
}

class AccountOverviewPageState extends State<AccountOverviewPage> {
  // Firestore Collection Reference
  final CollectionReference _assetsCollection = FirebaseFirestore.instance
      .collection('fixed_assets');

  // --- LOGIC: Add Asset to Firestore ---
  Future<void> _addAsset(String name, String type, double cost) async {
    await _assetsCollection.add({
      'name': name,
      'type': type,
      'cost': cost,
      'date': Timestamp.now(),
    });
  }

  // --- LOGIC: Delete Asset (Optional helper) ---
  Future<void> _deleteAsset(String id) async {
    await _assetsCollection.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    // POS Color Palette
    const bgCol = Color(0xFFF5F7FA); // Light Dashboard Grey
    const darkCol = Color(0xFF1E293B); // Slate Dark
    const primaryCol = Color(0xFF3B82F6); // Professional Blue
    const successCol = Color(0xFF10B981); // Growth Green
    const warningCol = Color(0xFFF59E0B); // Attention Orange
    const dangerCol = Color(0xFFEF4444); // Debt Red

    return Scaffold(
      backgroundColor: bgCol,
      // Simple Professional App Bar
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCOUNTS OVERVIEW',
             
            ),
            Text(
              'Financial Command Center',
              
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: darkCol),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  
                ),
              ],
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. FINANCIAL TILES SECTION (The "POS" Look)
            // ==========================================
            Text(
              "FINANCIAL SNAPSHOT",
              
            ),
            const SizedBox(height: 16),

            // Grid of Financial Cards
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 4 cards wide on desktop, 2 on tablet
                int crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // -- Card 1: Cash In Hand (Placeholder for your calculation page)
                    _buildFinanceTile(
                      title: "Cash In Hand",
                      amount: "\$ 24,500.00",
                      icon: Icons.account_balance_wallet,
                      color: successCol,
                      subtext: "Live from Cash Counter",
                    ),

                    // -- Card 2: Vendor Debt (What you owe)
                    _buildFinanceTile(
                      title: "Vendor Debt",
                      amount: "\$ 4,200.00",
                      icon: Icons.money_off,
                      color: dangerCol,
                      subtext: "3 Invoices Pending",
                    ),

                    // -- Card 3: Debtors (Who owes you)
                    _buildFinanceTile(
                      title: "Debtors (Receivable)",
                      amount: "\$ 1,850.00",
                      icon: Icons.handshake,
                      color: primaryCol,
                      subtext: "Due this month",
                    ),

                    // -- Card 4: Monthly Payroll & Ops
                    _buildFinanceTile(
                      title: "Payroll & Ops",
                      amount: "\$ 8,400.00",
                      icon: Icons.groups,
                      color: warningCol,
                      subtext: "Rent, Salaries, Maint.",
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),

            // ==========================================
            // 2. FIXED ASSETS SECTION (Functional)
            // ==========================================

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      height: 30,
                      width: 4,
                      decoration: BoxDecoration(
                        color: darkCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "FIXED ASSETS REGISTRY",
                      
                    ),
                  ],
                ),

                // Add Button
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text("NEW ASSET"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkCol,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // The Main Asset Panel
            StreamBuilder<QuerySnapshot>(
              stream:
                  _assetsCollection
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text("Connection Error");
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // Calculate Total Asset Value Live
                double totalAssetValue = 0;
                for (var doc in docs) {
                  totalAssetValue += (doc['cost'] as num).toDouble();
                }

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Total Value Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${docs.length} Items Recorded",
                              
                            ),
                            Row(
                              children: [
                                Text(
                                  "TOTAL VALUATION: ",
                                 
                                ),
                                Text(
                                  NumberFormat.simpleCurrency().format(
                                    totalAssetValue,
                                  ),
                                 
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // The Table
                      docs.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(50.0),
                            child: Text(
                              "No assets added yet. Click 'NEW ASSET' to begin.",
                            ),
                          )
                          : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder:
                                (c, i) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade100,
                                ),
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final id = docs[index].id;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: primaryCol,
                                  ),
                                ),
                                title: Text(
                                  data['name'],
                                  
                                ),
                                subtitle: Text(
                                  data['type'].toString().toUpperCase(),
                                  
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      NumberFormat.simpleCurrency().format(
                                        data['cost'],
                                      ),
                                      
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _deleteAsset(id),
                                      tooltip: 'Remove Asset',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                );
              },
            ),

            // Footer Space
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Finance Tile (Professional Card) ---
  Widget _buildFinanceTile({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required String subtext,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white), // Clean look
      ),
      child: Stack(
        children: [
          // Background Decor (Subtle circle)
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: color.withOpacity(0.05),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                     
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  amount,
                  
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtext,
                   
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DIALOG: Add Asset ---
  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Entry Fixed Asset",
              
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(nameCtrl, "Asset Name", Icons.label_outline),
                  const SizedBox(height: 16),
                  _buildTextField(
                    typeCtrl,
                    "Type (e.g. Furniture, Machine)",
                    Icons.category_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    costCtrl,
                    "Total Cost",
                    Icons.attach_money,
                    isNumber: true,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "Cancel",
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty && costCtrl.text.isNotEmpty) {
                    _addAsset(
                      nameCtrl.text,
                      typeCtrl.text,
                      double.tryParse(costCtrl.text) ?? 0.0,
                    );
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Save Entry",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
    );
  }
}
