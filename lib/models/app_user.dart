class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final int points;
  final bool isBlocked;
  final String? blockedReason;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.points,
    required this.isBlocked,
    required this.blockedReason,
    required this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      displayName: (map['displayName'] ?? 'Player').toString(),
      email: (map['email'] ?? '').toString(),
      points: (map['points'] as num?)?.toInt() ?? 0,
      isBlocked: map['isBlocked'] as bool? ?? false,
      blockedReason: map['blockedReason'] as String?,
      createdAt: map['createdAt'] == null
          ? null
          : (map['createdAt'] is DateTime ? map['createdAt'] : map['createdAt'].toDate()),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'points': points,
        'isBlocked': isBlocked,
        'blockedReason': blockedReason,
      };
}
