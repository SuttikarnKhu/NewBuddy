import 'package:flutter/material.dart';
import '../widgets/chatbot_face.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ChatBotFace(),
      ),
    );
  }
}
