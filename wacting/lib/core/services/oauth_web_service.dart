import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'api_service.dart';

/// Opens an OAuth popup window and listens for the JWT result via postMessage.
class OAuthWebService {
  static final OAuthWebService _instance = OAuthWebService._();
  factory OAuthWebService() => _instance;
  OAuthWebService._();

  /// Opens a popup to the OAuth start URL for [provider].
  /// Returns a map with {token, userId} on success, or throws on failure.
  Future<Map<String, dynamic>> startOAuth(String provider) async {
    final url = apiService.getOAuthStartUrl(provider);
    final completer = Completer<Map<String, dynamic>>();

    // Open popup
    final popup = html.window.open(url, 'oauth_popup',
        'width=500,height=700,scrollbars=yes,resizable=yes');

    // Listen for postMessage from the callback page
    late StreamSubscription<html.MessageEvent> sub;
    Timer? timeout;

    sub = html.window.onMessage.listen((event) {
      try {
        final data = jsonDecode(event.data as String);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('error')) {
            completer.completeError(Exception(data['error']));
          } else if (data.containsKey('token')) {
            completer.complete(data);
          }
          sub.cancel();
          timeout?.cancel();
          try { popup.close(); } catch (_) {}
        }
      } catch (_) {
        // Ignore non-JSON messages
      }
    });

    // Timeout after 5 minutes
    timeout = Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Giris zaman asimina ugradi.'));
        sub.cancel();
        try { popup.close(); } catch (_) {}
      }
    });

    // Also check if popup was closed manually
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (popup.closed == true && !completer.isCompleted) {
        completer.completeError(Exception('Giris penceresi kapatildi.'));
        sub.cancel();
        timeout?.cancel();
        timer.cancel();
      }
      if (completer.isCompleted) {
        timer.cancel();
      }
    });

    return completer.future;
  }
}

final oauthWebService = OAuthWebService();
