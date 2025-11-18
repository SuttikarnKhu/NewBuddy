import 'package:flutter/material.dart';
import 'package:newbuddy/screens/home_screen.dart';
import 'package:newbuddy/services/firebase_service.dart';
import 'package:newbuddy/screens/app_loading_page.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    this.pageIfNotConnected,
  });

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: firebaseService,
      builder: (context, FirebaseService, child) {
        return StreamBuilder(
          stream: firebaseService.value.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingPage();
            } else if (snapshot.hasData) {
              return const HomeScreen();
            } else {
              return pageIfNotConnected ?? const AppLoadingPage();
            }
          },
        );
      },
    );
  }
}