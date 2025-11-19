import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:newbuddy/model/user.dart';

ValueNotifier<FirebaseService> firebaseService = ValueNotifier(FirebaseService());

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth methods
  User? get currentAuthUser => _auth.currentUser;
  static UserModel? _currentUser;

  static UserModel get currentUserModel {
    if (_currentUser == null) {
      throw StateError(
        '_currentUser must not be null when calling this getter'
      );
    }
    return _currentUser!;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    
    // Load user data after successful sign in
    await loadCurrentUser(credential.user!.uid);
    
    return credential;
  }

  static Future<void> loadCurrentUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        _currentUser = UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      // Error loading user data
      rethrow;
    }
  }

  static void clearCurrentUser() {
    _currentUser = null;
  }

  // Firestore methods
  Stream<QuerySnapshot<Map<String, dynamic>>> get buildViews =>
      _firestore.collection('users').snapshots();

  Future<bool> saveUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return false;
      }

      var userRef = _firestore.collection('users').doc(
            credential.user!.uid,
          );

      final Timestamp createdAt = Timestamp.now();

      final String token = '';

      final user = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        createdAt: createdAt.toDate().toString(),
        token: token,
      );

      await userRef.set(user.toJson());
      
      // Load the user data into _currentUser after registration
      _currentUser = user;

      return true;
    } catch (e) {
      return false;
    }
  }
}
