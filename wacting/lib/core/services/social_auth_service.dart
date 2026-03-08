import 'dart:math';

// Represents the data structure returned by native OAuth SDKs (like GoogleSignIn)
class SocialUser {
  final String provider;
  final String providerId;
  final String? email;
  final String? displayName;

  SocialUser({
    required this.provider,
    required this.providerId,
    this.email,
    this.displayName,
  });
}

class SocialAuthService {
  // Mock implementations standing in for real GoogleSignIn / Facebook SDKs
  // This allows logic to build and compile seamlessly

  Future<SocialUser?> signInWithGoogle() async {
    print("Mock: Launching Google Accounts Popup...");
    await Future.delayed(const Duration(seconds: 1)); // Simulate network latency

    return SocialUser(
      provider: 'google',
      providerId: 'g_${Random().nextInt(999999)}',
      email: 'commander@gmail.com',
      displayName: 'Google Commander',
    );
  }

  Future<SocialUser?> signInWithFacebook() async {
    print("Mock: Launching Facebook Login Context...");
    await Future.delayed(const Duration(seconds: 1));

    return SocialUser(
      provider: 'facebook',
      providerId: 'fb_${Random().nextInt(999999)}',
      email: 'zuck@facebook.com',
      displayName: 'FB General',
    );
  }

  Future<SocialUser?> signInWithInstagram() async {
    print("Mock: Launching Instagram Webview...");
    await Future.delayed(const Duration(seconds: 1));

    return SocialUser(
      provider: 'instagram',
      providerId: 'ig_${Random().nextInt(999999)}',
      displayName: '@InstaLord',
    );
  }
}

// Global Singleton
final socialAuthService = SocialAuthService();
