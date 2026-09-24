import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/unmatched_entry.dart';
import '../services/match_service.dart';
import '../utils/csv_exporter.dart';

/// Admin control panel for the unmatched-tail queue.
///
/// Additions over the original version:
///  * Search/filter box over the unmatched queue by username.
///  * CSV export of the current queue (returned as a string via callback,
///    so the host app can decide whether to save, share, or email it).
///  * A required refund reason, enforced before the confirm button enables,
///    which is persisted to an audit log by MatchService.
///  * A typed "CONFIRM" safety check on top of the existing dialog, since
///    this action moves real money and cannot be undone.
class AdminManualRefundWidget extends StatefulWidget {
  final String matchId;
  final String adminUserId;
  final MatchService? matchService;

  /// Called with the generated CSV text when the admin taps "Export CSV".
  /// The host app wires this to its own file-save / share flow.
  final void Function(String csvContent)? onExportCsv;

  const AdminManualRefundWidget({
    Key? key,
    required this.matchId,
    required this.adminUserId,
    this.matchService,
    this.onExportCsv,
  }) : super(key: key);

  @override
  State<AdminManualRefundWidget> createState() => _AdminManualRefundWidgetState();
}

class _AdminManualRefundWidgetState extends State<AdminManualRefundWidget> {
  late final MatchService _service = widget.matchService ?? MatchService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isProcessing = false;

  List<UnmatchedEntry> _filter(List<UnmatchedEntry> entries) {
    if (_searchQuery.trim().isEmpty) return entries;
    final q = _searchQuery.toLowerCase();
    return entries.where((e) => e.userName.toLowerCase().contains(q)).toList();
  }

  Future<void> _processManualRefund(MatchModel match) async {
    final reasonController = TextEditingController();

    final confirmedReason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RefundConfirmationDialog(
        unmatchedTotal: match.unmatchedTotal,
        reasonController: reasonController,
      ),
    );

    if (confirmedReason == null || confirmedReason.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    final result = await _service.processManualRefund(
      matchId: widget.matchId,
      adminUserId: widget.adminUserId,
      reason: confirmedReason.trim(),
      unmatchedTotal: match.unmatchedTotal,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  void _exportCsv(List<UnmatchedEntry> entries) {
    final csv = CsvExporter.buildUnmatchedQueueCsv(entries);
    if (widget.onExportCsv != null) {
      widget.onExportCsv!(csv);
    } else {
      Clipboard.setData(ClipboardData(text: csv));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard.')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.matchService == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchModel>(
      stream: _service.watchMatch(widget.matchId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final MatchModel match = snapshot.data!;
        final bool isLocked = match.status.isLocked;
        final List<UnmatchedEntry> filteredQueue = _filter(match.unmatchedQueue);

        return Card(
          elevation: 6,
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Admin Order-Book Control',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(match.status.label),
                      backgroundColor: isLocked ? Colors.red.shade800 : Colors.orange.shade800,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.grey),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Unmatched Queue (Tail Users) — ${match.unmatchedQueue.length} total',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: match.unmatchedQueue.isEmpty ? null : () => _exportCsv(match.unmatchedQueue),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),

                filteredQueue.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          match.unmatchedQueue.isEmpty
                              ? '✅ Pool is fully balanced! No unmatched tail.'
                              : 'No entries match "$_searchQuery".',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      )
                    : Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          itemCount: filteredQueue.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, index) {
                            final entry = filteredQueue[index];
                            return ListTile(
                              dense: true,
                              title: Text(entry.userName, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                'Side: ${entry.side} · Placed: ${entry.placedAt?.toLocal() ?? 'unknown'}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                              trailing: Text(
                                '${entry.unmatchedAmount.toStringAsFixed(2)} ${AppConstants.currencyCode}',
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.assignment_return_rounded),
                    label: Text(
                      isLocked
                          ? 'FIGHT LOCKED & MATCHED'
                          : '🛑 Process Manual Refund (${match.unmatchedTotal.toStringAsFixed(2)} ${AppConstants.currencyCode}) & Lock',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLocked ? Colors.grey : Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (isLocked || _isProcessing || match.unmatchedTotal <= 0)
                        ? null
                        : () => _processManualRefund(match),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Two-step safety dialog: the admin must give a reason (stored in the
/// audit log) and type CONFIRM before the refund fires, since this moves
/// real money and cannot be reversed automatically.
class _RefundConfirmationDialog extends StatefulWidget {
  final double unmatchedTotal;
  final TextEditingController reasonController;

  const _RefundConfirmationDialog({
    required this.unmatchedTotal,
    required this.reasonController,
  });

  @override
  State<_RefundConfirmationDialog> createState() => _RefundConfirmationDialogState();
}

class _RefundConfirmationDialogState extends State<_RefundConfirmationDialog> {
  final TextEditingController _typedConfirmController = TextEditingController();
  bool get _canConfirm =>
      widget.reasonController.text.trim().isNotEmpty &&
      _typedConfirmController.text.trim().toUpperCase() == 'CONFIRM';

  @override
  void dispose() {
    _typedConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          title: const Text('Confirm Manual Refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This refunds ${widget.unmatchedTotal.toStringAsFixed(2)} ${AppConstants.currencyCode} '
                  'to the unmatched tail users and permanently locks this match.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for refund (required, saved to audit log)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocalState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _typedConfirmController,
                  decoration: const InputDecoration(
                    labelText: 'Type CONFIRM to proceed',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocalState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _canConfirm
                  ? () => Navigator.of(context).pop(widget.reasonController.text)
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Authorize Refund'),
            ),
          ],
        );
      },
    );
  }
}
