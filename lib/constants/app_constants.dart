/// Centralized configuration so endpoints, collection names, and currency
/// formatting live in one place instead of being hard-coded across widgets.
class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = 'https://api.ethiofight.com/api/v1';
  static const String matchesCollection = 'matches';
  static const String refundAuditCollection = 'refundAuditLogs';

  static const String currencyCode = 'ETB';
  static const int requestTimeoutSeconds = 15;
  static const int maxRetryAttempts = 2;
}

/// Match lifecycle status values, kept as an enum instead of raw strings
/// to eliminate typos and make status checks exhaustive/type-safe.
enum MatchStatus {
  upcoming,
  live,
  lockedMatched,
  refunded,
  completed,
  unknown;

  static MatchStatus fromString(String? value) {
    switch (value) {
      case 'UPCOMING':
        return MatchStatus.upcoming;
      case 'LIVE':
        return MatchStatus.live;
      case 'LOCKED_MATCHED':
        return MatchStatus.lockedMatched;
      case 'REFUNDED':
        return MatchStatus.refunded;
      case 'COMPLETED':
        return MatchStatus.completed;
      default:
        return MatchStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case MatchStatus.upcoming:
        return 'UPCOMING';
      case MatchStatus.live:
        return 'LIVE';
      case MatchStatus.lockedMatched:
        return 'LOCKED_MATCHED';
      case MatchStatus.refunded:
        return 'REFUNDED';
      case MatchStatus.completed:
        return 'COMPLETED';
      case MatchStatus.unknown:
        return 'UNKNOWN';
    }
  }

  bool get isLocked =>
      this == MatchStatus.lockedMatched ||
      this == MatchStatus.live ||
      this == MatchStatus.completed;
}
