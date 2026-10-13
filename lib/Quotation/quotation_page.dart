import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/sidemenubar.dart';
import 'package:gtel_erp/Core/Utils/navigation_key.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Permission/permission_button.dart';

import 'quotation_controller.dart';
import 'quotation_model.dart';

class QuotationListPage extends StatelessWidget {
  const QuotationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(QuotationController());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'QUOTATIONS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh quotations',
            onPressed: controller.loadQuotations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PermissionVisibility(
                  moduleKey: 'quotations',
                  action: 'create',
                  child: FilledButton.icon(
                    onPressed: () {
                      controller.startNewQuotation();
                      Get.toNamed(Routes.quotationForm, id: NavKey.nestedHome);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Make New Quotation'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => controller.listSearch.value = value,
                  decoration: InputDecoration(
                    hintText: 'Search quotation number, customer or phone...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final quotations = controller.filteredQuotations;
              if (quotations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 52,
                        color: Colors.blueGrey.shade200,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.quotations.isEmpty
                            ? 'No quotations created yet'
                            : 'No matching quotations',
                        style: TextStyle(color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: quotations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final quotation = quotations[index];
                  return _QuotationCard(
                    quotation: quotation,
                    onEdit: () {
                      controller.editQuotation(quotation);
                      Get.toNamed(
                        Routes.quotationForm,
                        id: NavKey.nestedHome,
                        arguments: quotation,
                      );
                    },
                    onPrint: () => controller.printQuotation(quotation),
                    onDownload: () => controller.downloadQuotation(quotation),
                    onDelete: () async {
                      final confirmed = await Get.dialog<bool>(
                        AlertDialog(
                          title: const Text('Delete quotation?'),
                          content: Text(
                            'Delete ${quotation.quotationNo} for ${quotation.customerName}? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(result: false),
                              child: const Text('CANCEL'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Get.back(result: true),
                              child: const Text('DELETE'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await controller.deleteQuotation(quotation);
                      }
                    },
                    onGenerateSale: () {
                      Get.find<NavigationController>().changePage(
                        Routes.liveorder,
                        arguments: quotation.toSaleDraft(),
                      );
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onGenerateSale;

  const _QuotationCard({
    required this.quotation,
    required this.onEdit,
    required this.onPrint,
    required this.onDownload,
    required this.onDelete,
    required this.onGenerateSale,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                PermissionIconButton(
                  moduleKey: 'quotations',
                  action: 'edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit quotation',
                ),
                PermissionIconButton(
                  moduleKey: 'quotations',
                  action: 'export',
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Print quotation',
                ),
                PermissionIconButton(
                  moduleKey: 'quotations',
                  action: 'export',
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download / share PDF',
                ),
                PermissionIconButton(
                  moduleKey: 'quotations',
                  action: 'delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete quotation',
                  color: Colors.red,
                ),
                PermissionVisibility(
                  moduleKey: 'new_order',
                  action: 'create',
                  child: FilledButton.tonalIcon(
                    onPressed: onGenerateSale,
                    icon: const Icon(Icons.point_of_sale, size: 18),
                    label: const Text('Generate Sale'),
                  ),
                ),
              ],
            );

            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quotation.quotationNo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${quotation.customerName}  •  ${quotation.customerPhone}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${quotation.formattedDate}  •  ${quotation.items.length} product(s)  •  ${quotation.customerType}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quoted total: ৳${quotation.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 780) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  summary,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class QuotationFormPage extends StatefulWidget {
  final Quotation? quotation;

  const QuotationFormPage({super.key, this.quotation});

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  late final QuotationController controller;
  late final TextEditingController productSearchC;
  late final TextEditingController customerSearchC;

  @override
  void initState() {
    super.initState();
    controller = Get.find<QuotationController>();
    productSearchC = TextEditingController();
    customerSearchC = TextEditingController();
    if (widget.quotation != null) {
      controller.editQuotation(widget.quotation!);
    } else {
      controller.startNewQuotation();
    }
  }

  @override
  void dispose() {
    productSearchC.dispose();
    customerSearchC.dispose();
    super.dispose();
  }

  Future<void> _saveAndPrint() async {
    final quotation = await controller.saveQuotation();
    if (quotation != null) {
      await controller.printQuotation(quotation);
      if (mounted) {
        Get.snackbar('Saved', 'Quotation saved and sent to printer.');
      }
    }
  }

  Future<void> _saveAndDownload() async {
    final quotation = await controller.saveQuotation();
    if (quotation != null) {
      await controller.downloadQuotation(quotation);
      if (mounted) Get.snackbar('Saved', 'Quotation saved and PDF is ready.');
    }
  }

  Future<void> _saveOnly() async {
    final quotation = await controller.saveQuotation();
    if (quotation != null && mounted) {
      Get.snackbar('Saved', 'Quotation saved successfully.');
    }
  }

  Future<void> _refreshForm() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Refresh quotation form?'),
        content: Text(
          widget.quotation == null
              ? 'This will clear the current quotation details and items.'
              : 'This will discard unsaved changes and restore the saved quotation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('REFRESH'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    customerSearchC.clear();
    productSearchC.clear();
    if (widget.quotation == null) {
      controller.startNewQuotation();
    } else {
      controller.editQuotation(widget.quotation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productCtrl = controller.productCtrl;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isWide = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Obx(
        () => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(isWide),
              _customerCard(),
              const SizedBox(height: 12),
              if (isWide)
                SizedBox(
                  height: screenHeight > 800 ? screenHeight * 0.75 : 650,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _productCard(productCtrl)),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: _cartCard()),
                      ],
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      SizedBox(height: 460, child: _productCard(productCtrl)),
                      const SizedBox(height: 16),
                      SizedBox(height: 520, child: _cartCard()),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _actionBar(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    final title = widget.quotation == null ? 'NEW QUOTATION' : 'EDIT QUOTATION';
    final titleBlock = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.request_quote_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Product quotation • Not a sales invoice',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isWide ? 0 : 16),
      height: isWide ? 60 : null,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      child:
          isWide
              ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleBlock,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Refresh quotation form',
                        onPressed: _refreshForm,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Get.back(id: NavKey.nestedHome),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Get.back(id: NavKey.nestedHome),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh quotation form',
                        onPressed: _refreshForm,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _customerCard() {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final typeTabs = SizedBox(
      width: isWide ? 320 : double.infinity,
      child: Row(
        children:
            const ['WHOLESALE', 'VIP', 'AGENT'].map((type) {
              final isSelected = controller.customerType.value == type;
              return Expanded(
                child: InkWell(
                  onTap: () => controller.selectCustomerType(type),
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
    final customerSearch = TextField(
      controller: customerSearchC,
      onChanged: controller.searchCustomers,
      decoration: InputDecoration(
        hintText:
            controller.customerType.value == 'AGENT'
                ? 'Search Existing Agent...'
                : 'Search Customer by Phone/Name...',
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        filled: true,
        fillColor: Colors.yellow.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );

    return _panel(
      title: 'CUSTOMER DETAILS',
      icon: Icons.person_outline,
      child: Column(
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                typeTabs,
                const SizedBox(width: 16),
                Expanded(child: customerSearch),
              ],
            )
          else ...[
            typeTabs,
            const SizedBox(height: 12),
            customerSearch,
          ],
          Obx(() {
            if (controller.customerSuggestions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              constraints: const BoxConstraints(maxHeight: 170),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: controller.customerSuggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = controller.customerSuggestions[index];
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      dense: true,
                      title: Text(customer['name']?.toString() ?? ''),
                      subtitle: Text(
                        '${customer['phone'] ?? ''} • ${customer['customerType'] ?? ''}',
                      ),
                      onTap: () {
                        controller.selectCustomerSuggestion(customer);
                        customerSearchC.clear();
                      },
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 12),
          if (isWide)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _formField(
                    controller.customerPhoneC,
                    'Phone Number',
                    width: double.infinity,
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _formField(
                    controller.shopNameC,
                    'Shop Name',
                    width: double.infinity,
                    icon: Icons.store,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _formField(
                    controller.customerNameC,
                    'Customer Name',
                    width: double.infinity,
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _formField(
                    controller.addressC,
                    'Address / Location',
                    width: double.infinity,
                    icon: Icons.location_on,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _formField(
                  controller.customerPhoneC,
                  'Phone Number',
                  width: double.infinity,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                _formField(
                  controller.customerNameC,
                  'Customer Name',
                  width: double.infinity,
                  icon: Icons.person,
                ),
                const SizedBox(height: 8),
                _formField(
                  controller.addressC,
                  'Address / Location',
                  width: double.infinity,
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 8),
                _formField(
                  controller.shopNameC,
                  'Shop Name',
                  width: double.infinity,
                  icon: Icons.store,
                ),
              ],
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  initialValue: controller.validityDays.value,
                  decoration: const InputDecoration(
                    labelText: 'Valid for',
                    suffixText: 'days',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items:
                      const [7, 14, 30, 60]
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: Text('$days days'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) controller.validityDays.value = value;
                  },
                ),
              ),
              _formField(
                controller.noteC,
                'Quotation note',
                width: 350,
                icon: Icons.notes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductController productCtrl) {
    return _panel(
      title: 'PRODUCT CATALOG',
      icon: Icons.inventory_2_outlined,
      expandChild: true,
      child: Column(
        children: [
          TextField(
            controller: productSearchC,
            onChanged: productCtrl.search,
            decoration: const InputDecoration(
              hintText: 'Search product name / model / code...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (productCtrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productCtrl.allProducts.isEmpty) {
                return const Center(child: Text('No products found'));
              }
              return ListView.separated(
                itemCount: productCtrl.allProducts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = productCtrl.allProducts[index];
                  final price =
                      controller.customerType.value == 'AGENT'
                          ? product.agent
                          : product.wholesale;
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${product.model}  •  Stock ${product.stockQty}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '৳${price.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            tooltip: 'Add to quotation',
                            onPressed: () => controller.addProduct(product),
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => controller.addProduct(product),
                    ),
                  );
                },
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() {
                  final totalPages =
                      productCtrl.totalProducts.value == 0
                          ? 0
                          : (productCtrl.totalProducts.value /
                                  productCtrl.pageSize.value)
                              .ceil();
                  return Text(
                    'Page ${productCtrl.currentPage.value} of $totalPages',
                    style: const TextStyle(fontSize: 12),
                  );
                }),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous products',
                      onPressed: productCtrl.previousPage,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next products',
                      onPressed: productCtrl.nextPage,
                      icon: const Icon(Icons.chevron_right),
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

  Widget _cartCard() {
    return _panel(
      title: 'QUOTATION ITEMS',
      icon: Icons.request_quote_outlined,
      expandChild: true,
      child: Column(
        children: [
          Expanded(
            child:
                controller.cart.isEmpty
                    ? Center(
                      child: Text(
                        'Add products from the catalog',
                        style: TextStyle(color: Colors.blueGrey.shade400),
                      ),
                    )
                    : ListView.separated(
                      itemCount: controller.cart.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = controller.cart[index];
                        return _QuotationCartRow(
                          key: ValueKey(item.product.id),
                          item: item,
                          onQuantityChanged:
                              (value) => controller.updateQuantity(item, value),
                          onPriceChanged:
                              (value) => controller.updatePrice(item, value),
                          onRemove: () => controller.removeItem(item),
                        );
                      },
                    ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.discountC,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: controller.updateDiscount,
                  decoration: const InputDecoration(
                    labelText: 'Discount',
                    prefixText: '৳ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: controller.discountNoteC,
                  decoration: const InputDecoration(
                    labelText: 'Discount note',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _totalRow('Subtotal', controller.subtotal),
          const SizedBox(height: 4),
          _totalRow('Discount', -controller.discount, color: Colors.red),
          const Divider(),
          _totalRow('QUOTED TOTAL', controller.grandTotal, emphasize: true),
          const SizedBox(height: 6),
          Text(
            'Quotation only: no payment, sale record, or stock change is made.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = [
          OutlinedButton.icon(
            onPressed: () => Get.back(id: NavKey.nestedHome),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to quotations'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          PermissionVisibility(
            moduleKey: 'quotations',
            action:
                controller.editingQuotationId.value == null ? 'create' : 'edit',
            child: Obx(
              () => FilledButton.icon(
                onPressed: controller.isSaving.value ? null : _saveOnly,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  controller.editingQuotationId.value == null
                      ? 'Save Quotation'
                      : 'Save Changes',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF334155),
                ),
              ),
            ),
          ),
          PermissionVisibility(
            moduleKey: 'quotations',
            action:
                controller.editingQuotationId.value == null ? 'create' : 'edit',
            child: PermissionVisibility(
              moduleKey: 'quotations',
              action: 'export',
              child: Obx(
                () => FilledButton.icon(
                  onPressed:
                      controller.isSaving.value ? null : _saveAndDownload,
                  icon: const Icon(Icons.download),
                  label: const Text('Save & Download PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          ),
          PermissionVisibility(
            moduleKey: 'quotations',
            action:
                controller.editingQuotationId.value == null ? 'create' : 'edit',
            child: PermissionVisibility(
              moduleKey: 'quotations',
              action: 'export',
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSaving.value ? null : _saveAndPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Save & Print'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ),
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < buttons.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                buttons[index],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < buttons.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(child: buttons[index]),
            ],
          ],
        );
      },
    );
  }

  Widget _formField(
    TextEditingController textController,
    String label, {
    required double width,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: textController,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon, size: 18),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    bool expandChild = false,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double amount, {
    bool emphasize = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w500,
            fontSize: emphasize ? 15 : 13,
          ),
        ),
        Text(
          '৳${amount.abs().toStringAsFixed(2)}${amount < 0 ? ' (less)' : ''}',
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.bold,
            fontSize: emphasize ? 18 : 13,
            color: color ?? (emphasize ? Colors.blue : null),
          ),
        ),
      ],
    );
  }
}

class _QuotationCartRow extends StatefulWidget {
  final QuotationCartItem item;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<String> onPriceChanged;
  final VoidCallback onRemove;

  const _QuotationCartRow({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  @override
  State<_QuotationCartRow> createState() => _QuotationCartRowState();
}

class _QuotationCartRowState extends State<_QuotationCartRow> {
  late final TextEditingController quantityC;
  late final TextEditingController priceC;

  @override
  void initState() {
    super.initState();
    quantityC = TextEditingController(
      text: widget.item.quantity.value.toString(),
    );
    priceC = TextEditingController(
      text: widget.item.unitPrice.value.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _QuotationCartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      quantityC.text = widget.item.quantity.value.toString();
      priceC.text = widget.item.unitPrice.value.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    quantityC.dispose();
    priceC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.product.model,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              item.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
            ),
          ],
        );
        final quantityField = SizedBox(
          width: 68,
          child: TextField(
            controller: quantityC,
            keyboardType: TextInputType.number,
            onSubmitted: widget.onQuantityChanged,
            onTapOutside: (_) => widget.onQuantityChanged(quantityC.text),
            decoration: const InputDecoration(
              labelText: 'Qty',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        );
        final priceField = SizedBox(
          width: 105,
          child: TextField(
            controller: priceC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: widget.onPriceChanged,
            onTapOutside: (_) => widget.onPriceChanged(priceC.text),
            decoration: const InputDecoration(
              labelText: 'Unit ৳',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        );
        final amount = Obx(
          () => Text(
            '৳${item.subtotal.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
        final removeButton = IconButton(
          tooltip: 'Remove item',
          onPressed: widget.onRemove,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              constraints.maxWidth < 500
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [Expanded(child: details), removeButton]),
                      Row(
                        children: [
                          quantityField,
                          const SizedBox(width: 8),
                          priceField,
                          const SizedBox(width: 8),
                          Expanded(child: amount),
                        ],
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Expanded(flex: 4, child: details),
                      const SizedBox(width: 8),
                      quantityField,
                      const SizedBox(width: 8),
                      priceField,
                      const SizedBox(width: 8),
                      SizedBox(width: 92, child: amount),
                      removeButton,
                    ],
                  ),
        );
      },
    );
  }
}
