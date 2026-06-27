import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Live%20order/salemodel.dart';

import '../Permission/permission_button.dart';

class LiveOrderSalesPage extends StatelessWidget {
  const LiveOrderSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LiveSalesController());
    final RxString cartSearchQuery = ''.obs;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildTopBar(controller, isDesktop),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildCustomerSection(controller, isDesktop, context),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1, height: 1),
                  const SizedBox(height: 16),
                  _buildExpandedPaymentSection(controller, isDesktop),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child:
                  isDesktop
                      ? SizedBox(
                        height: screenHeight > 800 ? screenHeight * 0.75 : 650,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _productInventoryTable(controller, true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _buildCartSection(
                                controller,
                                cartSearchQuery,
                                true,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Column(
                        children: [
                          _productInventoryTable(controller, false),
                          const SizedBox(height: 16),
                          _buildCartSection(controller, cartSearchQuery, false),
                        ],
                      ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP BAR ---
  Widget _buildTopBar(LiveSalesController controller, bool isDesktop) {
    Widget titleBlock = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Obx(
            () => Icon(
              controller.isConditionSale.value
                  ? Icons.local_shipping
                  : Icons.point_of_sale,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => Text(
                controller.isConditionSale.value
                    ? "CONDITION / COURIER MANAGER"
                    : "POINT OF SALE (POS)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              "Sales & Inventory System",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );

    Widget toggleBlock = Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Obx(
                () => Text(
                  controller.isConditionSale.value
                      ? "Switch to Direct Sale"
                      : "Switch to Condition",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => Switch(
                  value: controller.isConditionSale.value,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.orange.shade300,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey,
                  onChanged: (val) => controller.isConditionSale.value = val,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: controller.refreshPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Page & Clear Data",
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isDesktop ? 0 : 16,
      ),
      height: isDesktop ? 60 : null,
      decoration: BoxDecoration(
        color:
            controller.isConditionSale.value
                ? const Color(0xFFC2410C)
                : const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      child:
          isDesktop
              ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [titleBlock, toggleBlock],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 16), toggleBlock],
              ),
    );
  }

  // --- 2. CUSTOMER SECTION (UPDATED FOR UNIFIED SEARCH) ---
  Widget _buildCustomerSection(
    LiveSalesController controller,
    bool isDesktop,
    BuildContext context,
  ) {
    return Obx(() {
      bool isAgent = controller.customerType.value == "AGENT";

      // Reusable Tabs
      Widget tabsBlock = SizedBox(
        width: isDesktop ? 320 : double.infinity,
        child: Row(
          children:
              ["WHOLESALE", "VIP", "AGENT"].map((type) {
                bool isSelected = controller.customerType.value == type;
                return Expanded(
                  child: InkWell(
                    onTap: () => controller.customerType.value = type,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 40,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      );

      // --- DYNAMIC SEARCH FIELD BLOCK ---
      bool showAgentList = isAgent && controller.filteredDebtors.isNotEmpty;
      bool showRegularList =
          !isAgent && controller.filteredRegularCustomers.isNotEmpty;

      Widget searchFieldBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _erpInput(
            controller.debtorPhoneSearch,
            isAgent
                ? "Search Existing Agent..."
                : "Search Customer by Phone/Name...",
            icon: Icons.search,
            highlight: true,
            fillColor: Colors.yellow.shade50,
          ),
          if (showAgentList || showRegularList)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount:
                    isAgent
                        ? controller.filteredDebtors.length
                        : controller.filteredRegularCustomers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  String cName = "";
                  String cPhone = "";
                  VoidCallback onTap;

                  if (isAgent) {
                    final debtor = controller.filteredDebtors[i];
                    cName = debtor.name;
                    cPhone = debtor.phone;
                    onTap = () {
                      FocusScope.of(context).unfocus();
                      controller.selectDebtorFromDropdown(debtor);
                    };
                  } else {
                    final cust = controller.filteredRegularCustomers[i];
                    cName = cust['name'] ?? 'Unknown';
                    cPhone = cust['phone'] ?? '';
                    onTap = () {
                      FocusScope.of(context).unfocus();
                      controller.selectRegularCustomerFromDropdown(cust);
                    };
                  }

                  return InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Text(
                                cPhone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.grey,
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

      // --- DYNAMIC BADGE BLOCK ---
      Widget badgeBlock;
      if (isAgent) {
        badgeBlock =
            controller.selectedDebtor.value != null
                ? Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "AGENT FOUND",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Previous Due",
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                          Text(
                            "৳${controller.totalPreviousDue.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                : Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "* To create NEW Agent, ignore search and fill info below.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
      } else {
        badgeBlock =
            controller.selectedRegularCustomer.value != null
                ? Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "CUSTOMER FOUND",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                )
                : Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "* To create NEW Customer, ignore search and fill info below.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tabsBlock,
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: searchFieldBlock),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: badgeBlock),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tabsBlock,
                const SizedBox(height: 12),
                searchFieldBlock,
                const SizedBox(height: 8),
                badgeBlock,
              ],
            ),

          const SizedBox(height: 12),

          if (isDesktop)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _erpInput(
                    controller.phoneC,
                    "Phone Number",
                    isNumber: true,
                    highlight: true,
                    icon: Icons.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _erpInput(
                    controller.nameC,
                    "Shop Name",
                    icon: Icons.store,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  flex: 2,
                  child: _erpInput(
                    controller.shopC,
                    "Customer Name",
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _erpInput(
                    controller.addressC,
                    "Address / Location",
                    icon: Icons.location_on,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            )
          else
            Column(
              children: [
                _erpInput(
                  controller.phoneC,
                  "Phone Number",
                  isNumber: true,
                  highlight: true,
                  icon: Icons.phone,
                ),
                const SizedBox(height: 8),
                _erpInput(
                  controller.nameC,
                  "Customer Name",
                  icon: Icons.person,
                ),
                const SizedBox(height: 8),
                _erpInput(
                  controller.addressC,
                  "Address / Location",
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 8),
                _erpInput(controller.shopC, "Shop Name", icon: Icons.store),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  height: 40,
                  width: isDesktop ? 240 : double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedPackager.value,
                      hint: const Text(
                        "Select Packager",
                        style: TextStyle(fontSize: 12),
                      ),
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      items:
                          controller.packagerList
                              .map(
                                (String value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (n) => controller.selectedPackager.value = n,
                    ),
                  ),
                ),
                if (controller.isConditionSale.value) ...[
                  if (isDesktop)
                    Container(
                      width: 1,
                      height: 25,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  Container(
                    height: 40,
                    width: isDesktop ? 200 : double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.selectedCourier.value,
                        hint: const Text(
                          "Select Courier",
                          style: TextStyle(fontSize: 12),
                        ),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        items:
                            controller.courierList
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => controller.selectedCourier.value = v,
                      ),
                    ),
                  ),
                  SizedBox(
                    width:
                        isDesktop
                            ? 140
                            : (MediaQuery.sizeOf(context).width / 2) - 22,
                    child: _erpInput(
                      controller.challanC,
                      "Challan No",
                      icon: Icons.receipt,
                    ),
                  ),
                  SizedBox(
                    width:
                        isDesktop
                            ? 100
                            : (MediaQuery.sizeOf(context).width / 2) - 22,
                    child: _erpInput(
                      controller.cartonsC,
                      "Carton Qty",
                      isNumber: true,
                      icon: Icons.inventory_2,
                    ),
                  ),
                  if (controller.selectedCourier.value == 'Other')
                    SizedBox(
                      width: isDesktop ? 250 : double.infinity,
                      child: _erpInput(
                        controller.otherCourierC,
                        "Custom Courier Name",
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  // --- 3. EXPANDED PAYMENT SECTION ---
  Widget _buildExpandedPaymentSection(
    LiveSalesController controller,
    bool isDesktop,
  ) {
    Widget cashBlock = Container(
      height: 85,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withValues(alpha: 0.5),
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.money, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "CASH PAYMENT",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          _erpPaymentInput(controller.cashC, "Received Amount", Colors.green),
        ],
      ),
    );

    Widget bkashBlock = Row(
      children: [
        Expanded(
          flex: 4,
          child: _erpPaymentInput(controller.bkashC, "Bkash Amt", Colors.pink),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 6,
          child: _erpInput(
            controller.bkashNumberC,
            "Bkash No (017..)",
            icon: Icons.phone_android,
          ),
        ),
      ],
    );

    Widget nagadBlock = Row(
      children: [
        Expanded(
          flex: 4,
          child: _erpPaymentInput(
            controller.nagadC,
            "Nagad Amt",
            Colors.orange,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 6,
          child: _erpInput(
            controller.nagadNumberC,
            "Nagad No (016..)",
            icon: Icons.phone_android,
          ),
        ),
      ],
    );

    Widget mobileBankingBlock = Container(
      height: isDesktop ? 85 : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pink.shade50.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.mobile_friendly, size: 18, color: Colors.pink),
              SizedBox(width: 8),
              Text(
                "MOBILE BANKING",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.pink,
                ),
              ),
            ],
          ),
          if (!isDesktop) const SizedBox(height: 12),
          if (isDesktop)
            Row(
              children: [
                Expanded(child: bkashBlock),
                const SizedBox(width: 16),
                Expanded(child: nagadBlock),
              ],
            )
          else
            Column(
              children: [bkashBlock, const SizedBox(height: 8), nagadBlock],
            ),
        ],
      ),
    );

    Widget bankBlock = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.3),
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          isDesktop
              ? Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    size: 18,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: _erpPaymentInput(
                      controller.bankC,
                      "Bank Amt",
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _erpInput(
                      controller.bankNameC,
                      "Bank Name",
                      icon: Icons.business,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _erpInput(
                      controller.bankAccC,
                      "Acc No / Trx ID",
                      icon: Icons.numbers,
                    ),
                  ),
                ],
              )
              : Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.account_balance, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "BANK PAYMENT",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _erpPaymentInput(controller.bankC, "Bank Amt", Colors.blue),
                  const SizedBox(height: 8),
                  _erpInput(
                    controller.bankNameC,
                    "Bank Name",
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 8),
                  _erpInput(
                    controller.bankAccC,
                    "Acc No / Trx ID",
                    icon: Icons.numbers,
                  ),
                ],
              ),
    );

    if (isDesktop) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: cashBlock),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: mobileBankingBlock),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [Expanded(flex: 7, child: bankBlock)]),
        ],
      );
    } else {
      return Column(
        children: [
          cashBlock,
          const SizedBox(height: 12),
          mobileBankingBlock,
          const SizedBox(height: 12),
          bankBlock,
        ],
      );
    }
  }

  // --- 4. CART & SEARCH ---
  Widget _buildCartSection(
    LiveSalesController controller,
    RxString searchQuery,
    bool isDesktop,
  ) {
    Widget cartListBuilder = Obx(() {
      if (controller.cart.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.remove_shopping_cart,
                size: 40,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 10),
              Text(
                "Cart is Empty",
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ],
          ),
        );
      }

      final filteredCart =
          controller.cart.where((item) {
            final query = searchQuery.value.toLowerCase();
            return item.product.name.toLowerCase().contains(query) ||
                item.product.model.toLowerCase().contains(query);
          }).toList();

      if (filteredCart.isEmpty) {
        return const Center(child: Text("No item found matching query"));
      }

      bool isPriceFixed =
          (controller.customerType.value == 'VIP' ||
              controller.customerType.value == 'AGENT');

      return ListView.separated(
        shrinkWrap: !isDesktop,
        physics:
            isDesktop
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: filteredCart.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = filteredCart[index];
          final originalIndex = controller.cart.indexOf(item);
          final isLoss = item.isLoss;

          return Container(
            color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.model,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 28,
                            child: CartPriceEditor(
                              initialPrice: item.priceAtSale,
                              isLoss: isLoss,
                              readOnly: isPriceFixed,
                              onChanged:
                                  (v) => controller.updateItemPrice(
                                    originalIndex,
                                    v,
                                  ),
                            ),
                          ),
                          if (isLoss)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                CartQuantityEditor(
                  currentQty: item.quantity.value,
                  maxStock: item.product.stockQty,
                  onIncrease: () {
                    if (item.quantity.value < item.product.stockQty) {
                      item.quantity.value++;
                      controller.cart.refresh();
                      controller.updatePaymentCalculations();
                    }
                  },
                  onDecrease: () {
                    if (item.quantity.value > 1) {
                      item.quantity.value--;
                      controller.cart.refresh();
                      controller.updatePaymentCalculations();
                    } else {
                      controller.cart.removeAt(originalIndex);
                      controller.updatePaymentCalculations();
                    }
                  },
                  onSubmit: (v) => controller.updateQuantity(originalIndex, v),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "৳${item.subtotal.toStringAsFixed(0)}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "SALE ORDER (${controller.cart.length})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => Text(
                        "৳${controller.grandTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (val) => searchQuery.value = val,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Find in Cart (Name or Model)...",
                      prefixIcon: const Icon(
                        Icons.filter_list,
                        size: 18,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          isDesktop ? Expanded(child: cartListBuilder) : cartListBuilder,

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Obx(() {
                  double paid = controller.totalPaidInput.value;
                  double due = controller.grandTotal - paid;
                  String lbl =
                      due > 0
                          ? "DUE AMOUNT"
                          : (paid > controller.grandTotal
                              ? "CHANGE RETURN"
                              : "PAID");
                  Color clr = due > 0 ? Colors.red : Colors.green;
                  double val = due > 0 ? due : (paid - controller.grandTotal);
                  if (paid == controller.grandTotal) val = 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Paid: ৳${paid.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: clr.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$lbl: ৳${val.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: clr,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: controller.discountC,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          labelText: "DISCOUNT",
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          prefixText: "- ",
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (v) {
                          controller.discountVal.value =
                              double.tryParse(v) ?? 0.0;
                          controller.updatePaymentCalculations();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: controller.discountNoteC,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: "Discount Note",
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          hintText: "e.g., Damaged Box...",
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PermissionVisibility(
                  moduleKey: 'new_order',
                  action: 'create',
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Obx(
                      () => ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              controller.isConditionSale.value
                                  ? Colors.deepOrange
                                  : const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed:
                            controller.isProcessing.value
                                ? null
                                : controller.finalizeSale,
                        icon:
                            controller.isProcessing.value
                                ? const SizedBox.shrink()
                                : const Icon(
                                  Icons.print,
                                  size: 20,
                                  color: Colors.white,
                                ),
                        label:
                            controller.isProcessing.value
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  controller.isConditionSale.value
                                      ? "PROCESS CHALLAN"
                                      : "COMPLETE INVOICE",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. PRODUCT TABLE (LEFT SIDE) ---
  Widget _productInventoryTable(
    LiveSalesController controller,
    bool isDesktop,
  ) {
    Widget buildTableContent() {
      Widget tableHeaders = Container(
        color: const Color(0xFFF1F5F9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: const [
            Expanded(
              flex: 4,
              child: Text(
                "PRODUCT NAME",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "MODEL",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                "STOCK",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "RATE",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(width: 50),
          ],
        ),
      );

      Widget productListBuilder = Obx(() {
        if (controller.productCtrl.isLoading.value) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: !isDesktop,
          physics:
              isDesktop
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
          itemCount: controller.productCtrl.allProducts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = controller.productCtrl.allProducts[index];
            final stockColor =
                p.stockQty == 0
                    ? Colors.red
                    : (p.stockQty < 5 ? Colors.orange : Colors.green);

            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => controller.addToCart(p),
                hoverColor: Colors.blue.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.model,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: stockColor),
                            const SizedBox(width: 6),
                            Text(
                              p.stockQty.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: stockColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Obx(() {
                          double price =
                              controller.customerType.value == "AGENT"
                                  ? p.agent
                                  : p.wholesale;
                          return Text(
                            "৳${price.toStringAsFixed(0)}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),

                      SizedBox(
                        width: 40,
                        height: 30,
                        child: ElevatedButton(
                          onPressed: () => controller.addToCart(p),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.blue.shade50,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.blue,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      });

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tableHeaders,
          isDesktop ? Expanded(child: productListBuilder) : productListBuilder,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                isDesktop
                    ? Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "PRODUCT CATALOG",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 250,
                          height: 40,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            onChanged: (v) => controller.productCtrl.search(v),
                            decoration: InputDecoration(
                              hintText: "Search Name / Model / Code...",
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: Colors.black87,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "PRODUCT CATALOG",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: TextField(
                            style: TextStyle(fontSize: 13),
                            onChanged: (v) => controller.productCtrl.search(v),
                            decoration: InputDecoration(
                              hintText: "Search Name / Model...",
                              hintStyle: TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),

          isDesktop
              ? Expanded(child: buildTableContent())
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 700, child: buildTableContent()),
              ),

          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => Text(
                    "Page ${controller.currentPage} of ${controller.totalPages}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: controller.prevPage,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: controller.nextPage,
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _erpInput(
    TextEditingController c,
    String hint, {
    bool isNumber = false,
    bool highlight = false,
    IconData? icon,
    Color? fillColor,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon:
              icon != null ? Icon(icon, size: 16, color: Colors.grey) : null,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          filled: true,
          fillColor: fillColor ?? Colors.white,
        ),
      ),
    );
  }

  Widget _erpPaymentInput(TextEditingController c, String label, Color color) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          prefixText: "৳ ",
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOGIC WIDGETS
// ---------------------------------------------------------------------------

class CartQuantityEditor extends StatefulWidget {
  final int currentQty;
  final int maxStock;
  final Function(String) onSubmit;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const CartQuantityEditor({
    super.key,
    required this.currentQty,
    required this.maxStock,
    required this.onSubmit,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  State<CartQuantityEditor> createState() => _CartQuantityEditorState();
}

class _CartQuantityEditorState extends State<CartQuantityEditor> {
  late TextEditingController _textCtrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.currentQty.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onSubmit(_textCtrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant CartQuantityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQty != oldWidget.currentQty && !_focusNode.hasFocus) {
      _textCtrl.text = widget.currentQty.toString();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onDecrease,
            child: Container(
              width: 28,
              alignment: Alignment.center,
              color: Colors.grey.shade100,
              child: const Icon(Icons.remove, size: 14),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (v) => widget.onSubmit(v),
            ),
          ),
          InkWell(
            onTap: widget.onIncrease,
            child: Container(
              width: 28,
              alignment: Alignment.center,
              color: Colors.grey.shade100,
              child: const Icon(Icons.add, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CartPriceEditor extends StatefulWidget {
  final double initialPrice;
  final bool isLoss;
  final bool readOnly;
  final Function(String) onChanged;

  const CartPriceEditor({
    super.key,
    required this.initialPrice,
    required this.isLoss,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  State<CartPriceEditor> createState() => _CartPriceEditorState();
}

class _CartPriceEditorState extends State<CartPriceEditor> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialPrice.toStringAsFixed(0));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onChanged(_ctrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant CartPriceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPrice != oldWidget.initialPrice && !_focusNode.hasFocus) {
      _ctrl.text = widget.initialPrice.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: widget.readOnly,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color:
            widget.isLoss
                ? Colors.red
                : (widget.readOnly ? Colors.grey : Colors.blue),
      ),
      decoration: InputDecoration(
        prefixText: "৳",
        prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border:
            widget.readOnly ? InputBorder.none : const UnderlineInputBorder(),
      ),
      onSubmitted: (v) {
        if (!widget.readOnly) widget.onChanged(v);
      },
    );
  }
}
