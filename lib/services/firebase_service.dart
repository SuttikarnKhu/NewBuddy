import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:newbuddy/model/user.dart';

ValueNotifier<FirebaseService> firebaseService = ValueNotifier(FirebaseService());

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  // Get user by ID from Firestore (searches buddies only, not caregivers)
  static Future<UserModel?> getUserById(String userId) async {
    try {
      print('Searching for buddy with ID: $userId');
      
      // Search as buddy only (skip caregiver check)
      print('Searching as buddy...');
      final caregiversSnapshot = await _firestore.collection('caregivers').get();
      print('Searching through ${caregiversSnapshot.docs.length} caregivers...');
      
      for (final caregiverDoc in caregiversSnapshot.docs) {
        final buddiesSnapshot = await caregiverDoc.reference
            .collection('buddies')
            .get();
        
        if (buddyDoc.exists) {
          print('✅ Found buddy in caregiver: ${caregiverDoc.id}');
          _caregiverId = caregiverDoc.id;
          
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
      
      print('❌ User not found as caregiver or buddy');
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
      // Test 1: Try collectionGroup query
      print('Testing collectionGroup query...');
      final collectionGroupSnapshot = await _firestore
          .collectionGroup('buddies')
          .limit(1)
          .get();
      print('✅ CollectionGroup query successful! Found ${collectionGroupSnapshot.docs.length} buddies');
      
      return true;
    } catch (e) {
      print('❌ CollectionGroup query failed: $e');
      
      // Test 2: Try direct path query
      try {
        print('Testing direct caregiver query...');
        final caregiversSnapshot = await _firestore
            .collection('caregivers')
            .limit(1)
            .get();
        print('✅ Direct caregiver query successful! Found ${caregiversSnapshot.docs.length} caregivers');
        
        if (caregiversSnapshot.docs.isNotEmpty) {
          final caregiverId = caregiversSnapshot.docs.first.id;
          print('Testing buddies subcollection for caregiver: $caregiverId');
          final buddiesSnapshot = await _firestore
              .collection('caregivers')
              .doc(caregiverId)
              .collection('buddies')
              .limit(1)
              .get();
          print('✅ Buddies subcollection query successful! Found ${buddiesSnapshot.docs.length} buddies');
        }
        
        return true;
      } catch (e2) {
        print('❌ Direct query also failed: $e2');
        return false;
      }
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
