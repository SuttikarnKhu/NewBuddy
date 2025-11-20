import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Keep import for now, might be removed later if not used anywhere else
import 'package:logging/logging.dart';
import 'package:newbuddy/services/firebase_service.dart';

class ReminderService {
  static final ReminderService instance = ReminderService._();
  ReminderService._();

  final _log = Logger('ReminderService');
  final FlutterTts _flutterTts = FlutterTts(); // Still initialized, but not used for speaking reminders
  
  StreamSubscription? _eventsSubscription;
  Timer? _checkTimer;
  
  // Local cache of active events
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeEvents = [];

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage("en-US"); 
      await _flutterTts.setSpeechRate(0.5);
      _isInitialized = true;
      _log.info('ReminderService initialized');
    } catch (e) {
      _log.severe('Error initializing TTS: $e');
    }
  }

  void startListening() {
    if (_eventsSubscription != null) return; // Already listening

    final uid = FirebaseService.caregiverId;
    final buddyId = FirebaseService.currentUserModel.id; // Accessing static getter directly

    // Note: FirebaseService.currentUserModel might throw if not set.
    // We should catch or check safely, but per app flow, it should be set by now.
    
    if (uid == null) {
      _log.warning('Cannot start ReminderService: Missing caregiverId');
      return;
    }

    _log.info('Starting ReminderService for caregiver: $uid, buddy: $buddyId');

    final collectionRef = FirebaseFirestore.instance
        .collection('caregivers')
        .doc(uid)
        .collection('buddies')
        .doc(buddyId)
        .collection('events');

    _eventsSubscription = collectionRef
        .where('finishAnnounce', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _activeEvents = snapshot.docs;
      _log.info('Updated active events: ${_activeEvents.length}');
      _checkReminders(); // Check immediately on update
    }, onError: (e) {
      _log.severe('Error listening to events: $e');
    });

    // Check periodically (every 30 seconds)
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
  }

  void stopListening() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    _activeEvents.clear();
    _log.info('ReminderService stopped');
  }

  Future<void> _checkReminders() async {
    final now = DateTime.now();

    // Copy list to avoid concurrent modification issues if stream updates during loop
    final eventsToCheck = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(_activeEvents);

    for (final doc in eventsToCheck) {
      try {
        final data = doc.data();
        
        // Check for required fields
        if (!data.containsKey('date') || !data.containsKey('time')) continue;

        final Timestamp? dateTs = data['date'];
        final String? timeStr = data['time']; // "HH:mm"
        final int frequency = data['frequency'] is int ? data['frequency'] : (int.tryParse(data['frequency']?.toString() ?? '0') ?? 0);
        final int interval = data['interval'] is int ? data['interval'] : (int.tryParse(data['interval']?.toString() ?? '0') ?? 0); // minutes
        final int announceCount = data['AnnounceCount'] is int ? data['AnnounceCount'] : (int.tryParse(data['AnnounceCount']?.toString() ?? '0') ?? 0);
        final String title = data['title'] ?? '';
        final String description = data['description'] ?? '';
        final bool finishAnnounce = data['finishAnnounce'] ?? false;

        if (finishAnnounce) continue; // Should be filtered by query, but double check
        if (dateTs == null || timeStr == null) continue;

        // Construct start DateTime
        final date = dateTs.toDate(); // Local time
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;

        // Combine date (year/month/day) with time (hour/minute)
        final startDateTime = DateTime(
          date.year, 
          date.month, 
          date.day, 
          hour, 
          minute
        );

        // Calculate the scheduled time for the *current* step (AnnounceCount)
        // 0th announce = startDateTime
        // 1st announce = startDateTime + interval
        // ...
        final scheduledTime = startDateTime.add(Duration(minutes: interval * announceCount));
        
        // Allow a small buffer (e.g., if we missed it by a few seconds, or it's just due)
        // Since we check every 30s, we just check if now >= scheduledTime
        if (now.isAfter(scheduledTime) || now.isAtSameMomentAs(scheduledTime)) {
           // Additional check: ensure we don't announce too rapidly if there was a glitch.
           // But Firestore update should prevent double announce via stream update loop.
           
           await _updateAnnounceCount(doc.reference, announceCount, frequency);
        }

      } catch (e) {
        _log.severe('Error processing event ${doc.id}: $e');
      }
    }
  }

  Future<void> _updateAnnounceCount(
    DocumentReference ref, 
    int currentCount, 
    int maxFrequency
  ) async {
    // Update Firestore
    // Increment count.
    final newCount = currentCount + 1;
    final finish = newCount >= maxFrequency;

    try {
      if (finish) {
        _log.info('Reminder finished (Count: $newCount >= Freq: $maxFrequency). Deleting event ${ref.id}...');
        await ref.delete();
      } else {
        await ref.update({
          'AnnounceCount': newCount,
          'finishAnnounce': false,
        });
        _log.info('Updated event ${ref.id}: count=$newCount, finish=false');
      }
    } catch (e) {
      _log.severe('Failed to update/delete event ${ref.id}: $e');
    }
  }

  // New method to provide active reminders as a formatted string
  String getActiveRemindersText() {
    if (_activeEvents.isEmpty) {
      return "ไม่มีการแจ้งเตือนใดๆ ในขณะนี้ครับ";
    }

    final List<String> formattedReminders = [];
    for (final doc in _activeEvents) {
      final data = doc.data();
      final title = data['title'] ?? 'Untitled';
      final time = data['time'] ?? '??:??';
      final description = data['description'] ?? '';
      formattedReminders.add('$title เวลา $time ($description)');
    }
    return "บั๊ดดี้ทราบข้อมูลการแจ้งเตือนปัจจุบันดังนี้: " + formattedReminders.join('; ') + "ครับ";
  }
}
