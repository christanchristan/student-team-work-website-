import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthResult {
  final bool success;
  final String message;
  const AuthResult({required this.success, required this.message});
}

/// Wraps Firebase Auth + the matching Firestore user-profile document,
/// so a new signup always gets a `users/{uid}` doc with a starting
/// points balance rather than the two getting out of sync.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      await _firestore.collection('users').doc(uid).set({
        'displayName': displayName.trim().isEmpty ? 'Player' : displayName.trim(),
        'email': email.trim(),
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return const AuthResult(success: true, message: 'Account created.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    } catch (e) {
      return AuthResult(success: false, message: 'Registration failed: $e');
    }
  }

  Future<AuthResult> login({required String email, required String password}) async {
    try {
      final credential =
          await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

      final profileDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
      final bool isBlocked = profileDoc.data()?['isBlocked'] as bool? ?? false;
      if (isBlocked) {
        final String reason = (profileDoc.data()?['blockedReason'] as String?) ??
            'This account has been suspended.';
        await _auth.signOut();
        return AuthResult(success: false, message: reason);
      }

      return const AuthResult(success: true, message: 'Logged in.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    } catch (e) {
      return AuthResult(success: false, message: 'Login failed: $e');
    }
  }

  Future<void> logout() => _auth.signOut();

  Stream<AppUser?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snap) => snap.exists ? AppUser.fromMap(snap.id, snap.data()!) : null,
        );
  }



  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered — try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }
}
