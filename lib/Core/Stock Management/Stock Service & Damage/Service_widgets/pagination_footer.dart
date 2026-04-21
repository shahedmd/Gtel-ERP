import 'package:flutter/material.dart';

import '../Service/service_constatnts.dart';

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.total,
    required this.startIndex,
    required this.endIndex,
    required this.totalPages,
    required this.current,
    required this.isMobile,
    required this.onNext,
    required this.onPrev,
  });

  final int total;
  final int startIndex;
  final int endIndex;
  final int totalPages;
  final int current;
  final bool isMobile;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isMobile)
            Text(
              'Showing ${startIndex + 1}–$endIndex of $total',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: current > 1 ? onPrev : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'Page $current of $totalPages',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: current < totalPages ? onNext : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
