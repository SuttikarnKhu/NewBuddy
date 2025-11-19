import 'package:flutter/material.dart';
import 'package:newbuddy/services/firebase_service.dart';
import 'package:newbuddy/screens/home_screen.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:newbuddy/constants/app_config.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

class IdInputScreen extends StatefulWidget {
  const IdInputScreen({super.key});

  @override
  State<IdInputScreen> createState() => _IdInputScreenState();
}

class _IdInputScreenState extends State<IdInputScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitId() async {
    final id = _idController.text.trim();
    
    if (id.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your buddy ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch user from Firestore
      final user = await FirebaseService.getUserById(id);
      
      if (user == null) {
        setState(() {
          _errorMessage = 'User not found. Please check your ID and try again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Show confirmation dialog
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Buddy'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connect as:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        user.gender.toLowerCase() == 'male' 
                          ? Icons.person 
                          : Icons.person_outline,
                        size: 40,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${user.age} years old • ${user.gender}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );

        if (confirmed != true) {
          return;
        }
      }

      setState(() {
        _isLoading = true;
      });

      // Initialize Zego call service
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: AppConfig.appID,
        appSign: AppConfig.appSign,
        userID: user.id,
        userName: user.name,
        plugins: [ZegoUIKitSignalingPlugin()],
      );

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your ID'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/logo.png',
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Colors.blue,
                  );
                },
              ),
            const SizedBox(height: 32),
            const Text(
              'Welcome to Buddy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please enter the ID provided by your administrator',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'Buddy ID',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _submitId(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitId,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}
