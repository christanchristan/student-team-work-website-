import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/prediction.dart';
import '../models/upcoming_match.dart';

class PredictionSubmitResult {
  final bool success;
  final String message;
  const PredictionSubmitResult({required this.success, required this.message});
}

class PredictionService {
  final FirebaseFirestore _firestore;

  PredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Live feed of matches still open for prediction, soonest first.
  Stream<List<UpcomingMatch>> watchUpcomingMatches() {
    return _firestore
        .collection('predictionMatches')
        .where('status', isEqualTo: 'UPCOMING')
        .orderBy('matchTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UpcomingMatch.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// The current user's prediction for one match, if they've already picked.
  Stream<Prediction?> watchMyPrediction(String matchId, String userId) {
    return _firestore
        .collection('predictions')
        .where('matchId', isEqualTo: matchId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : Prediction.fromFirestore(snap.docs.first.id, snap.docs.first.data()));
  }

  /// Submits a prediction. One prediction per user per match — enforced
  /// here by checking first, and should also be enforced by a Firestore
  /// security rule / unique-doc-id pattern (e.g. doc id = "${matchId}_${userId}")
  /// server-side so a client can't bypass this check.
  Future<PredictionSubmitResult> submitPrediction({
    required String matchId,
    required String userId,
    required String pickedSide,
  }) async {
    try {
      final matchDoc = await _firestore.collection('predictionMatches').doc(matchId).get();
      if (!matchDoc.exists) {
        return const PredictionSubmitResult(success: false, message: 'Match not found.');
      }
      final match = UpcomingMatch.fromFirestore(matchDoc.id, matchDoc.data()!);
      if (!match.canStillPredict) {
        return const PredictionSubmitResult(
            success: false, message: 'Predictions are closed for this match.');
      }

      final docId = '${matchId}_$userId';
      final existing = await _firestore.collection('predictions').doc(docId).get();
      if (existing.exists) {
        return const PredictionSubmitResult(
            success: false, message: 'You already predicted this match.');
      }

      await _firestore.collection('predictions').doc(docId).set({
        'userId': userId,
        'matchId': matchId,
        'pickedSide': pickedSide,
        'scored': false,
        'pointsAwarded': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return const PredictionSubmitResult(success: true, message: 'Prediction saved.');
    } catch (e) {
      return PredictionSubmitResult(success: false, message: 'Could not save prediction: $e');
    }
  }

  /// Top players by points, for the leaderboard screen.
  Stream<List<AppUser>> watchLeaderboard({int limit = 50}) {
    return _firestore
        .collection('users')
        .where('isBlocked', isEqualTo: false)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }
}
