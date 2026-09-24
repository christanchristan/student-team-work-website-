class UnmatchedEntry {
  final String userId;
  final String userName;
  final double unmatchedAmount;
  final DateTime? placedAt;
  final String side;

  const UnmatchedEntry({
    required this.userId,
    required this.userName,
    required this.unmatchedAmount,
    required this.placedAt,
    required this.side,
  });


  factory UnmatchedEntry.fromMap(Map<String, dynamic> map) {
    return UnmatchedEntry(
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? 'Unknown user').toString(),
      unmatchedAmount: (map['unmatchedAmount'] as num?)?.toDouble() ?? 0.0,
      placedAt: _parseTimestamp(map['placedAt']),
      side: (map['side'] ?? 'UNKNOWN').toString(),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    // Supports both Firestore Timestamp (has toDate()) and ISO strings,
    // so the widget doesn't crash if the backend format changes.
    try {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      final dynamic maybeTimestamp = value;
      return maybeTimestamp.toDate();
    } catch (_) {
      return null;
    }
  }

  /// One row of the CSV export.
  String toCsvRow() {
    final String safeName = userName.replaceAll(',', ' ');
    final String time = placedAt?.toIso8601String() ?? 'unknown';
    return '$userId,$safeName,$side,${unmatchedAmount.toStringAsFixed(2)},$time';
  }
}
