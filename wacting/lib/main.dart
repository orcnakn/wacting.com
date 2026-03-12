import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
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
      theme: AppTheme.lightTheme(),
      home: const AuthScreen(),
    );
  }
}
