import 'package:flutter/material.dart';

import '../Views/ph_tokens.dart';

class PHTableHeader extends StatelessWidget {
  const PHTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PHTokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: const Row(
        children: [
          PHHeaderCell('DATE', flex: 2),
          PHHeaderCell('SUPPLIER / DEBTOR', flex: 3),
          PHHeaderCell('STOCK / WAREHOUSE', flex: 3),
          PHHeaderCell('TYPE', flex: 2),
          PHHeaderCell('AMOUNT', flex: 2, align: TextAlign.right),
          _ActionHeader(),
        ],
      ),
    );
  }
}

class PHHeaderCell extends StatelessWidget {
  const PHHeaderCell(
    this.label, {
    super.key,
    this.flex = 1,
    this.align = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PHTokens.tableHeaderCell,
      ),
    );
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      child: Text(
        'ACTION',
        textAlign: TextAlign.center,
        style: PHTokens.tableHeaderCell,
      ),
    );
  }
}