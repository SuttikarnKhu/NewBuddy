import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:newbuddy/model/user.dart';

ValueNotifier<FirebaseService> firebaseService = ValueNotifier(FirebaseService());

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static UserModel? _currentUser;

  static UserModel get currentUserModel {
    if (_currentUser == null) {
      throw StateError(
        '_currentUser must not be null when calling this getter'
      );
    }
    return _currentUser!;
  }

  // Get user by ID from Firestore
  static Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromJson(doc.data()!);
        return _currentUser;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Load current user (same as getUserById but stores in _currentUser)
  static Future<void> loadCurrentUser(String uid) async {
    await getUserById(uid);
  }

  static void clearCurrentUser() {
    _currentUser = null;
  }

  // Get all users stream (for contact list if needed)
  Stream<QuerySnapshot<Map<String, dynamic>>> get buildViews =>
      _firestore.collection('users').snapshots();
}
