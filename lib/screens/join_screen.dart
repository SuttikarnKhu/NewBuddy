import 'package:flutter/material.dart';
import 'call_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _roomController = TextEditingController(text: 'test_room');
  final _nameController = TextEditingController(text: 'AndroidTablet');

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a call')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final room = _roomController.text.trim();
                final name = _nameController.text.trim();
                if (room.isEmpty || name.isEmpty) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CallScreen(
                    callID: room,
                    userName: name,
                  ),
                ));
              },
              child: const Text('Join'),
            )
          ],
        ),
      ),
    );
  }
}
