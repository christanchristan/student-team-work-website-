import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/prediction.dart';
import '../models/upcoming_match.dart';

class AdminOpResult {
  final bool success;
  final String message;
  const AdminOpResult({required this.success, required this.message});
}

/// All administrative operations for the prediction game: match lifecycle,
/// result entry + automatic scoring, viewing raw predictions, and account
/// moderation. In production the scoring step in particular should be
/// mirrored (or moved outright) into a Cloud Function triggered on the
/// match-result write, so a malicious or buggy client can't award itself
/// points — this client-side version is convenient for an admin app but
/// should sit behind an admin-only security rule at minimum.
class AdminService {
  final FirebaseFirestore _firestore;

  AdminService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------- Match management ----------

  Stream<List<UpcomingMatch>> watchAllMatches() {
    return _firestore
        .collection('predictionMatches')
        .orderBy('matchTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UpcomingMatch.fromFirestore(d.id, d.data())).toList());
  }

  Future<AdminOpResult> createMatch({
    required String fighterAName,
    required String fighterBName,
    required DateTime matchTime,
    int pointsValue = 10,
  }) async {
    if (fighterAName.trim().isEmpty || fighterBName.trim().isEmpty) {
      return const AdminOpResult(success: false, message: 'Both team/fighter names are required.');
    }
    try {
      await _firestore.collection('predictionMatches').add({
        'fighterAName': fighterAName.trim(),
        'fighterBName': fighterBName.trim(),
        'matchTime': Timestamp.fromDate(matchTime),
        'status': 'UPCOMING',
        'winningSide': null,
        'pointsValue': pointsValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const AdminOpResult(success: true, message: 'Match created.');
    } catch (e) {
      return AdminOpResult(success: false, message: 'Could not create match: $e');
    }
  }

  Future<AdminOpResult> updateMatchDetails({
    required String matchId,
    String? fighterAName,
    String? fighterBName,
    DateTime? matchTime,
    int? pointsValue,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fighterAName != null) updates['fighterAName'] = fighterAName.trim();
      if (fighterBName != null) updates['fighterBName'] = fighterBName.trim();
      if (matchTime != null) updates['matchTime'] = Timestamp.fromDate(matchTime);
      if (pointsValue != null) updates['pointsValue'] = pointsValue;
      if (updates.isEmpty) {
        return const AdminOpResult(success: false, message: 'Nothing to update.');
      }
      await _firestore.collection('predictionMatches').doc(matchId).update(updates);
      return const AdminOpResult(success: true, message: 'Match updated.');
    } catch (e) {
      return AdminOpResult(success: false, message: 'Update failed: $e');
    }
  }

  Future<AdminOpResult> cancelMatch(String matchId) async {
    try {
      await _firestore.collection('predictionMatches').doc(matchId).update({'status': 'CANCELLED'});
      return const AdminOpResult(success: true, message: 'Match cancelled.');
    } catch (e) {
      return AdminOpResult(success: false, message: 'Cancel failed: $e');
    }
  }

  // ---------- Result entry + scoring ----------

  /// Enters the final result and immediately scores every prediction
  /// for that match: correct picks get the match's `pointsValue` added
  /// to the user's running total, in a single batched write.
  Future<AdminOpResult> enterResultAndScore({
    required String matchId,
    required String winningSide, // 'A' or 'B'
  }) async {
    try {
      final matchDoc = await _firestore.collection('predictionMatches').doc(matchId).get();
      if (!matchDoc.exists) {
        return const AdminOpResult(success: false, message: 'Match not found.');
      }
      final match = UpcomingMatch.fromFirestore(matchDoc.id, matchDoc.data()!);

      final predictionsSnap = await _firestore
          .collection('predictions')
          .where('matchId', isEqualTo: matchId)
          .where('scored', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      final Map<String, int> pointsToAdd = {};

      for (final doc in predictionsSnap.docs) {
        final prediction = Prediction.fromFirestore(doc.id, doc.data());
        final bool correct = prediction.pickedSide == winningSide;
        final int awarded = correct ? match.pointsValue : 0;

        batch.update(doc.reference, {'scored': true, 'pointsAwarded': awarded});
        if (awarded > 0) {
          pointsToAdd.update(prediction.userId, (v) => v + awarded, ifAbsent: () => awarded);
        }
      }

      for (final entry in pointsToAdd.entries) {
        batch.update(
          _firestore.collection('users').doc(entry.key),
          {'points': FieldValue.increment(entry.value)},
        );
      }

      batch.update(matchDoc.reference, {
        'status': 'COMPLETED',
        'winningSide': winningSide,
      });

      await batch.commit();
      return AdminOpResult(
        success: true,
        message: 'Result recorded. ${pointsToAdd.length} winner(s) scored.',
      );
    } catch (e) {
      return AdminOpResult(success: false, message: 'Scoring failed: $e');
    }
  }

  // ---------- Viewing predictions ----------

  Stream<List<Prediction>> watchPredictionsForMatch(String matchId) {
    return _firestore
        .collection('predictions')
        .where('matchId', isEqualTo: matchId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Prediction.fromFirestore(d.id, d.data())).toList());
  }
  

  // ---------- Account moderation ----------

  Stream<List<AppUser>> watchAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('points', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<AdminOpResult> setUserBlocked({
    required String uid,
    required bool isBlocked,
    String? reason,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isBlocked': isBlocked,
        'blockedReason': isBlocked ? (reason?.trim().isEmpty ?? true ? 'Suspected fraud.' : reason) : null,
      });
      return AdminOpResult(
        success: true,
        message: isBlocked ? 'Account blocked.' : 'Account unblocked.',
      );
    } catch (e) {
      return AdminOpResult(success: false, message: 'Could not update account: $e');
    }
  }
}
