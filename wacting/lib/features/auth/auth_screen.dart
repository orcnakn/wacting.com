import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // null = login/register ekranı, email = kod doğrulama ekranı
  String? _pendingVerificationEmail;

  final MapController _mapController = MapController();
  final double _currentZoom = 3.0;
  final LatLng _initialCenter = const LatLng(41.0082, 28.9784);

  @override
  void initState() {
    super.initState();
    socketService.connect(AppConfig.socketUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  LatLng _offsetToLatLng(Offset pos) {
    double lng = (pos.dx / 510) * 360 - 180;
    double lat = 90 - (pos.dy / 510) * 180;
    return LatLng(lat, lng);
  }

  // ── SIGN UP ────────────────────────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = "Gecerli bir email adresi girin.");
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _errorMessage = "Sifre en az 6 karakter olmali.");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      final data = await apiService.emailRegister(email, password);

      if (data['needsVerification'] == true) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _pendingVerificationEmail = email;
            _successMessage = 'Aktivasyon kodu $email adresine gonderildi.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractError(e);
        });
      }
    }
  }

  // ── SIGN IN ────────────────────────────────────────────────────────────────
  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = "Email gerekli.");
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = "Sifre gerekli.");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      await apiService.emailLogin(email, password);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigation()),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['needsVerification'] == true) {
        // Email doğrulanmamış — kod ekranına yönlendir
        if (mounted) {
          setState(() {
            _isLoading = false;
            _pendingVerificationEmail = email;
            _successMessage = 'Aktivasyon kodu $email adresine gonderildi.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = _extractError(e);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractError(e);
        });
      }
    }
  }

  // ── VERIFY CODE ────────────────────────────────────────────────────────────
  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = "6 haneli aktivasyon kodunu girin.");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      await apiService.verifyCode(_pendingVerificationEmail!, code);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractError(e);
        });
      }
    }
  }

  // ── RESEND CODE ────────────────────────────────────────────────────────────
  Future<void> _handleResendCode() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await apiService.resendVerification(_pendingVerificationEmail!);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Yeni kod gonderildi.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractError(e);
        });
      }
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) return data['error'] ?? 'Bir hata olustu.';
    }
    return 'Baglanti hatasi.';
  }

  Future<void> _handleSocialAuth(String provider) async {
    setState(() { _isLoading = true; _errorMessage = null; });

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
        setState(() { _isLoading = false; _errorMessage = "Sosyal giris iptal edildi."; });
        return;
      }

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigation()),
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = "Ag hatasi."; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          _buildBackgroundMap(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.public, size: 80, color: AppColors.navyPrimary),
                  const SizedBox(height: 24),
                  Text('WACTING', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 8),
                  Text('Establish your planetary dominance.', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 48),

                  if (_pendingVerificationEmail != null)
                    _buildVerificationCard()
                  else
                    _buildLoginCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── LOGIN / REGISTER CARD ─────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return ModernCard(
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Sifre (en az 6 karakter)',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(_errorMessage!, style: TextStyle(color: AppColors.accentRed), textAlign: TextAlign.center),
            ),
          Row(
            children: [
              Expanded(
                child: ModernButton(
                  text: _isLoading ? '...' : 'SIGN IN',
                  onPressed: _isLoading ? () {} : _handleSignIn,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ModernButton(
                  text: _isLoading ? '...' : 'SIGN UP',
                  onPressed: _isLoading ? () {} : _handleSignUp,
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
    );
  }

  // ── VERIFICATION CODE CARD ────────────────────────────────────────────────
  Widget _buildVerificationCard() {
    return ModernCard(
      child: Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.navyPrimary),
          const SizedBox(height: 16),
          Text('Email Dogrulama', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_pendingVerificationEmail!, style: TextStyle(color: AppColors.navyPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Email adresinize gonderilen 6 haneli kodu girin.', style: TextStyle(color: Colors.white60, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // 6-digit code input
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 12),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.navyPrimary)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.navyPrimary, width: 2)),
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(_errorMessage!, style: TextStyle(color: AppColors.accentRed, fontSize: 13), textAlign: TextAlign.center),
            ),
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(_successMessage!, style: TextStyle(color: Colors.green, fontSize: 13), textAlign: TextAlign.center),
            ),

          ModernButton(
            text: _isLoading ? '...' : 'DOGRULA',
            onPressed: _isLoading ? () {} : _handleVerifyCode,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isLoading ? null : _handleResendCode,
                child: Text('Kodu tekrar gonder', style: TextStyle(color: AppColors.navyPrimary, fontSize: 13)),
              ),
              Text(' | ', style: TextStyle(color: Colors.white24)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _pendingVerificationEmail = null;
                    _errorMessage = null;
                    _successMessage = null;
                    _codeController.clear();
                  });
                },
                child: Text('Geri don', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
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
            point: latLng, width: size, height: size,
            child: Container(
              decoration: BoxDecoration(
                color: icon.color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: icon.color.withOpacity(0.5), blurRadius: size / 2.0)],
              ),
            ),
          );
        }).toList();

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _currentZoom,
            cameraConstraint: CameraConstraint.contain(bounds: LatLngBounds(const LatLng(-90, -180), const LatLng(90, 180))),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd'], userAgentPackageName: 'com.wacting.app'),
            const DayNightLayer(),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Widget _buildSocialIcon(IconData icon, String provider, Color color) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _handleSocialAuth(provider),
      child: Container(
        height: 56, width: 56,
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
