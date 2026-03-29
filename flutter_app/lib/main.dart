import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/patient_home_screen.dart';
import 'screens/caregiver_home_screen.dart';
import 'screens/login_screen.dart';
import 'services/offline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://fqjriojizqnevfojirss.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZxanJpb2ppenFuZXZmb2ppcnNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3OTc4MTQsImV4cCI6MjA5MDM3MzgxNH0.6mg6oFQb0IQaU9x23ZJVxfZM0c8r0L9FZiVPvGw5E1A'),
  );

  // Initialize offline SQLite database
  try {
    await OfflineService.database;
  } catch (_) {
    // Non-fatal — offline cache will init on first use
  }

  runApp(const RecoverAIApp());
}

class RecoverAIApp extends StatelessWidget {
  const RecoverAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecoverAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        final args = settings.arguments as String?;
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/patient':
            return MaterialPageRoute(builder: (_) => PatientHomeScreen(patientId: args ?? 'a1000000-0000-0000-0000-000000000cc1'));
          case '/caregiver':
            return MaterialPageRoute(builder: (_) => CaregiverHomeScreen(patientId: args ?? 'a1000000-0000-0000-0000-000000000cc1'));
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}
