import 'dart:async';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';

/// Live, dual-colored pool gauge for the user-facing match screen.
///
/// Additions over the original version:
///  * Animated width transitions instead of instant re-layout jumps.
///  * Percentage labels on each side of the bar.
///  * Implied decimal odds for the matched pool.
///  * A live countdown to the match lock time.
///  * A dedicated error / empty state instead of a bare Text widget.
class LivePoolProgressBar extends StatefulWidget {
  final String matchId;
  final MatchService? matchService;

  const LivePoolProgressBar({
    Key? key,
    required this.matchId,
    this.matchService,
  }) : super(key: key);

  @override
  State<LivePoolProgressBar> createState() => _LivePoolProgressBarState();
}

class _LivePoolProgressBarState extends State<LivePoolProgressBar> {
  late final MatchService _service = widget.matchService ?? MatchService();
  Timer? _countdownTicker;
  Duration? _remaining;

  void _startCountdown(MatchModel match) {
    _countdownTicker?.cancel();
    _remaining = match.timeUntilLock;
    if (_remaining == null) return;
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final Duration? next = match.timeUntilLock == null
            ? null
            : match.lockTime!.difference(DateTime.now());
        _remaining = (next == null || next.isNegative) ? Duration.zero : next;
      });
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    if (widget.matchService == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchModel>(
      stream: _service.watchMatch(widget.matchId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline,
            color: Colors.red,
            message: 'Could not load live pool data. Pull to refresh.',
          );
        }
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final MatchModel match = snapshot.data!;
        if (_countdownTicker == null && match.lockTime != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown(match));
        }

        final int percentA = (match.ratioA * 100).round();
        final int percentB = 100 - percentA;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fighter A: ${match.rawPoolA.toStringAsFixed(2)} ${AppConstants.currencyCode} ($percentA%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    Text(
                      'Fighter B: ${match.rawPoolB.toStringAsFixed(2)} ${AppConstants.currencyCode} ($percentB%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        AnimatedFlex(flex: percentA.clamp(1, 99), color: Colors.blue),
                        AnimatedFlex(flex: percentB.clamp(1, 99), color: Colors.red),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Matched Active Pool: ${match.totalMatchedPool.toStringAsFixed(2)} ${AppConstants.currencyCode}  '
                          '(odds ${match.impliedOddsA.toStringAsFixed(2)}x)',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                if (match.hasUnmatchedTail) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unmatched Tail: ${match.unmatchedTotal.toStringAsFixed(2)} ${AppConstants.currencyCode} '
                            'on ${match.unmatchedSide} (Awaiting match or pre-fight refund)',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_remaining != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        _remaining == Duration.zero
                            ? 'Betting window closed'
                            : 'Locks in ${_formatDuration(_remaining!)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small helper so each side of the bar animates its width smoothly
/// instead of snapping when the underlying flex ratio changes.
class AnimatedFlex extends StatelessWidget {
  final int flex;
  final Color color;

  const AnimatedFlex({Key? key, required this.flex, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        builder: (context, value, child) => Container(color: color.withOpacity(0.6 + 0.4 * value)),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _MessageCard({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: color))),
          ],
        ),
      ),
    );
  }
}
