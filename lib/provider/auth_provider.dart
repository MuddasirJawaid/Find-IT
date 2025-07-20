import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false; // For active login/register operations
  String? _errorMessage;
  bool _isAuthReady = false; // New flag to indicate initial auth state is determined

  AuthProvider() {
    // Initialize _user with current user (might be null initially)
    _user = _auth.currentUser;

    // Listen to authentication state changes
    _auth.authStateChanges().listen((user) {
      _user = user;
      // Once the first event from authStateChanges comes, it means Firebase
      // has determined the initial authentication state.
      if (!_isAuthReady) {
        _isAuthReady = true;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading; // For login/register process
  bool get isAuthReady => _isAuthReady; // For initial app load
  String? get errorMessage => _errorMessage;

  /// ✅ LOGIN
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // _user will be updated by the authStateChanges listener
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Login failed.');
    } catch (_) {
      _setError('Login failed. Try again.');
    }
    return false;
  }

  /// ✅ REGISTER WITH FIRESTORE
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
  }) async {
    _setLoading(true);
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // _user will be updated by the authStateChanges listener

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'city': city,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Registration failed.');
    } catch (_) {
      _setError('Registration failed. Try again.');
    }
    return false;
  }

  /// ✅ RESET PASSWORD
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _setError(null); // Clear any previous error message
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Failed to send reset email.');
    } catch (_) {
      _setError('Failed to send reset email.');
    }
  }

  /// ✅ LOGOUT
  Future<void> logout([BuildContext? context]) async {
    await _auth.signOut();
    // _user will be set to null by the authStateChanges listener
    // _isAuthReady will remain true, as the initial check is done.
    notifyListeners();
  }

  /// 🔹 Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    _errorMessage = null; // Clear error when loading
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }
}
