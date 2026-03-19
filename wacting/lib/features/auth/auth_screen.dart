import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/oauth_web_service.dart';
import '../../core/config/app_config.dart';
import '../root_navigation.dart';
import 'auth_background_animation.dart';

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

  // unused — text animation is now on the W marker

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

  Future<void> _handleSocialLogin(String provider) async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await oauthWebService.startOAuth(provider);
      final token = result['token'] as String?;
      final userId = result['userId'] as String?;
      if (token != null && userId != null) {
        apiService.handleSocialLoginResult(token, userId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RootNavigation()),
          );
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Giris basarisiz.'; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
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

  void _onMerge(bool merging) {
    // merge event handled inside animation widget now
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: Stack(children: [
        // ── Animated background ──
        Positioned.fill(
          child: AuthBackgroundAnimation(onMerge: _onMerge),
        ),

        // ── Content ──
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Social login icons (replacing the D logo) ──
                  _buildSocialIconsRow(),
                  const SizedBox(height: 32),

                  // ── Login / Verification form ──
                  if (_pendingVerificationEmail != null)
                    _buildVerificationCard()
                  else
                    _buildLoginCard(),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Social login icon row (circular icons)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSocialIconsRow() {
    final socials = [
      _SocialDef('facebook', const Color(0xFF1877F2), Icons.facebook),
      _SocialDef('instagram', const Color(0xFFE4405F), Icons.camera_alt),
      _SocialDef('twitter', const Color(0xFFEEEEEE), null, 'X'),
      _SocialDef('linkedin', const Color(0xFF0A66C2), Icons.work),
      _SocialDef('apple', const Color(0xFFAAAAAA), Icons.apple),
      _SocialDef('tiktok', const Color(0xFF69C9D0), Icons.music_note),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: socials.map((s) {
        return GestureDetector(
          onTap: _isLoading ? null : () => _handleSocialLogin(s.provider),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.color.withOpacity(0.15),
                border: Border.all(color: s.color.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: s.color.withOpacity(0.2), blurRadius: 10),
                ],
              ),
              child: Center(
                child: s.textLabel != null
                    ? Text(s.textLabel!,
                        style: TextStyle(
                            color: s.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900))
                    : Icon(s.icon, color: s.color, size: 20),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login card (Divi-style: translucent, rounded fields, gradient button)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: [
        // ── Username / Email field ──
        _buildField(
          controller: _emailController,
          hint: 'Username',
          icon: Icons.person_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // ── Password field ──
        _buildField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const SizedBox(height: 24),

        // ── Error message ──
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                textAlign: TextAlign.center),
          ),

        // ── Log In button (gradient) ──
        SizedBox(
          width: double.infinity,
          height: 50,
          child: GestureDetector(
            onTap: _isLoading ? null : _handleSignIn,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF416C).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Log In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Sign Up link ──
        GestureDetector(
          onTap: _isLoading ? null : _handleSignUp,
          child: Text('Hesabin yok mu? Kayit Ol',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              )),
        ),
        const SizedBox(height: 8),

        // ── Lost your password ──
        GestureDetector(
          onTap: () {},
          child: Text('Lost your password?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              )),
        ),
      ]),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verification card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVerificationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: Color(0xFFFF416C)),
        const SizedBox(height: 16),
        const Text('Email Dogrulama',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_pendingVerificationEmail!,
            style: const TextStyle(color: Color(0xFFFF416C), fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('Email adresinize gonderilen 6 haneli kodu girin.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 28, letterSpacing: 12),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        if (_successMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_successMessage!,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                textAlign: TextAlign.center),
          ),
        // Verify button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: GestureDetector(
            onTap: _isLoading ? null : _handleVerifyCode,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF416C).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('DOGRULA',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: _isLoading ? null : _handleResendCode,
            child: const Text('Kodu tekrar gonder',
                style: TextStyle(color: Color(0xFFFF416C), fontSize: 13)),
          ),
          Text(' | ', style: TextStyle(color: Colors.white.withOpacity(0.2))),
          TextButton(
            onPressed: () => setState(() {
              _pendingVerificationEmail = null;
              _errorMessage = null;
              _successMessage = null;
              _codeController.clear();
            }),
            child: Text('Geri don',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ),
        ]),
      ]),
    );
  }
}

class _SocialDef {
  final String provider;
  final Color color;
  final IconData? icon;
  final String? textLabel;
  const _SocialDef(this.provider, this.color, this.icon, [this.textLabel]);
}
