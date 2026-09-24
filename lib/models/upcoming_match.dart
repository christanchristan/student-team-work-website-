enum PredictionMatchStatus { upcoming, completed, cancelled, unknown }

class UpcomingMatch {
  final String matchId;
  final String fighterAName;
  final String fighterBName;
  final DateTime matchTime; 
  final PredictionMatchStatus status;
  final String? winningSide; // 'A', 'B', or null if not decided yet
  final int pointsValue;

  const UpcomingMatch({
    required this.matchId,
    required this.fighterAName,
    required this.fighterBName,
    required this.matchTime,
    required this.status,
    required this.winningSide,
    required this.pointsValue,
  });

  factory UpcomingMatch.fromFirestore(String id, Map<String, dynamic> data) {
    return UpcomingMatch(
      matchId: id,
      fighterAName: (data['fighterAName'] ?? 'Fighter A').toString(),
      fighterBName: (data['fighterBName'] ?? 'Fighter B').toString(),
      matchTime: _parseTime(data['matchTime']) ?? DateTime.now(),
      status: _parseStatus(data['status'] as String?),
      winningSide: data['winningSide'] as String?,
      pointsValue: (data['pointsValue'] as num?)?.toInt() ?? 10,
    );
  }

  static DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return value.toDate();
    } catch (_) {
      return null;
    }
  }

  static PredictionMatchStatus _parseStatus(String? value) {
    switch (value) {
      case 'UPCOMING':
        return PredictionMatchStatus.upcoming;
      case 'COMPLETED':
        return PredictionMatchStatus.completed;
      case 'CANCELLED':
        return PredictionMatchStatus.cancelled;
      default:
        return PredictionMatchStatus.unknown;
    }
  }

  bool get canStillPredict =>
      status == PredictionMatchStatus.upcoming && matchTime.isAfter(DateTime.now());
}
