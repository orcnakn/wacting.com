import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_button.dart';
import '../../app/widgets/modern_card.dart';
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
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController     = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
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

  void _handleSocialLogin(String provider) {
    final names = {'facebook': 'Facebook', 'instagram': 'Instagram', 'tiktok': 'TikTok', 'twitter': 'X (Twitter)'};
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${names[provider] ?? provider} girişi yakında aktif olacak.'),
      backgroundColor: const Color(0xFF1a1a2e),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _handleSignUp() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Gecerli bir email adresi girin.');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _errorMessage = 'Sifre en az 6 karakter olmali.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });
    try {
      final data = await apiService.emailRegister(email, password);
      if (data['needsVerification'] == true && mounted) {
        setState(() {
          _isLoading = false;
          _pendingVerificationEmail = email;
          _successMessage = 'Aktivasyon kodu $email adresine gonderildi.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  Future<void> _handleSignIn() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty) { setState(() => _errorMessage = 'Email gerekli.'); return; }
    if (password.isEmpty) { setState(() => _errorMessage = 'Sifre gerekli.'); return; }
    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });
    try {
      await apiService.emailLogin(email, password);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootNavigation()));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['needsVerification'] == true) {
        if (mounted) setState(() { _isLoading = false; _pendingVerificationEmail = email; _successMessage = 'Aktivasyon kodu $email adresine gonderildi.'; });
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) { setState(() => _errorMessage = '6 haneli aktivasyon kodunu girin.'); return; }
    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });
    try {
      await apiService.verifyCode(_pendingVerificationEmail!, code);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootNavigation()));
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  Future<void> _handleResendCode() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await apiService.resendVerification(_pendingVerificationEmail!);
      if (mounted) setState(() { _isLoading = false; _successMessage = 'Yeni kod gonderildi.'; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) return data['error'] ?? 'Bir hata olustu.';
    }
    return 'Baglanti hatasi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(children: [
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
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                const SizedBox(height: 8),
                Text('Establish your planetary dominance.', textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 48),
                if (_pendingVerificationEmail != null) _buildVerificationCard() else _buildAuthCard(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAuthCard() {
    return ModernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Social login section (FIRST) ───────────────────────────────────
        Text('Sosyal Hesabınla Giriş Yap',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildSocialBtn('Facebook', const Color(0xFF1877F2), _facebookIcon(), 'facebook')),
          const SizedBox(width: 12),
          Expanded(child: _buildSocialBtn('Instagram', const Color(0xFFE4405F), _instagramIcon(), 'instagram')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildSocialBtn('TikTok', const Color(0xFF010101), _tiktokIcon(), 'tiktok')),
          const SizedBox(width: 12),
          Expanded(child: _buildSocialBtn('X', const Color(0xFF14171A), _xIcon(), 'twitter')),
        ]),

        // ── Divider ────────────────────────────────────────────────────────
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: Divider(color: AppColors.surfaceLight, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('veya email ile devam et',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, letterSpacing: 1)),
          ),
          Expanded(child: Divider(color: AppColors.surfaceLight, thickness: 1)),
        ]),
        const SizedBox(height: 20),

        // ── Email form ─────────────────────────────────────────────────────
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Email', hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true, fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController, obscureText: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Şifre', hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true, fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_errorMessage!, style: TextStyle(color: AppColors.accentRed), textAlign: TextAlign.center),
          ),
        Row(children: [
          Expanded(child: ModernButton(text: _isLoading ? '...' : 'GİRİŞ', onPressed: _isLoading ? () {} : _handleSignIn)),
          const SizedBox(width: 12),
          Expanded(child: ModernButton(text: _isLoading ? '...' : 'KAYIT OL', onPressed: _isLoading ? () {} : _handleSignUp)),
        ]),
      ]),
    );
  }

  Widget _buildSocialBtn(String label, Color color, Widget icon, String provider) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _handleSocialLogin(provider),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _facebookIcon() => const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 22);
  Widget _instagramIcon() => Container(
    width: 22, height: 22,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFEDA77), Color(0xFFE4405F), Color(0xFF833AB4)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
  );
  Widget _tiktokIcon() => const Text('\u266a', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
  Widget _xIcon() => const Text('X', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));

  Widget _buildVerificationCard() {
    return ModernCard(
      child: Column(children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.navyPrimary),
        const SizedBox(height: 16),
        const Text('Email Dogrulama', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_pendingVerificationEmail!, style: TextStyle(color: AppColors.navyPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        const Text('Email adresinize gonderilen 6 haneli kodu girin.',
            style: TextStyle(color: Colors.white60, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
          decoration: InputDecoration(
            counterText: '', hintText: '------',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 12),
            filled: true, fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.navyPrimary)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.navyPrimary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: TextStyle(color: AppColors.accentRed, fontSize: 13), textAlign: TextAlign.center)),
        if (_successMessage != null)
          Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 13), textAlign: TextAlign.center)),
        ModernButton(text: _isLoading ? '...' : 'DOGRULA', onPressed: _isLoading ? () {} : _handleVerifyCode),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: _isLoading ? null : _handleResendCode,
            child: Text('Kodu tekrar gonder', style: TextStyle(color: AppColors.navyPrimary, fontSize: 13)),
          ),
          const Text(' | ', style: TextStyle(color: Colors.white24)),
          TextButton(
            onPressed: () => setState(() {
              _pendingVerificationEmail = null;
              _errorMessage = null;
              _successMessage = null;
              _codeController.clear();
            }),
            child: const Text('Geri don', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildBackgroundMap() {
    return StreamBuilder<List<IconModel>>(
      stream: socketService.iconStream, initialData: const [],
      builder: (context, snapshot) {
        final icons = snapshot.data ?? [];
        final markers = icons.map((icon) {
          final latLng = _offsetToLatLng(icon.position);
          final size = (icon.size * 2).clamp(4.0, 50.0).toDouble();
          return Marker(point: latLng, width: size, height: size,
            child: Container(decoration: BoxDecoration(color: icon.color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: icon.color.withOpacity(0.5), blurRadius: size / 2.0)])));
        }).toList();
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter, initialZoom: _currentZoom,
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
}
