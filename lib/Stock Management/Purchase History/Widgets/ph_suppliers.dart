import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';

class PHSupplierSearchField extends StatefulWidget {
  const PHSupplierSearchField({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  @override
  State<PHSupplierSearchField> createState() => _PHSupplierSearchFieldState();
}

class _PHSupplierSearchFieldState extends State<PHSupplierSearchField> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  OverlayEntry? _overlay;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _removeTimer?.cancel();
        _removeTimer = Timer(const Duration(milliseconds: 180), _removeOverlay);
      }
    });
  }

  @override
  void dispose() {
    _removeTimer?.cancel();
    _removeOverlay();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    _removeTimer?.cancel();

    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }

    _overlay = OverlayEntry(
      builder: (_) {
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: PHSupplierDropdown(
              ctrl: widget.ctrl,
              onSelect: (supplier) async {
                final id = supplier['id']?.toString().trim() ?? '';
                final name = supplier['name']?.toString().trim() ?? '';

                if (id.isEmpty) return;

                _removeTimer?.cancel();

                _textCtrl.text = name;
                _textCtrl.selection = TextSelection.collapsed(
                  offset: name.length,
                );

                _removeOverlay();
                _focusNode.unfocus();

                if (mounted) setState(() {});

                await widget.ctrl.setSupplierFilter(id, supplierName: name);
              },
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
  }

  Future<void> _clearSupplier() async {
    _removeTimer?.cancel();

    _textCtrl.clear();
    _removeOverlay();
    _focusNode.unfocus();

    if (mounted) setState(() {});

    await widget.ctrl.setSupplierFilter(null);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 260,
        height: 40,
        child: TextField(
          controller: _textCtrl,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 13),
          decoration: PHTokens.inputDecoration(
            hint: 'Filter by supplier...',
            prefix: const Icon(
              Icons.search,
              size: 16,
              color: PHTokens.slate400,
            ),
            suffix: _textCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 14,
                      color: PHTokens.slate400,
                    ),
                    onPressed: _clearSupplier,
                  )
                : null,
          ).copyWith(
            filled: true,
            fillColor: PHTokens.slate100,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onTap: () {
            if (_textCtrl.text.trim().isNotEmpty) {
              _showOverlay();
            }
          },
          onChanged: (value) {
            setState(() {});

            final query = value.trim();

            widget.ctrl.searchSupplier(query);

            if (query.isNotEmpty) {
              _showOverlay();
            } else {
              _removeOverlay();
            }
          },
        ),
      ),
    );
  }
}

class PHSupplierDropdown extends StatelessWidget {
  const PHSupplierDropdown({
    super.key,
    required this.ctrl,
    required this.onSelect,
  });

  final GlobalPurchaseHistoryController ctrl;
  final Future<void> Function(Map<String, dynamic> supplier) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(PHTokens.radiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: Obx(() {
          if (ctrl.isSearchingSupplier.value) {
            return const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PHTokens.blue,
                ),
              ),
            );
          }

          if (ctrl.searchedSuppliers.isEmpty) {
            return const SizedBox(
              height: 58,
              child: Center(
                child: Text(
                  'No matching suppliers',
                  style: TextStyle(
                    fontSize: 12,
                    color: PHTokens.slate400,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: ctrl.searchedSuppliers.length,
            separatorBuilder: (_, __) {
              return const Divider(
                height: 1,
                color: PHTokens.slate200,
              );
            },
            itemBuilder: (_, index) {
              final supplier = ctrl.searchedSuppliers[index];
              final name = supplier['name']?.toString() ?? '';
              final phone = supplier['phone']?.toString() ?? '';
              final address = supplier['address']?.toString() ?? '';

              return InkWell(
                onTapDown: (_) => onSelect(supplier),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: PHTokens.blueLight,
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: PHTokens.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Unnamed Supplier' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: PHTokens.slate900,
                              ),
                            ),
                            if (phone.isNotEmpty || address.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                phone.isNotEmpty ? phone : address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: PHTokens.slate400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
