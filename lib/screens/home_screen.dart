import 'package:flutter/material.dart';
import '../widgets/chatbot_face.dart';
import '../services/reminder_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  @override
  void initState() {
    super.initState();
    _initReminders();
  }

  Future<void> _initReminders() async {
    await ReminderService.instance.init();
    ReminderService.instance.startListening();
  }

  @override
  void dispose() {
    ReminderService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ChatBotFace(),
      ),
    );
  }
}