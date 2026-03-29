import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/supabase_service.dart';
import '../services/demo_mode.dart';

class OCRScannerScreen extends StatefulWidget {
  final String patientId;

  const OCRScannerScreen({super.key, required this.patientId});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  int? _systolic;
  int? _diastolic;
  String _statusMessage = 'Enter or say your BP reading';
  bool _submitted = false;
  String? _alertStatus;

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();

  late AnimationController _gaugeController;

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceText = '';

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _gaugeController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_voiceText.isNotEmpty) _parseVoiceBP(_voiceText);
        }
      },
    );
    setState(() {});
  }

  void _startVoiceInput() {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _voiceText = '';
      _statusMessage = 'Listening... Say your BP like "120 over 80"';
    });
    _speech.listen(
      onResult: (result) {
        setState(() => _voiceText = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _parseVoiceBP(String text) {
    final lower = text.toLowerCase();

    // Try patterns: "120 over 80", "120/80", "120 by 80", "120 80", "systolic 120 diastolic 80"
    int? sys, dia;

    // Pattern: "X over Y" or "X by Y" or "X slash Y"
    final overMatch = RegExp(r'(\d{2,3})\s*(?:over|by|slash|upon|on)\s*(\d{2,3})').firstMatch(lower);
    if (overMatch != null) {
      sys = int.tryParse(overMatch.group(1)!);
      dia = int.tryParse(overMatch.group(2)!);
    }

    // Pattern: "X/Y"
    if (sys == null) {
      final slashMatch = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(text);
      if (slashMatch != null) {
        sys = int.tryParse(slashMatch.group(1)!);
        dia = int.tryParse(slashMatch.group(2)!);
      }
    }

    // Pattern: just two numbers close together
    if (sys == null) {
      final nums = RegExp(r'\d{2,3}').allMatches(text).map((m) => int.tryParse(m.group(0)!)).whereType<int>().toList();
      if (nums.length >= 2) {
        // Higher number is systolic
        nums.sort((a, b) => b.compareTo(a));
        sys = nums[0];
        dia = nums[1];
      }
    }

    if (sys != null && dia != null && sys > 40 && sys < 250 && dia > 30 && dia < 200) {
      setState(() {
        _systolicController.text = sys.toString();
        _diastolicController.text = dia.toString();
        _statusMessage = 'Heard: $sys/$dia — Tap submit to confirm';
      });
    } else {
      setState(() {
        _statusMessage = 'Could not understand "$text"\nTry saying "120 over 80"';
      });
    }
  }

  Future<void> _submitBP() async {
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);

    if (systolic == null || diastolic == null) {
      setState(() => _statusMessage = 'Please enter valid numbers');
      return;
    }

    await _processBPReading(systolic, diastolic);
  }

  Future<void> _useDemoReading() async {
    await _processBPReading(160, 100);
  }

  Future<void> _processBPReading(int systolic, int diastolic) async {
    setState(() {
      _isProcessing = true;
      _systolic = systolic;
      _diastolic = diastolic;
      _statusMessage = 'Submitting BP: $systolic/$diastolic...';
    });

    try {
      await SupabaseService.submitBPReading(
        patientId: widget.patientId,
        systolic: systolic,
        diastolic: diastolic,
      );

      if (systolic > 150) {
        await SupabaseService.createAlert(
          patientId: widget.patientId,
          alertType: 'bp_threshold',
          triggerReason: 'Systolic BP $systolic > 150',
          triageStatus: 'red',
        );
        setState(() {
          _alertStatus = 'red';
          _statusMessage = 'HIGH BP ALERT -- Doctor notified';
        });
      } else {
        setState(() {
          _alertStatus = 'green';
          _statusMessage = 'BP Reading -- Normal range';
        });
      }

      _gaugeController.forward();
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _statusMessage = 'Error submitting. Please try again.');
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('BP Reading', style: TextStyle(fontSize: 22)),
        actions: [
          if (DemoMode.isActive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text('DEMO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_alertStatus == 'red' ? Colors.red : const Color(0xFF2E7D32)).withOpacity(0.1),
              ),
              child: Icon(
                Icons.monitor_heart_outlined,
                size: 44,
                color: _alertStatus == 'red' ? Colors.red : const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _alertStatus == 'red' ? Colors.red : (_alertStatus == 'green' ? const Color(0xFF2E7D32) : Colors.grey[800]),
              ),
              textAlign: TextAlign.center,
            ),

            // Voice listening indicator
            if (_isListening) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                      const SizedBox(width: 8),
                      Text(_voiceText.isEmpty ? 'Listening...' : '"$_voiceText"',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (!_submitted) ...[
              // ====== VOICE INPUT BUTTON (primary) ======
              GestureDetector(
                onTap: _isListening ? null : _startVoiceInput,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : Colors.green).withOpacity(0.3),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isListening ? Icons.hearing : Icons.mic_rounded,
                        size: 40, color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? 'Listening...' : 'SAY YOUR BP',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening ? 'e.g. "120 over 80"' : 'Tap and say "120 over 80"',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or type manually', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 16),

              // ====== MANUAL INPUT ======
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _systolicController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Systolic',
                              labelStyle: const TextStyle(fontSize: 16),
                              hintText: '120',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true, fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('/', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w300, color: Colors.grey)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _diastolicController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Diastolic',
                              labelStyle: const TextStyle(fontSize: 16),
                              hintText: '80',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true, fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _rangeIndicator('Normal', '<120/80', const Color(0xFF4CAF50)),
                          Container(width: 1, height: 28, color: Colors.grey[300]),
                          _rangeIndicator('Elevated', '120-139', Colors.orange),
                          Container(width: 1, height: 28, color: Colors.grey[300]),
                          _rangeIndicator('High', '>150', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Demo mode button
              if (DemoMode.isActive) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _useDemoReading,
                  icon: const Icon(Icons.science_outlined, size: 20),
                  label: const Text('Use Demo Reading (160/100)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],

            // Gauge result
            if (_systolic != null && _diastolic != null && _submitted) ...[
              const SizedBox(height: 8),
              _buildGaugeDisplay(),
            ],

            const SizedBox(height: 24),

            // Submit / Done button
            SizedBox(
              height: 60,
              child: _submitted
                  ? FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Done', style: TextStyle(fontSize: 22)),
                    )
                  : FilledButton.icon(
                      onPressed: _isProcessing ? null : _submitBP,
                      icon: _isProcessing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 26),
                      label: Text(_isProcessing ? 'Submitting...' : 'Submit BP Reading', style: const TextStyle(fontSize: 22)),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeIndicator(String label, String range, Color color) {
    return Column(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        Text(range, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildGaugeDisplay() {
    final isHigh = _systolic! > 150;
    final isDiastolicHigh = _diastolic! > 90;
    final mainColor = isHigh ? Colors.red : const Color(0xFF4CAF50);

    return AnimatedBuilder(
      animation: _gaugeController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: mainColor.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 200, height: 120,
                child: CustomPaint(painter: _BPGaugePainter(systolic: _systolic!, progress: _gaugeController.value, color: mainColor)),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(children: [
                  TextSpan(text: '$_systolic', style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: isHigh ? Colors.red : const Color(0xFF2E7D32))),
                  TextSpan(text: '/', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Colors.grey[400])),
                  TextSpan(text: '$_diastolic', style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: isDiastolicHigh ? Colors.orange : const Color(0xFF2E7D32))),
                ]),
              ),
              const SizedBox(height: 4),
              Text('mmHg', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(color: mainColor.withOpacity(0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: mainColor.withOpacity(0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isHigh ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: mainColor, size: 22),
                    const SizedBox(width: 8),
                    Text(isHigh ? 'HIGH - Alert Sent' : 'Normal Range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: mainColor)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BPGaugePainter extends CustomPainter {
  final int systolic;
  final double progress;
  final Color color;

  _BPGaugePainter({required this.systolic, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 16;

    final bgPaint = Paint()..color = Colors.grey[200]!..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi, false, bgPaint);

    final normalized = ((systolic - 80) / 120).clamp(0.0, 1.0);
    final sweepAngle = pi * normalized * progress;
    final valuePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, sweepAngle, false, valuePaint);

    final tickPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 1.5;
    final normalAngle = pi + pi * ((120 - 80) / 120);
    canvas.drawLine(
      Offset(center.dx + (radius - 12) * cos(normalAngle), center.dy + (radius - 12) * sin(normalAngle)),
      Offset(center.dx + (radius + 12) * cos(normalAngle), center.dy + (radius + 12) * sin(normalAngle)),
      tickPaint,
    );
    final highAngle = pi + pi * ((150 - 80) / 120);
    canvas.drawLine(
      Offset(center.dx + (radius - 12) * cos(highAngle), center.dy + (radius - 12) * sin(highAngle)),
      Offset(center.dx + (radius + 12) * cos(highAngle), center.dy + (radius + 12) * sin(highAngle)),
      tickPaint..color = Colors.red[300]!,
    );
  }

  @override
  bool shouldRepaint(covariant _BPGaugePainter old) => old.progress != progress || old.systolic != systolic;
}
