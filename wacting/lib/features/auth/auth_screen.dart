import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/oauth_web_service.dart';
import '../../core/services/locale_service.dart';
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
  final TextEditingController _rePasswordController = TextEditingController();
  final TextEditingController _codeController     = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _rePasswordFocus = FocusNode();

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureRePassword = true;
  bool _agreedToTerms = false;
  String? _errorMessage;
  String? _successMessage;
  String? _pendingVerificationEmail;

  @override
  void initState() {
    super.initState();
    socketService.connect(AppConfig.socketUrl);
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _rePasswordFocus.addListener(() => setState(() {}));
    localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    _codeController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _rePasswordFocus.dispose();
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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
        if (mounted) setState(() { _isLoading = false; _errorMessage = t('login_failed'); });
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
    final rePassword = _rePasswordController.text.trim();
    if (!_agreedToTerms) {
      setState(() => _errorMessage = t('terms_required'));
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = t('valid_email'));
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _errorMessage = t('password_min'));
      return;
    }
    if (password != rePassword) {
      setState(() => _errorMessage = t('passwords_mismatch'));
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });
    try {
      final data = await apiService.emailRegister(email, password);
      if (data['needsVerification'] == true && mounted) {
        setState(() {
          _isLoading = false;
          _pendingVerificationEmail = email;
          _successMessage = t('activation_sent').replaceAll('{email}', email);
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  Future<void> _handleSignIn() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty) { setState(() => _errorMessage = t('email_required')); return; }
    if (password.isEmpty) { setState(() => _errorMessage = t('password_required')); return; }
    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });
    try {
      await apiService.emailLogin(email, password);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootNavigation()));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['needsVerification'] == true) {
        if (mounted) setState(() { _isLoading = false; _pendingVerificationEmail = email; _successMessage = t('activation_sent').replaceAll('{email}', email); });
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) { setState(() => _errorMessage = t('enter_6digit')); return; }
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
      if (mounted) setState(() { _isLoading = false; _successMessage = t('new_code_sent'); });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = _extractError(e); });
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) return data['error'] ?? t('error_occurred');
    }
    return t('connection_error');
  }

  void _onMerge(bool merging) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: Stack(children: [
        Positioned.fill(
          child: AuthBackgroundAnimation(onMerge: _onMerge),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Language switcher
                  _buildLanguageSwitcher(),
                  const SizedBox(height: 20),
                  _buildSocialIconsRow(),
                  const SizedBox(height: 32),
                  if (_pendingVerificationEmail != null)
                    _buildVerificationCard()
                  else if (_isRegisterMode)
                    _buildRegisterCard()
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

  Widget _buildLanguageSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _langChip('TR', 'tr'),
        const SizedBox(width: 8),
        _langChip('EN', 'en'),
      ],
    );
  }

  Widget _langChip(String label, String locale) {
    final isSelected = localeService.locale == locale;
    return GestureDetector(
      onTap: () => localeService.setLocale(locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? const Color(0xFFFF416C) : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF416C) : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        )),
      ),
    );
  }

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
  // Login card
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
        _buildField(
          controller: _emailController,
          focusNode: _emailFocus,
          hint: t('email'),
          icon: Icons.person_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: t('password'),
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                textAlign: TextAlign.center),
          ),

        _buildGradientButton(t('login'), _isLoading ? null : _handleSignIn),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _isLoading ? null : () {
            setState(() {
              _isRegisterMode = true;
              _errorMessage = null;
              _emailController.clear();
              _passwordController.clear();
            });
          },
          child: Text(t('no_account'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              )),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {},
          child: Text(t('lost_password'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              )),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Register card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRegisterCard() {
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
        Text(t('register'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildField(
          controller: _emailController,
          focusNode: _emailFocus,
          hint: t('email'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: t('password'),
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _rePasswordController,
          focusNode: _rePasswordFocus,
          hint: t('password_confirm'),
          icon: Icons.lock_outline,
          obscure: _obscureRePassword,
          onToggleObscure: () => setState(() => _obscureRePassword = !_obscureRePassword),
        ),
        const SizedBox(height: 20),

        // Terms agreement checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                activeColor: const Color(0xFFFF416C),
                checkColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _showTermsDialog(),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4),
                    children: [
                      TextSpan(text: '${t('terms_agree')} '),
                      TextSpan(
                        text: t('read_terms'),
                        style: const TextStyle(
                          color: Color(0xFFFF416C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFFF416C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                textAlign: TextAlign.center),
          ),

        _buildGradientButton(t('register'), _isLoading ? null : _handleSignUp),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _isLoading ? null : () {
            setState(() {
              _isRegisterMode = false;
              _errorMessage = null;
              _agreedToTerms = false;
              _emailController.clear();
              _passwordController.clear();
              _rePasswordController.clear();
            });
          },
          child: Text(t('has_account'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              )),
        ),
      ]),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1A1533),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.description_outlined, color: Color(0xFFFF416C), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('terms_title'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
            Divider(color: Colors.white.withOpacity(0.1)),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  t('terms_content'),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF416C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() => _agreedToTerms = true);
                  Navigator.pop(ctx);
                },
                child: Text(t('terms_accept'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared field builder with focus highlight + password eye toggle
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isFocused
              ? const Color(0xFFFF416C)
              : Colors.white.withOpacity(0.15),
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isFocused ? const Color(0xFFFF416C) : Colors.white54, size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
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
  // Gradient button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGradientButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: GestureDetector(
        onTap: onTap,
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
                : Text(label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    )),
          ),
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
        Text(t('email_verification'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_pendingVerificationEmail!,
            style: const TextStyle(color: Color(0xFFFF416C), fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(t('verification_hint'),
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
        _buildGradientButton(t('verify'), _isLoading ? null : _handleVerifyCode),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: _isLoading ? null : _handleResendCode,
            child: Text(t('resend_code'),
                style: const TextStyle(color: Color(0xFFFF416C), fontSize: 13)),
          ),
          Text(' | ', style: TextStyle(color: Colors.white.withOpacity(0.2))),
          TextButton(
            onPressed: () => setState(() {
              _pendingVerificationEmail = null;
              _errorMessage = null;
              _successMessage = null;
              _codeController.clear();
            }),
            child: Text(t('go_back'),
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
