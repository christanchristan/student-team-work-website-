import '../models/unmatched_entry.dart';

/// Builds a CSV string from the unmatched queue so admins can keep a
/// record before triggering a refund, or reconcile against payment logs.
class CsvExporter {
  static String buildUnmatchedQueueCsv(List<UnmatchedEntry> entries) {
    final buffer = StringBuffer('userId,userName,side,unmatchedAmount,placedAt\n');
    for (final entry in entries) {
      buffer.writeln(entry.toCsvRow());
    }
    return buffer.toString();
  }
}
