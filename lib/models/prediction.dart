class Prediction {
  final String predictionId;
  final String userId;
  final String matchId;
  final String pickedSide; // 'A' or 'B'
  final DateTime createdAt;
  final bool scored;

  
  final int pointsAwarded;

  const Prediction({
    required this.predictionId,
    required this.userId,
    required this.matchId,
    required this.pickedSide,
    required this.createdAt,
    required this.scored,
    required this.pointsAwarded,
  });

  factory Prediction.fromFirestore(String id, Map<String, dynamic> data) {
    return Prediction(
      predictionId: id,
      userId: (data['userId'] ?? '').toString(),
      matchId: (data['matchId'] ?? '').toString(),
      pickedSide: (data['pickedSide'] ?? '').toString(),
      createdAt: data['createdAt'] == null
          ? DateTime.now()
          : (data['createdAt'] is DateTime ? data['createdAt'] : data['createdAt'].toDate()),
      scored: data['scored'] as bool? ?? false,
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
    );
  }




  Map<String, dynamic> toMap() => {
        'userId': userId,
        'matchId': matchId,
        'pickedSide': pickedSide,
        'scored': scored,
        'pointsAwarded': pointsAwarded,
      };
}
