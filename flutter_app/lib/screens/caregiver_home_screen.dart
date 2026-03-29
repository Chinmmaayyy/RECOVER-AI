import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class CaregiverHomeScreen extends StatefulWidget {
  final String patientId;
  const CaregiverHomeScreen({super.key, required this.patientId});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  late final String _patientId = widget.patientId;

  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _checkIns = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _bpReadings = [];
  bool _isLoading = true;
  Set<String> _dismissedAlerts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToAlerts();
  }

  Future<void> _loadData() async {
    try {
      final patient = await SupabaseService.getPatientProfile(_patientId);
      final checkIns = await SupabaseService.getCheckIns(_patientId, limit: 7);
      final alerts = await SupabaseService.getAlerts(_patientId);
      final meds = await SupabaseService.getMedications(_patientId);
      final rxs = await SupabaseService.getPrescriptions(_patientId);
      final bp = await SupabaseService.getBPReadings(_patientId);

      setState(() {
        _patient = patient;
        _checkIns = checkIns;
        _alerts = alerts;
        _medications = meds;
        _prescriptions = rxs;
        _bpReadings = bp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToAlerts() {
    SupabaseService.subscribeToAlerts(_patientId, (alert) {
      _loadData(); // Refresh on new alert

      // Show red alert snackbar notification
      if (alert['triage_status'] == 'red' && mounted) {
        final patientName = _patient?['name'] ?? 'Patient';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '\u26a0\ufe0f New Red Alert for $patientName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Color _triageColor(String status) {
    switch (status) {
      case 'red': return Colors.red;
      case 'yellow': return Colors.orange;
      default: return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _patient?['name'] ?? 'Patient';
    final lastCheckIn = _checkIns.isNotEmpty ? _checkIns.first : null;
    final currentStatus = lastCheckIn?['triage_status'] ?? 'green';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22),
          tooltip: 'Switch Role',
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        title: Row(
          children: [
            // Patient photo placeholder avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: _triageColor(currentStatus).withOpacity(0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: TextStyle(fontWeight: FontWeight.bold, color: _triageColor(currentStatus), fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Text('Caring for $name'),
          ],
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current status card
                  _buildStatusCard(currentStatus, lastCheckIn),
                  const SizedBox(height: 16),

                  // Alert banner (only on yellow/red)
                  ..._buildAlertBanners(),

                  // Last voice transcript
                  if (lastCheckIn != null) ...[
                    const SizedBox(height: 16),
                    _buildTranscriptCard(lastCheckIn),
                  ],

                  // Medication verification
                  const SizedBox(height: 16),
                  _buildMedicationPanel(),

                  // Doctor Prescriptions
                  if (_prescriptions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPrescriptionsPanel(),
                  ],

                  // 7-day history
                  const SizedBox(height: 16),
                  _buildHistoryTimeline(),

                  // Quick actions
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(String status, Map<String, dynamic>? lastCheckIn) {
    final statusLabel = status == 'green' ? 'Stable' : status == 'yellow' ? 'Monitoring' : 'Needs Attention';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [_triageColor(status), _triageColor(status).withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _triageColor(status).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Icon(
                status == 'green' ? Icons.check_circle : status == 'yellow' ? Icons.warning : Icons.error,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last check-in: ${_formatTime(lastCheckIn?['timestamp'])}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAlertBanners() {
    final activeAlerts = _alerts.where((a) =>
      a['triage_status'] != 'green' &&
      !_dismissedAlerts.contains(a['id']?.toString() ?? '')
    ).toList();

    if (activeAlerts.isEmpty) return [];

    return activeAlerts.take(3).map((alert) {
      final alertId = alert['id']?.toString() ?? '';
      final isRed = alert['triage_status'] == 'red';
      final alertColor = isRed ? Colors.red : Colors.orange;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: alertColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alertColor.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alertColor.withOpacity(0.15),
                ),
                child: Icon(Icons.notification_important, color: alertColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert: ${alert['alert_type'] ?? ''}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: alertColor, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(alert['trigger_reason'] ?? '', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                onPressed: () {
                  setState(() => _dismissedAlerts.add(alertId));
                },
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTranscriptCard(Map<String, dynamic> checkIn) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.record_voice_over, color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Last Voice Check-In', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                checkIn['transcript'] ?? 'No transcript available',
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationPanel() {
    // Calculate a simple adherence percentage for demo
    final totalMeds = _medications.length;
    final takenCount = (totalMeds * 0.7).round(); // Simulated for demo
    final percentage = totalMeds > 0 ? (takenCount / totalMeds) : 0.0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication_rounded, color: Color(0xFF2E7D32), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Medication Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${(percentage * 100).round()}% taken',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: percentage >= 0.8 ? const Color(0xFF2E7D32) : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 10,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 0.8 ? const Color(0xFF4CAF50) : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._medications.map((med) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medication_rounded, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(med['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(med['schedule_time'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsPanel() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: Colors.teal[700], size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("Doctor's Prescriptions", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_prescriptions.length} Rx',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ..._prescriptions.map((rx) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.medication_liquid_rounded, color: Colors.teal[600], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rx['medication'] ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${rx['dosage'] ?? ''} \u00b7 ${rx['frequency'] ?? ''}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          if (rx['notes'] != null && rx['notes'].toString().isNotEmpty)
                            Text(
                              rx['notes'],
                              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    if (rx['duration'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rx['duration'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTimeline() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.timeline_rounded, color: Colors.purple[400], size: 22),
                ),
                const SizedBox(width: 12),
                Text('7-Day History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            ..._checkIns.asMap().entries.map((entry) {
              final index = entry.key;
              final checkIn = entry.value;
              final status = checkIn['triage_status'] ?? 'green';
              final isLast = index == _checkIns.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline dots and line
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _triageColor(status),
                              border: Border.all(color: _triageColor(status).withOpacity(0.3), width: 3),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey[200],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    checkIn['transcript'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, height: 1.4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(checkIn['timestamp']),
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.phone,
            label: 'Call Patient',
            color: const Color(0xFF2E7D32),
            onTap: () => launchUrl(Uri.parse('tel:${_patient?['phone'] ?? ''}')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: Icons.medical_services,
            label: 'Message Doctor',
            color: Colors.blue,
            onTap: () {
              // TODO: implement messaging
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return '';
    }
  }
}
