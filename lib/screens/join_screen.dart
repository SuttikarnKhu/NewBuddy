import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:newbuddy/services/firebase_service.dart';
import 'package:newbuddy/model/user.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      try {
        _currentUser = FirebaseService.currentUserModel;
      } catch (e) {
        print('Error getting user: $e');
      }
      _isLoading = false;
    });
  }

  Widget _buildContactList(List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No contacts available'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              radius: 24,
              child: Text(
                user.name[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voice call button using Zego's invitation button
                ZegoSendCallInvitationButton(
                  buttonSize: const Size(48, 48),
                  iconSize: const Size(28, 28),
                  isVideoCall: false,
                  invitees: [
                    ZegoUIKitUser(
                      id: user.id,
                      name: user.name,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Video call button using Zego's invitation button
                ZegoSendCallInvitationButton(
                  buttonSize: const Size(48, 48),
                  iconSize: const Size(28, 28),
                  isVideoCall: true,
                  invitees: [
                    ZegoUIKitUser(
                      id: user.id,
                      name: user.name,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error loading user data. Please sign in again.'),
        ),
      );
    }
    
    return Scaffold(
      body: Column(
        children: [
          // Top header section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1560BD), Color(0xFF1560BD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentUser!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          radius: 24,
                          child: Text(
                            _currentUser!.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Contacts list
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: firebaseService.value.buildViews,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Rebuild to retry
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text('No caregiver found'),
                  );
                }
                
                // Get caregiver data
                final caregiverData = snapshot.data!.data() as Map<String, dynamic>;
                final caregiver = UserModel.fromJson({
                  'id': snapshot.data!.id,
                  ...caregiverData,
                });
                
                return _buildContactList([caregiver]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
