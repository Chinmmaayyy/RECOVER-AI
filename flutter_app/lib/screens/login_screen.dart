import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class _DemoUser {
  final String id;
  final String name;
  final String role; // 'patient' or 'caregiver'
  final String pin; // for patients
  final String email; // for caregivers
  final String password; // for caregivers
  final String subtitle;
  final String statusColor; // 'green', 'yellow', 'red'

  const _DemoUser({
    required this.id,
    required this.name,
    required this.role,
    this.pin = '',
    this.email = '',
    this.password = '',
    required this.subtitle,
    this.statusColor = 'green',
  });
}

const _demoPatients = [
  _DemoUser(id: 'a1000000-0000-0000-0000-000000000cc1', name: 'Arthur', role: 'patient', pin: '1234', subtitle: '72y  Post-CABG  PIN: 1234', statusColor: 'green'),
  _DemoUser(id: 'a2000000-0000-0000-0000-000000000cc2', name: 'Meera Iyer', role: 'patient', pin: '2345', subtitle: '68y  Post-Knee Replacement  PIN: 2345', statusColor: 'yellow'),
  _DemoUser(id: 'a3000000-0000-0000-0000-000000000cc3', name: 'Rajesh Kumar', role: 'patient', pin: '3456', subtitle: '65y  Post-CABG  PIN: 3456', statusColor: 'green'),
  _DemoUser(id: 'a4000000-0000-0000-0000-000000000cc4', name: 'Sunita Devi', role: 'patient', pin: '4567', subtitle: '70y  Post-Hip Replacement  PIN: 4567', statusColor: 'red'),
  _DemoUser(id: 'a5000000-0000-0000-0000-000000000cc5', name: 'Farhan Sheikh', role: 'patient', pin: '5678', subtitle: '45y  Post-Appendectomy  PIN: 5678', statusColor: 'green'),
];

const _demoCaregivers = [
  _DemoUser(id: 'c1000000-0000-0000-0000-000000000bb1', name: 'Elena', role: 'caregiver', email: 'elena@email.com', password: 'elena123', subtitle: 'Caring for Arthur'),
  _DemoUser(id: 'c2000000-0000-0000-0000-000000000bb2', name: 'Priya Sharma', role: 'caregiver', email: 'priya.sharma@gmail.com', password: 'priya123', subtitle: 'Caring for Meera Iyer'),
  _DemoUser(id: 'c3000000-0000-0000-0000-000000000bb3', name: 'Rahul Verma', role: 'caregiver', email: 'rahul.verma@gmail.com', password: 'rahul123', subtitle: 'Caring for Rajesh Kumar'),
  _DemoUser(id: 'c4000000-0000-0000-0000-000000000bb4', name: 'Anita Desai', role: 'caregiver', email: 'anita.desai@gmail.com', password: 'anita123', subtitle: 'Caring for Sunita Devi'),
  _DemoUser(id: 'c5000000-0000-0000-0000-000000000bb5', name: 'Vikram Patel', role: 'caregiver', email: 'vikram.patel@gmail.com', password: 'vikram123', subtitle: 'Caring for Farhan Sheikh'),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPatient = true;
  final _pinControllers = List.generate(4, (_) => TextEditingController());
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _pinControllers) {
      c.dispose();
    }
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginAsPatient() {
    final pin = _pinControllers.map((c) => c.text).join();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit PIN')),
      );
      return;
    }

    // Match PIN to demo patient
    final match = _demoPatients.where((p) => p.pin == pin).toList();
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PIN. Try: 1234, 2345, 3456, 4567, or 5678')),
      );
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pushReplacementNamed(context, '/patient', arguments: match.first.id);
    });
  }

  void _loginAsCaregiver() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    // Match credentials to demo caregiver
    final match = _demoCaregivers.where((c) => c.email == email && c.password == password).toList();
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials. Check the demo accounts below.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pushReplacementNamed(context, '/caregiver', arguments: match.first.id);
    });
  }

  void _quickLogin(_DemoUser user) {
    setState(() => _isLoading = true);
    final route = user.role == 'patient' ? '/patient' : '/caregiver';
    // For caregiver, pass the linked patient ID
    String argId = user.id;
    if (user.role == 'caregiver') {
      final idx = _demoCaregivers.indexOf(user);
      if (idx >= 0 && idx < _demoPatients.length) {
        argId = _demoPatients[idx].id;
      }
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.pushReplacementNamed(context, route, arguments: argId);
    });
  }

  Color _statusDotColor(String status) {
    switch (status) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.amber;
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF00897B),
              Color(0xFF00897B),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Logo area with heartbeat feel
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.monitor_heart_rounded, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RecoverAI',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Recovery Companion',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 28),

                // Login form card with elevation
                Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      children: [
                        // Role toggle
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Patient'), icon: Icon(Icons.person)),
                            ButtonSegment(value: false, label: Text('Caregiver'), icon: Icon(Icons.people)),
                          ],
                          selected: {_isPatient},
                          onSelectionChanged: (val) => setState(() => _isPatient = val.first),
                        ),
                        const SizedBox(height: 24),

                        if (_isPatient) _buildPatientLogin() else _buildCaregiverLogin(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Quick login section
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Quick Demo Login',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 16),
                ..._buildQuickLogins(),
                const SizedBox(height: 20),

                // Doctor Dashboard button
                Material(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF0F766E),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      launchUrl(
                        Uri.parse('http://localhost:3000'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.desktop_mac_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Doctor Dashboard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                                SizedBox(height: 2),
                                Text('Opens in browser (React web app)', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 18, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuickLogins() {
    final users = _isPatient ? _demoPatients : _demoCaregivers;
    return users.map((user) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          elevation: 2,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : () => _quickLogin(user),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar with status indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                        child: Text(
                          user.name[0],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2E7D32)),
                        ),
                      ),
                      if (_isPatient)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusDotColor(user.statusColor),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(user.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPatientLogin() {
    return Column(
      children: [
        Text('Enter your 4-digit PIN', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _pinControllers[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                obscureText: true,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.isNotEmpty && i < 3) {
                    FocusScope.of(context).nextFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isLoading ? null : _loginAsPatient,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enter', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverLogin() {
    return Column(
      children: [
        Text('Caregiver Login', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isLoading ? null : _loginAsCaregiver,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Sign In', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
