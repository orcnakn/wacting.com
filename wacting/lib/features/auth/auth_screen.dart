import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_button.dart';
import '../../app/widgets/modern_card.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/icon_model.dart';
import '../../core/config/app_config.dart';
import '../root_navigation.dart';
import '../grid/day_night_layer.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final MapController _mapController = MapController();
  final double _currentZoom = 3.0;
  final LatLng _initialCenter = const LatLng(41.0082, 28.9784); // Istanbul

  @override
  void initState() {
    super.initState();
    socketService.connect(AppConfig.socketUrl);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    // socketService.dispose(); // Don't dispose here, because RootNavigation uses it
    super.dispose();
  }

  LatLng _offsetToLatLng(Offset pos) {
    double lng = (pos.dx / 510) * 360 - 180;
    double lat = 90 - (pos.dy / 510) * 180;
    return LatLng(lat, lng);
  }

  Future<void> _handleAuth(bool isSignUp) async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = "Email is required.");
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (isSignUp) {
        await apiService.emailRegister(email, password);
      } else {
        await apiService.emailLogin(email, password);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigation()),
        );
      }
    } catch (e) {
      String msg = 'Authentication failed.';
      if (e is DioException && e.response?.data != null) {
        msg = (e.response!.data as Map<String, dynamic>)['error'] ?? msg;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  Future<void> _handleSocialAuth(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SocialUser? socialUser;
      if (provider == 'google') {
        socialUser = await socialAuthService.signInWithGoogle();
      } else if (provider == 'facebook') {
        socialUser = await socialAuthService.signInWithFacebook();
      } else if (provider == 'instagram') {
        socialUser = await socialAuthService.signInWithInstagram();
      }

      if (socialUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Social authentication was cancelled.";
        });
        return;
      }

      // Simulated API Transmit to Wacting.com Node Backend
      await Future.delayed(const Duration(seconds: 1));

      print("Logged in via $provider in Mock Mode!");

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigation()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Network Error: Could not reach authorization server.";
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Keep dark for map background
      body: Stack(
        children: [
          // Background animated map
          _buildBackgroundMap(),

          // Auth Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.public, size: 80, color: AppColors.navyPrimary),
                  const SizedBox(height: 24),
                  Text(
                    'WACTING',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Establish your planetary dominance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  ModernCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Commander name or email',
                            hintStyle: TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(_errorMessage!, style: TextStyle(color: AppColors.accentRed)),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: ModernButton(
                                text: _isLoading ? '...' : 'SIGN IN',
                                onPressed: _isLoading ? () {} : () => _handleAuth(false),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ModernButton(
                                text: _isLoading ? '...' : 'SIGN UP',
                                onPressed: _isLoading ? () {} : () => _handleAuth(true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text('OR CONTINUE WITH', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, letterSpacing: 2)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSocialIcon(Icons.apple, 'google', const Color(0xFFDB4437)),
                            _buildSocialIcon(Icons.facebook, 'facebook', const Color(0xFF4267B2)),
                            _buildSocialIcon(Icons.camera_alt, 'instagram', const Color(0xFFC13584)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundMap() {
    return StreamBuilder<List<IconModel>>(
      stream: socketService.iconStream,
      initialData: const [],
      builder: (context, snapshot) {
        final icons = snapshot.data ?? [];

        final markers = icons.map((icon) {
            final latLng = _offsetToLatLng(icon.position);
            final size = (icon.size * 2).clamp(4.0, 50.0).toDouble();

            return Marker(
              point: latLng,
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  color: icon.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: icon.color.withOpacity(0.5), blurRadius: size/2.0),
                  ]
                ),
              ),
            );
        }).toList();

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _currentZoom,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-90, -180),
                const LatLng(90, 180),
              ),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none, // Map is non-interactive here
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.wacting.app',
            ),
            const DayNightLayer(),
            MarkerLayer(markers: markers),
          ],
        );
      }
    );
  }

  Widget _buildSocialIcon(IconData icon, String provider, Color color) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _handleSocialAuth(provider),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
