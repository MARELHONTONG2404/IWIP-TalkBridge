import 'package:flutter/material.dart';

import '../../../language/data/language_model.dart';

/// Auto-detect bahasa sumber (Camera Translate saja).
const _autoDetectLang = LanguageModel(
  name: 'Auto Detect',
  nativeName: 'Auto Detect',
  flag: '🌐',
  code: 'auto',
  speechCode: 'auto',
);

/// A compact language selector used in the Camera Translate page.
/// Reuses the same bottom-sheet picker pattern as LanguageSelector.
class LanguageSelectorCamera extends StatelessWidget {
  static const autoDetect = _autoDetectLang;

  final LanguageModel sourceLang;
  final LanguageModel targetLang;
  final ValueChanged<LanguageModel> onSourceChanged;
  final ValueChanged<LanguageModel> onTargetChanged;
  final VoidCallback onSwap;

  const LanguageSelectorCamera({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  Future<void> _openPicker(
    BuildContext context, {
    required LanguageModel selected,
    required ValueChanged<LanguageModel> onSelected,
    required List<LanguageModel> options,
  }) async {
    final picked = await showModalBottomSheet<LanguageModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Pilih Bahasa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final language = options[index];
                      final isSelected = language.code == selected.code;
                      return ListTile(
                        leading: Text(
                          language.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          language.nativeName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(language.name),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, language),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sourceOptions = <LanguageModel>[_autoDetectLang, ...languages];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LangChip(
              language: sourceLang,
              onTap: () => _openPicker(
                context,
                selected: sourceLang,
                onSelected: onSourceChanged,
                options: sourceOptions,
              ),
            ),
          ),
          IconButton(
            onPressed: onSwap,
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: colors.primary,
              size: 26,
            ),
            tooltip: 'Tukar bahasa',
          ),
          Expanded(
            child: _LangChip(
              language: targetLang,
              onTap: () => _openPicker(
                context,
                selected: targetLang,
                onSelected: onTargetChanged,
                options: languages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final LanguageModel language;
  final VoidCallback onTap;

  const _LangChip({required this.language, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                language.nativeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                color: colors.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }
}
