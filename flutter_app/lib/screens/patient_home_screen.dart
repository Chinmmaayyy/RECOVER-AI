import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'voice_checkin_screen.dart';
import 'ocr_scanner_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  final String patientId;
  const PatientHomeScreen({super.key, required this.patientId});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with SingleTickerProviderStateMixin {
  late final String _patientId = widget.patientId;
  late AnimationController _pulseController;

  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _recentCheckIns = [];
  String _lastTriageStatus = 'green';
  int _streakScore = 0;
  Map<String, dynamic>? _nextAppointment;
  bool _isLoading = true;
  final Set<String> _takenMedIds = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  int _daysSinceDischarge() {
    final dischargeDate = _patient?['discharge_date'];
    if (dischargeDate == null) return 0;
    try {
      final dt = DateTime.parse(dischargeDate.toString());
      return DateTime.now().difference(dt).inDays;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadData() async {
    try {
      final patient = await SupabaseService.getPatientProfile(_patientId);
      final meds = await SupabaseService.getMedications(_patientId);
      final rxs = await SupabaseService.getPrescriptions(_patientId);
      final checkIns = await SupabaseService.getCheckIns(_patientId, limit: 7);
      final appointment = await SupabaseService.getNextAppointment(_patientId);

      setState(() {
        _patient = patient;
        _medications = meds;
        _prescriptions = rxs;
        _recentCheckIns = checkIns;
        _streakScore = patient?['streak_score'] ?? 0;
        _lastTriageStatus = checkIns.isNotEmpty ? checkIns.first['triage_status'] ?? 'green' : 'green';
        _nextAppointment = appointment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _triageColor(String status) {
    switch (status) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _triageIcon(String status) {
    switch (status) {
      case 'red':
        return Icons.warning_rounded;
      case 'yellow':
        return Icons.info_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  String _triageLabel(String status) {
    switch (status) {
      case 'red':
        return 'Needs Attention';
      case 'yellow':
        return 'Monitoring';
      default:
        return 'Looking Good';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _patient?['name'] ?? 'Patient';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22),
          tooltip: 'Switch Role',
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        title: Text('${_greeting()}, $name!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          // Streak badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
                const SizedBox(width: 4),
                Text('$_streakScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Today's Status - bigger, more prominent
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // Recovery progress
                  _buildRecoveryProgress(),
                  const SizedBox(height: 16),

                  // Streak card with 7-day dots
                  _buildStreakCard(),
                  const SizedBox(height: 20),

                  // TAP TO SPEAK - main CTA with pulse ring
                  _buildSpeakButton(),
                  const SizedBox(height: 20),

                  // OCR Scanner
                  _buildScannerButton(),
                  const SizedBox(height: 28),

                  // Medication checklist
                  _buildMedicationSection(),
                  const SizedBox(height: 20),

                  // Doctor Prescriptions
                  if (_prescriptions.isNotEmpty) ...[
                    _buildPrescriptionsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Next Appointment
                  if (_nextAppointment != null) _buildAppointmentCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final color = _triageColor(_lastTriageStatus);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(_triageIcon(_lastTriageStatus), color: color, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Status", style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  _triageLabel(_lastTriageStatus),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryProgress() {
    final days = _daysSinceDischarge();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up_rounded, color: Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recovery Journey', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  days > 0 ? 'Day $days since discharge' : 'Recovery started',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$days days',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _streakMessage(int streak) {
    if (streak >= 14) return 'Incredible recovery! \ud83c\udf33';
    if (streak >= 7) return 'One week strong! Arthur is proud. \ud83c\udf3f';
    if (streak >= 3) return "You're building a great habit! \ud83c\udf31";
    return 'Every day counts. Keep going! \ud83d\udcaa';
  }

  Color _dotColor(String status) {
    switch (status) {
      case 'red': return Colors.red;
      case 'yellow': return Colors.orange;
      case 'green': return const Color(0xFF4CAF50);
      default: return Colors.grey[300]!;
    }
  }

  /// Build a map of date -> triage_status for the last 7 days
  List<String> _last7DayStatuses() {
    final Map<String, String> dateStatusMap = {};
    for (final ci in _recentCheckIns) {
      final ts = ci['timestamp'];
      if (ts == null) continue;
      try {
        final date = DateTime.parse(ts.toString());
        final key = '${date.year}-${date.month}-${date.day}';
        // Keep the first (most recent) status for each day
        dateStatusMap.putIfAbsent(key, () => ci['triage_status'] ?? 'green');
      } catch (_) {}
    }

    final result = <String>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      result.add(dateStatusMap[key] ?? 'none');
    }
    return result;
  }

  Widget _buildStreakCard() {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final statuses = _last7DayStatuses();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Streak header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check-In Streak', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(
                      '$_streakScore day${_streakScore == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                    const SizedBox(width: 4),
                    Text('$_streakScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final dayIndex = (DateTime.now().subtract(Duration(days: 6 - i)).weekday - 1) % 7;
              return Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dotColor(statuses[i]),
                      border: statuses[i] == 'none'
                          ? Border.all(color: Colors.grey[300]!, width: 1.5)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabels[dayIndex],
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),

          // Motivational message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _streakMessage(_streakScore),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceCheckinScreen(patientId: _patientId, patientName: _patient?['name'] ?? 'Patient'),
          ),
        );
        if (result == true) _loadData();
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated pulse rings
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final val = _pulseController.value;
                return Container(
                  width: 100 + (val * 30),
                  height: 100 + (val * 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15 - val * 0.1),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final val = _pulseController.value;
                return Container(
                  width: 140 + (val * 30),
                  height: 140 + (val * 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08 - val * 0.05),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.mic_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'TAP TO SPEAK',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  'How are you feeling today?',
                  style: TextStyle(fontSize: 17, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
        color: const Color(0xFF2E7D32).withOpacity(0.05),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OCRScannerScreen(patientId: _patientId)),
          );
          if (result == true) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 28, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 16),
              const Text('Scan BP Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication_rounded, color: Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 10),
            Text("Today's Medications", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
            const Spacer(),
            // Progress indicator
            Text(
              '${_takenMedIds.length}/${_medications.length} taken',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: _takenMedIds.length == _medications.length && _medications.isNotEmpty
                    ? const Color(0xFF2E7D32) : Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        if (_medications.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _medications.isEmpty ? 0 : _takenMedIds.length / _medications.length,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _takenMedIds.length == _medications.length ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
              ),
            ),
          ),
        const SizedBox(height: 14),
        ..._medications.map((med) {
          final medId = med['id']?.toString() ?? med['name']?.toString() ?? '';
          final isTaken = _takenMedIds.contains(medId);
          final scheduleTime = med['schedule_time'] ?? '';

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isTaken) {
                  _takenMedIds.remove(medId);
                } else {
                  _takenMedIds.add(medId);
                  SupabaseService.verifyMedication(
                    patientId: _patientId,
                    medicationId: medId,
                    method: 'manual',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${med['name']} marked as taken!'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isTaken ? const Color(0xFF4CAF50).withOpacity(0.06) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTaken ? const Color(0xFF4CAF50).withOpacity(0.3) : Colors.grey[200]!,
                  width: isTaken ? 1.5 : 1,
                ),
                boxShadow: [
                  if (!isTaken)
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Pill icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isTaken ? const Color(0xFF4CAF50).withOpacity(0.12) : Colors.blue[50],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isTaken ? Icons.check_circle_rounded : Icons.medication_rounded,
                        color: isTaken ? const Color(0xFF4CAF50) : Colors.blue,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name'] ?? '',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              decoration: isTaken ? TextDecoration.lineThrough : null,
                              color: isTaken ? Colors.grey[500] : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isTaken ? Colors.green[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: isTaken ? Colors.green[400] : Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(scheduleTime, style: TextStyle(fontSize: 14, color: isTaken ? Colors.green[600] : Colors.grey[700])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Animated checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTaken ? const Color(0xFF4CAF50) : const Color(0xFF4CAF50).withOpacity(0.12),
                        border: Border.all(
                          color: isTaken ? const Color(0xFF4CAF50) : const Color(0xFF4CAF50).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 28,
                        color: isTaken ? Colors.white : const Color(0xFF2E7D32).withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrescriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.teal[700], size: 26),
            const SizedBox(width: 10),
            Text("Doctor's Prescriptions", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
          ],
        ),
        const SizedBox(height: 12),
        ..._prescriptions.map((rx) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication_liquid_rounded, color: Colors.teal[700], size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rx['medication'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${rx['dosage'] ?? ''} \u00b7 ${rx['frequency'] ?? ''}${rx['duration'] != null ? ' \u00b7 ${rx['duration']}' : ''}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (rx['notes'] != null && rx['notes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            rx['notes'],
                            style: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatAppointmentDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = dt.difference(now);

      String dayLabel;
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        dayLabel = 'Today';
      } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day != now.day)) {
        dayLabel = 'Tomorrow';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        dayLabel = '${dt.day} ${months[dt.month - 1]}';
      }

      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');

      return '$dayLabel at $hour:$min $ampm';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildAppointmentCard() {
    final doctor = _nextAppointment?['doctor'];
    final scheduledAt = _nextAppointment?['scheduled_at'] ?? '';
    final formattedDate = _formatAppointmentDate(scheduledAt.toString());

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Appointment', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  doctor != null ? doctor['name'] : 'Doctor',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(formattedDate, style: TextStyle(color: Colors.blue[700], fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
