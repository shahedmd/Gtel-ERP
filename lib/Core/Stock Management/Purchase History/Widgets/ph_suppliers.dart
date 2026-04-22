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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
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
    _removeOverlay();
    _overlay = OverlayEntry(
      builder:
          (_) => Positioned(
            width: 260,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: PHSupplierDropdown(
                ctrl: widget.ctrl,
                onSelect: (supplier) {
                  _textCtrl.text = supplier['name'] ?? '';
                  widget.ctrl.setSupplierFilter(supplier['id']);
                  _removeOverlay();
                },
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 240,
        height: 40,
        child: TextField(
          controller: _textCtrl,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 13),
          decoration: PHTokens.inputDecoration(
            hint: 'Filter by supplier…',
            prefix: const Icon(
              Icons.search,
              size: 16,
              color: PHTokens.slate400,
            ),
            suffix:
                _textCtrl.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 14,
                        color: PHTokens.slate400,
                      ),
                      onPressed: () {
                        _textCtrl.clear();
                        widget.ctrl.setSupplierFilter(null);
                        _removeOverlay();
                        setState(() {});
                      },
                    )
                    : null,
          ).copyWith(
            // Override fill for the top-bar variant (no fill needed here)
            filled: true,
            fillColor: PHTokens.slate100,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) {
            setState(() {}); // Refresh suffix icon visibility
            widget.ctrl.searchSupplier(v);
            if (v.isNotEmpty) {
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

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER DROPDOWN  (rendered inside the overlay)
// ─────────────────────────────────────────────────────────────────────────────

class PHSupplierDropdown extends StatelessWidget {
  const PHSupplierDropdown({
    super.key,
    required this.ctrl,
    required this.onSelect,
  });

  final GlobalPurchaseHistoryController ctrl;
  final void Function(Map<String, dynamic> supplier) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(PHTokens.radiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
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
              height: 56,
              child: Center(
                child: Text(
                  'No matching suppliers',
                  style: TextStyle(fontSize: 12, color: PHTokens.slate400),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: ctrl.searchedSuppliers.length,
            separatorBuilder:
                (_, __) => const Divider(height: 1, color: PHTokens.slate200),
            itemBuilder: (_, i) {
              final s = ctrl.searchedSuppliers[i];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  s['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle:
                    (s['phone']?.toString().isNotEmpty ?? false)
                        ? Text(
                          s['phone'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: PHTokens.slate400,
                          ),
                        )
                        : null,
                onTap: () => onSelect(s),
              );
            },
          );
        }),
      ),
    );
  }
}
