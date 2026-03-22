import 'package:dio/dio.dart';

/// MyMemory ücretsiz çeviri API'si kullanır.
/// Limit: ~5000 kelime/gün (kayıtsız), e-posta ile 50K/gün.
/// Dokümantasyon: https://mymemory.translated.net/doc/spec.php
class TranslationService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// [text] çevrilecek metin, [targetLang] hedef dil kodu (örn. 'tr', 'de').
  /// Başarısız olursa null döner.
  static Future<String?> translate(String text, String targetLang) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {
          'q': text,
          'langpair': 'auto|$targetLang',
        },
      );

      final data = response.data;
      if (data is Map && data['responseStatus'] == 200) {
        final translated = data['responseData']?['translatedText'] as String?;
        // MyMemory bazen orijinal metni geri döner, bunu ele al
        if (translated != null && translated.toLowerCase() != text.toLowerCase()) {
          return translated;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
