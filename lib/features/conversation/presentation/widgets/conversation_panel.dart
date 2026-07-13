import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../language/data/language_model.dart';

class ConversationPanel extends StatelessWidget {
  final LanguageModel language;
  final IconData icon;
  final String subtitle;
  final String text;
  final Color accentColor;
  final bool isDraft;
  final bool isLoading;
  final bool isPlaceholder;
  final VoidCallback? onSpeak;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  const ConversationPanel({
    super.key,
    required this.language,
    required this.icon,
    required this.subtitle,
    required this.text,
    required this.accentColor,
    this.isDraft = false,
    this.isLoading = false,
    this.isPlaceholder = false,
    this.onSpeak,
    this.onFavorite,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.notoSans(
      fontSize: 22,
      height: 1.45,
      fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w600,
      color: isPlaceholder
          ? Colors.grey.shade500
          : isDraft
              ? Colors.grey.shade800
              : Colors.grey.shade900,
      fontStyle: isDraft ? FontStyle.italic : FontStyle.normal,
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: isDraft ? 0.35 : 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(22),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${language.flag} ${language.nativeName}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onSpeak != null && !isPlaceholder && !isLoading)
                      IconButton(
                        onPressed: onSpeak,
                        icon: Icon(Icons.volume_up, color: accentColor),
                      ),
                    if (onFavorite != null && !isPlaceholder && !isLoading)
                      IconButton(
                        onPressed: onFavorite,
                        icon: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite ? Colors.amber : accentColor,
                        ),
                      ),
                    if (!isPlaceholder && !isLoading)
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard!'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.copy_rounded, color: accentColor),
                      ),
                    if (isDraft)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isLoading
                      ? Row(
                          key: const ValueKey('loading'),
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Translating...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          text,
                          key: ValueKey(text),
                          style: _applyScriptFont(textStyle, language.code),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _applyScriptFont(TextStyle base, String code) {
    switch (code) {
      case 'zh':
        return GoogleFonts.notoSansSc(textStyle: base);
      case 'ja':
        return GoogleFonts.notoSansJp(textStyle: base);
      case 'ko':
        return GoogleFonts.notoSansKr(textStyle: base);
      case 'ar':
        return GoogleFonts.notoSansArabic(textStyle: base);
      case 'ru':
        return GoogleFonts.notoSans(textStyle: base);
      default:
        return base;
    }
  }
}
