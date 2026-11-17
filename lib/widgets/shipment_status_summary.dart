import 'package:flutter/material.dart';
import '../core/ui.dart';

/// Equal-width status cards that adapt to phone width and enlarged text.
class ShipmentStatusSummary extends StatelessWidget {
  const ShipmentStatusSummary({super.key, required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 720
          ? 3
          : constraints.maxWidth < 280 || scale > 1.6
          ? 1
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: counts.entries
            .map(
              (entry) => SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(entry.key),
                        const SizedBox(height: 12),
                        Text(
                          '${entry.value}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          'pengiriman',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
