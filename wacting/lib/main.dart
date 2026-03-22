import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'core/services/api_service.dart';
import 'core/services/locale_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/root_navigation.dart';

void main() {
  runApp(
    const ProviderScope(
      child: WactingApp(),
    ),
  );
}

class WactingApp extends StatefulWidget {
  const WactingApp({super.key});

  @override
  State<WactingApp> createState() => _WactingAppState();
}

class _WactingAppState extends State<WactingApp> {
  bool _checking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _init();
    localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    await localeService.init();
    final restored = await ApiService().tryRestoreSession();
    if (mounted) {
      setState(() {
        _hasSession = restored;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wacting - The Global Grid',
      theme: AppTheme.lightTheme(),
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_hasSession ? const RootNavigation() : const AuthScreen()),
    );
  }
}
