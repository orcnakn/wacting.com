import 'package:flutter/material.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/translation_service.dart';
import '../theme.dart';

/// Kullanıcı içeriğini (kampanya başlığı, açıklama vb.) çeviren düğme.
///
/// Kullanım:
/// ```dart
/// TranslateButton(
///   texts: {'title': campaign['title'], 'description': campaign['description']},
///   builder: (translated) => Column(children: [
///     Text(translated['title'] ?? campaign['title']),
///     Text(translated['description'] ?? campaign['description']),
///   ]),
/// )
/// ```
class TranslateButton extends StatefulWidget {
  /// Çevrilecek metin alanları. Key: alan adı, Value: orijinal metin.
  final Map<String, String?> texts;

  /// Çeviri sonucunu alan builder. Map içindeki değerler çevrilmiş ya da null olabilir.
  final Widget Function(Map<String, String?> translated) builder;

  const TranslateButton({
    super.key,
    required this.texts,
    required this.builder,
  });

  @override
  State<TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends State<TranslateButton> {
  Map<String, String?> _translated = {};
  bool _isTranslating = false;
  bool _isTranslated = false;

  Future<void> _doTranslate() async {
    setState(() => _isTranslating = true);

    final targetLang = localeService.locale;
    final results = <String, String?>{};

    for (final entry in widget.texts.entries) {
      final text = entry.value;
      if (text != null && text.isNotEmpty) {
        results[entry.key] = await TranslationService.translate(text, targetLang);
      }
    }

    if (mounted) {
      setState(() {
        _translated = results;
        _isTranslating = false;
        _isTranslated = true;
      });
    }
  }

  void _showOriginal() {
    setState(() {
      _translated = {};
      _isTranslated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.builder(_isTranslated ? _translated : {}),
        const SizedBox(height: 4),
        _isTranslating
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t('translating'),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: _isTranslated ? _showOriginal : _doTranslate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate,
                      size: 13,
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTranslated ? t('show_original') : t('translate'),
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}
