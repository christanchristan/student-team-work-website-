import '../constants/app_constants.dart';
import 'unmatched_entry.dart';

class MatchModel {
  final String matchId;
  final double rawPoolA;
  final double rawPoolB;
  
  final double matchedPoolPerSide;
  final double unmatchedTotal;
  final String unmatchedSide;
  final MatchStatus status;
  final DateTime? lockTime;
  final List<UnmatchedEntry> unmatchedQueue;

  const MatchModel({
    required this.matchId,
    required this.rawPoolA,
    required this.rawPoolB,
    required this.matchedPoolPerSide,
    required this.unmatchedTotal,
    required this.unmatchedSide,
    required this.status,
    required this.lockTime,
    required this.unmatchedQueue,
  });

  factory MatchModel.fromFirestore(String id, Map<String, dynamic> data) {
    final List<dynamic> rawQueue = data['unmatchedQueue'] as List<dynamic>? ?? [];

    DateTime? lockTime;
    final dynamic lockField = data['matchLockTime'];
    if (lockField != null) {
      try {
        lockTime = lockField is String
            ? DateTime.tryParse(lockField)
            : lockField.toDate();
      } catch (_) {
        lockTime = null;
      }
    }

    return MatchModel(
      matchId: id,
      rawPoolA: (data['rawPoolA'] as num?)?.toDouble() ?? 0.0,
      rawPoolB: (data['rawPoolB'] as num?)?.toDouble() ?? 0.0,
      matchedPoolPerSide: (data['matchedPoolPerSide'] as num?)?.toDouble() ?? 0.0,
      unmatchedTotal: (data['unmatchedTotal'] as num?)?.toDouble() ?? 0.0,
      unmatchedSide: (data['unmatchedSide'] ?? 'NONE').toString(),
      status: MatchStatus.fromString(data['status'] as String?),
      lockTime: lockTime,
      unmatchedQueue: rawQueue
          .whereType<Map<String, dynamic>>()
          .map(UnmatchedEntry.fromMap)
          .toList(),
    );
  }

  double get totalRawPool => rawPoolA + rawPoolB;

  /// Proportion of the raw pool sitting on side A, used to size the
  /// dual-color progress bar. Defaults to an even split pre-liquidity.
  double get ratioA => totalRawPool > 0 ? rawPoolA / totalRawPool : 0.5;

  double get totalMatchedPool => matchedPoolPerSide * 2;

  /// Simple decimal odds implied by the matched (active) pool only —
  /// the unmatched tail hasn't found a counterparty yet, so it's excluded
  /// from a fair-odds calculation.
  double get impliedOddsA =>
      matchedPoolPerSide > 0 ? totalMatchedPool / matchedPoolPerSide : 0.0;

  double get impliedOddsB => impliedOddsA; // symmetric in a matched pool

  bool get hasUnmatchedTail => unmatchedTotal > 0;

  Duration? get timeUntilLock {
    if (lockTime == null) return null;
    final Duration diff = lockTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
