import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: WactingApp(),
    ),
  );
}

class WactingApp extends StatelessWidget {
  const WactingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wacting - The Global Grid',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E88E5), // Neon blue hints
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}
