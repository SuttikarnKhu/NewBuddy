import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:newbuddy/model/user.dart';

ValueNotifier<FirebaseService> firebaseService = ValueNotifier(FirebaseService());

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static UserModel? _currentUser;
  static String? _caregiverId;
  static String? _caregiverName;

  static UserModel get currentUserModel {
    if (_currentUser == null) {
      throw StateError(
        '_currentUser must not be null when calling this getter'
      );
    }
    return _currentUser!;
  }

  // Get user by ID from Firestore (searches across all caregivers' buddies)
  static Future<UserModel?> getUserById(String buddyId) async {
    try {
      // Ensure we are authenticated (Anonymous Auth for Buddy App)
      if (_auth.currentUser == null) {
        print('Signing in anonymously...');
        await _auth.signInAnonymously();
        print('Signed in anonymously as ${_auth.currentUser?.uid}');
      }
      print('Searching for buddy with ID: $buddyId');
      
      // Step 1: Get all caregivers
      final caregiversSnapshot = await _firestore.collection('caregivers').get();
      print('Searching through ${caregiversSnapshot.docs.length} caregivers...');
      
      // Step 2: Search each caregiver's buddies subcollection
      for (final caregiverDoc in caregiversSnapshot.docs) {
        final buddyDoc = await caregiverDoc.reference
            .collection('buddies')
            .doc(buddyId)
            .get();
        
        if (buddyDoc.exists) {
          print('Found buddy in caregiver: ${caregiverDoc.id}');
          _caregiverId = caregiverDoc.id;
          _caregiverName = caregiverDoc.data()['name'];
          
          final data = buddyDoc.data()!;
          _currentUser = UserModel(
            id: buddyDoc.id,
            name: data['name'] ?? '',
            gender: data['gender'] ?? '',
            age: data['age'] is String ? int.tryParse(data['age']) ?? 0 : data['age'] ?? 0,
            preference: data['role'] ?? '',
          );
          
          print('Successfully loaded user: ${_currentUser!.name}');
          return _currentUser;
        }
      }
      
      print('Buddy not found in any caregiver');
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      rethrow;
    }
  }

  // Load current user (same as getUserById but stores in _currentUser)
  static Future<void> loadCurrentUser(String uid) async {
    await getUserById(uid);
  }

  static void clearCurrentUser() {
    _currentUser = null;
    _caregiverId = null;
    _caregiverName = null;
  }

  // Test database connection
  static Future<bool> testDatabaseConnection() async {
    try {
      // Test 1: Try direct path query (which works without indices usually)
      print('Testing direct caregiver query...');
      final caregiversSnapshot = await _firestore
          .collection('caregivers')
          .limit(1)
          .get();
      print('Direct caregiver query successful! Found ${caregiversSnapshot.docs.length} caregivers');
      
      if (caregiversSnapshot.docs.isNotEmpty) {
        final caregiverId = caregiversSnapshot.docs.first.id;
        print('Testing buddies subcollection for caregiver: $caregiverId');
        final buddiesSnapshot = await _firestore
            .collection('caregivers')
            .doc(caregiverId)
            .collection('buddies')
            .limit(1)
            .get();
        print('Buddies subcollection query successful! Found ${buddiesSnapshot.docs.length} buddies');
      }
      return true;
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }

  // Get the caregiver data (for contact list)
  Stream<DocumentSnapshot<Map<String, dynamic>>> get buildViews {
    if (_caregiverId == null) {
      throw StateError('Caregiver ID not set. Please login first.');
    }
    return _firestore
        .collection('caregivers')
        .doc(_caregiverId)
        .snapshots();
  }

  // Get caregiver ID
  static String? get caregiverId => _caregiverId;
  static String? get caregiverName => _caregiverName;
}
