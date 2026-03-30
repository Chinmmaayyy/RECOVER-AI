import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/triage_service.dart';
import '../services/supabase_service.dart';
import '../services/offline_service.dart';
import '../services/sms_service.dart';
import '../services/demo_mode.dart';

class VoiceCheckinScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const VoiceCheckinScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<VoiceCheckinScreen> createState() => _VoiceCheckinScreenState();
}

class _VoiceCheckinScreenState extends State<VoiceCheckinScreen> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _transcript = '';
  TriageResult? _triageResult;
  bool _isSubmitting = false;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Demo mode tap detection
  int _nameTapCount = 0;
  DateTime? _lastNameTap;
  bool _isResettingDemo = false;

  static const _demoTranscript =
      'I feel a bit heavy in my chest today and my legs look a little puffy';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_transcript.isNotEmpty) _processTranscript();
        }
      },
    );
    setState(() {});
  }

  void _onNameTapped() {
    final now = DateTime.now();
    if (_lastNameTap != null && now.difference(_lastNameTap!).inMilliseconds > 1500) {
      _nameTapCount = 0;
    }
    _lastNameTap = now;
    _nameTapCount++;

    if (_nameTapCount >= 5) {
      _nameTapCount = 0;
      DemoMode.toggle();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DemoMode.isActive ? 'Demo Mode ON' : 'Demo Mode OFF'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _startListening() {
    if (DemoMode.isActive) {
      _startDemoListening();
      return;
    }
    if (!_speechAvailable) return;
    setState(() {
      _isListening = true;
      _transcript = '';
      // Don't clear _triageResult here — let the new one replace it smoothly
    });
    _speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  void _startDemoListening() {
    setState(() {
      _isListening = true;
      _transcript = '';
    });

    // Simulate 3 seconds of "listening" then auto-fill demo transcript
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _transcript = _demoTranscript;
      });
      _processTranscript();
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    if (_transcript.isNotEmpty) _processTranscript();
  }

  Future<void> _processTranscript() async {
    // Use regex fallback NLP (on-device, no API needed)
    final symptomJson = TriageService.regexFallbackNLP(_transcript);

    // Get recent check-ins for escalation rule
    final recentHistory = await SupabaseService.getCheckIns(widget.patientId, limit: 3);

    // Run triage — pass raw transcript for better keyword matching
    final result = TriageService.evaluate(
      symptomJson: symptomJson,
      transcript: _transcript,
      recentHistory: recentHistory,
    );

    setState(() => _triageResult = result);

    // Submit to Supabase
    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.submitCheckIn(
        patientId: widget.patientId,
        transcript: _transcript,
        symptomJson: symptomJson,
        triageStatus: result.status,
      );

      // Create alert if yellow or red
      if (result.status == 'red') {
        await SupabaseService.createAlert(
          patientId: widget.patientId,
          alertType: 'voice_keyword',
          triggerReason: result.reason,
          triageStatus: 'red',
        );
        // Send Twilio SMS to caregiver
        await SmsService.sendRedAlert(
          patientName: widget.patientName,
          caregiverPhone: SmsService.demoCaregiverPhone,
          reason: result.reason,
        );
      } else if (result.status == 'yellow') {
        await SupabaseService.createAlert(
          patientId: widget.patientId,
          alertType: 'voice_keyword',
          triggerReason: result.reason,
          triageStatus: 'yellow',
        );
      }

      // Streak: increment on green, reset on red/yellow
      if (result.status == 'green') {
        await SupabaseService.incrementStreak(widget.patientId);
      } else {
        await SupabaseService.updateStreak(widget.patientId, 0);
      }
    } catch (e) {
      // Offline fallback — cache locally and send SMS if red
      await OfflineService.cacheCheckIn(
        patientId: widget.patientId,
        transcript: _transcript,
        symptomJson: symptomJson,
        triageStatus: result.status,
      );

      if (result.status == 'red') {
        final cachedProfile = await OfflineService.getCachedProfile(widget.patientId);
        final caregiverPhone = cachedProfile?['caregiver']?['phone'] as String?;
        if (caregiverPhone != null) {
          await OfflineService.sendEmergencySMS(
            caregiverPhone: caregiverPhone,
            patientName: widget.patientName,
            reason: result.reason,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet — data saved locally. Will sync when reconnected.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    setState(() => _isSubmitting = false);
  }

  Future<void> _resetDemoData() async {
    setState(() => _isResettingDemo = true);
    try {
      final pid = widget.patientId;

      // Delete existing check-ins, alerts, bp_readings for this patient
      await SupabaseService.client.from('check_ins').delete().eq('patient_id', pid);
      await SupabaseService.client.from('alerts').delete().eq('patient_id', pid);
      await SupabaseService.client.from('bp_readings').delete().eq('patient_id', pid);

      // Insert 7 days of mock check-ins: green, green, green, yellow, green, green, green
      final statuses = ['green', 'green', 'green', 'yellow', 'green', 'green', 'green'];
      final transcripts = [
        'Feeling good today, took all my medicines',
        'Slept well, no pain at all',
        'Walked around the house, feeling stronger',
        'A little tired and some mild pain in my chest area',
        'Feeling better today, ate well',
        'Good day, did some light exercises',
        'Feeling great, recovery going well',
      ];

      for (var i = 0; i < 7; i++) {
        final ts = DateTime.now().subtract(Duration(days: 6 - i));
        await SupabaseService.client.from('check_ins').insert({
          'patient_id': pid,
          'transcript': transcripts[i],
          'symptom_json': {
            'symptom': statuses[i] == 'yellow' ? 'mild pain' : 'none',
            'severity': statuses[i] == 'yellow' ? 'medium' : 'none',
            'mood': 'good',
            'medications_taken': true,
          },
          'triage_status': statuses[i],
          'timestamp': ts.toIso8601String(),
        });
      }

      // Insert 2 normal BP readings
      await SupabaseService.client.from('bp_readings').insert({
        'patient_id': pid,
        'systolic': 118,
        'diastolic': 76,
        'timestamp': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });
      await SupabaseService.client.from('bp_readings').insert({
        'patient_id': pid,
        'systolic': 122,
        'diastolic': 80,
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });

      // Reset streak
      await SupabaseService.client
          .from('patients')
          .update({'streak_score': 5})
          .eq('id', pid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo data reset \u2705'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
    setState(() => _isResettingDemo = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'red':
        return 'NEEDS ATTENTION';
      case 'yellow':
        return 'MONITORING';
      default:
        return 'ALL CLEAR';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'red':
        return Icons.error_rounded;
      case 'yellow':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Voice Check-In', style: TextStyle(fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, _triageResult != null),
        ),
        actions: [
          // DEMO badge — only visible in demo mode
          if (DemoMode.isActive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Greeting — tap 5 times to toggle demo mode
                  GestureDetector(
                    onTap: _onNameTapped,
                    child: Text(
                      'Hello, ${widget.patientName}!',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListening ? 'Listening... speak now' : 'How are you feeling today?',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Sound wave visualization when listening
                  if (_isListening)
                    _buildSoundWaves(),

                  if (_isListening)
                    const SizedBox(height: 16),

                  // Mic button
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _isListening ? _stopListening : _startListening,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = _isListening ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulse ring
                                if (_isListening)
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 200 + (_pulseController.value * 30),
                                        height: 200 + (_pulseController.value * 30),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.2 - _pulseController.value * 0.15),
                                            width: 3,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isListening ? Colors.red : Colors.green).withOpacity(0.3),
                                          blurRadius: _isListening ? 30 : 12,
                                          spreadRadius: _isListening ? 8 : 0,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                      size: 72,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Transcript display - chat bubble style
                  if (_transcript.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                          child: const Icon(Icons.person, size: 20, color: Color(0xFF2E7D32)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withOpacity(0.08),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              _transcript,
                              style: const TextStyle(fontSize: 19, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Triage result - animated fade-in
                  if (_triageResult != null) ...[
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _statusColor(_triageResult!.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _statusColor(_triageResult!.status).withOpacity(0.3), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _statusIcon(_triageResult!.status),
                              color: _statusColor(_triageResult!.status),
                              size: 56,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusLabel(_triageResult!.status),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(_triageResult!.status),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _triageResult!.reason,
                              style: TextStyle(color: Colors.grey[700], fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            if (_isSubmitting) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _statusColor(_triageResult!.status),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Saving...',
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_isSubmitting)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Done', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],

                  if (!_speechAvailable && !DemoMode.isActive && _transcript.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Speech recognition not available on this device',
                        style: TextStyle(color: Colors.red[400], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            // Reset Demo Data button — bottom-right, only in demo mode
            if (DemoMode.isActive)
              Positioned(
                bottom: 16,
                right: 16,
                child: TextButton(
                  onPressed: _isResettingDemo ? null : _resetDemoData,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isResettingDemo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Reset Demo Data'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWaves() {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (i) {
              final phase = _waveController.value * 2 * pi + (i * 0.5);
              final height = 12.0 + (sin(phase) + 1) * 14;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 5,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5 + sin(phase) * 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
