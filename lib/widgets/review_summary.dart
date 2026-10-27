import 'package:flutter/material.dart';
import '../models/media_item.dart';

/// A compact summary shown under the buttons when there's room beside the
/// photo (iPhone Duo open in landscape, foldables, tablets): keep / delete /
/// left counts, then one chip per year. The current year is highlighted, a
/// red badge shows how many of that year are marked for deletion, and tapping
/// a chip jumps to that year.
class ReviewSummary extends StatelessWidget {
  final List<MediaItem> media;

  /// false = delete, true = keep. Absent = not yet reviewed.
  final Map<String, bool> decisions;
  final int currentYear;
  final ValueChanged<int>? onYearTap;

  const ReviewSummary({
    super.key,
    required this.media,
    required this.decisions,
    required this.currentYear,
    this.onYearTap,
  });

  @override
  Widget build(BuildContext context) {
    final int keep = decisions.values.where((v) => v).length;
    final int delete = decisions.values.where((v) => !v).length;
    final int left = media.length - decisions.length;

    final totals = <int, int>{};
    final deletes = <int, int>{};
    for (final item in media) {
      totals[item.year] = (totals[item.year] ?? 0) + 1;
      if (decisions[item.id] == false) deletes[item.year] = (deletes[item.year] ?? 0) + 1;
    }
    final years = totals.keys.toList()..sort((a, b) => b.compareTo(a));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _tile('Keep', keep, Colors.green),
                const SizedBox(width: 8),
                _tile('Delete', delete, Colors.red),
                const SizedBox(width: 8),
                _tile('Left', left, Colors.blueGrey),
              ],
            ),
            if (years.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Years',
                style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final year in years)
                    _yearChip(year, totals[year]!, deletes[year] ?? 0),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _yearChip(int year, int total, int deleteCount) {
    final bool current = year == currentYear;
    return Material(
      color: current ? Colors.blue.withOpacity(0.12) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: current ? Colors.blue : Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onYearTap == null ? null : () => onYearTap!(year),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$year',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: current ? Colors.blue[800] : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Text('$total', style: TextStyle(color: Colors.grey[600])),
              if (deleteCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$deleteCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
