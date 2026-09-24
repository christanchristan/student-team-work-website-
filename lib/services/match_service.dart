import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/match_model.dart';
  




class RefundResult {
  final bool success;
  final String message;
  const RefundResult({required this.success, required this.message});
}



/// Wraps all Firestore + backend access for a match so widgets stay
/// presentation-only and are easy to test with a fake service.
class MatchService {
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;
  
  

  MatchService({FirebaseFirestore? firestore, http.Client? httpClient})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client();

  Stream<MatchModel> watchMatch(String matchId) {
    return _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .snapshots()
        .where((snap) => snap.exists)
        .map((snap) => MatchModel.fromFirestore(snap.id, snap.data()!));
  }

  /// Calls the manual-refund endpoint with a short retry loop for
  /// transient network failures, then writes an audit log entry so every
  /// manual refund has a traceable admin, reason, and timestamp.
  Future<RefundResult> processManualRefund({
    required String matchId,
    required String adminUserId,
    required String reason,
    required double unmatchedTotal,
  }) async {
    Exception? lastError;

    for (int attempt = 0; attempt <= AppConstants.maxRetryAttempts; attempt++) {
      try {
        final response = await _httpClient
            .post(
              Uri.parse(
                  '${AppConstants.apiBaseUrl}/admin/matches/$matchId/process-manual-refund'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'adminUserId': adminUserId,
                'reason': reason,
                'confirmMatchLock': true,
              }),
            )
            .timeout(const Duration(seconds: AppConstants.requestTimeoutSeconds));

        if (response.statusCode == 200) {
          await _writeAuditLog(
            matchId: matchId,
            adminUserId: adminUserId,
            reason: reason,
            unmatchedTotal: unmatchedTotal,
            success: true,
          );
          return const RefundResult(success: true, message: 'Refund processed and match locked.');
        }

        final String errorMessage =
            (jsonDecode(response.body)['message'] as String?) ?? 'Refund failed (${response.statusCode}).';
        await _writeAuditLog(
          matchId: matchId,
          adminUserId: adminUserId,
          reason: reason,
          unmatchedTotal: unmatchedTotal,
          success: false,
          errorMessage: errorMessage,
        );
        return RefundResult(success: false, message: errorMessage);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Only retry on the last-but-one attempt; otherwise fall through to failure.
        if (attempt == AppConstants.maxRetryAttempts) break;
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    await _writeAuditLog(
      matchId: matchId,
      adminUserId: adminUserId,
      reason: reason,
      unmatchedTotal: unmatchedTotal,
      success: false,
      errorMessage: lastError?.toString() ?? 'Unknown network error',
    );

    return RefundResult(
      success: false,
      message: 'Network error: ${lastError?.toString() ?? 'unknown'}',
    );
  }

  Future<void> _writeAuditLog({
    required String matchId,
    required String adminUserId,
    required String reason,
    required double unmatchedTotal,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await _firestore.collection(AppConstants.refundAuditCollection).add({
        'matchId': matchId,
        'adminUserId': adminUserId,
        'reason': reason,
        'unmatchedTotal': unmatchedTotal,
        'success': success,
        'errorMessage': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit logging must never crash the refund flow itself; a failed
      // log write is a lesser problem than blocking a successful refund.
    }
  }

  void dispose() => _httpClient.close();
}
