import 'package:flutter/material.dart';
import '../Views/ph_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG SECTION LABEL + CHILD
// ─────────────────────────────────────────────────────────────────────────────

class PHDialogSection extends StatelessWidget {
  const PHDialogSection({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: PHTokens.dialogLabel),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDARD DIALOG TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────

class PHDialogTextField extends StatelessWidget {
  const PHDialogTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: PHTokens.inputDecoration(hint: hint),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDARD DIALOG DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class PHDialogDropdown<T> extends StatelessWidget {
  const PHDialogDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      style: const TextStyle(fontSize: 13, color: PHTokens.slate900),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusMd),
          borderSide: const BorderSide(color: PHTokens.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusMd),
          borderSide: const BorderSide(color: PHTokens.blue),
        ),
      ),
      items:
          items
              .map(
                (e) => DropdownMenuItem<T>(value: e, child: Text(e.toString())),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE EDITABLE FIELD (used inside table rows during invoice edit)
// ─────────────────────────────────────────────────────────────────────────────

class PHInlineField extends StatelessWidget {
  const PHInlineField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusSm),
          borderSide: const BorderSide(color: PHTokens.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusSm),
          borderSide: const BorderSide(color: PHTokens.blue),
        ),
      ),
    );
  }
}