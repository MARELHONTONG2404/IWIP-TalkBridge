import 'package:flutter/material.dart';

import '../../../language/data/language_model.dart';

class LanguageSelector extends StatelessWidget {
  final LanguageModel sourceLanguage;
  final LanguageModel targetLanguage;
  final ValueChanged<LanguageModel> onSourceChanged;
  final ValueChanged<LanguageModel> onTargetChanged;
  final VoidCallback onSwap;

  const LanguageSelector({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  Future<void> _openPicker(
    BuildContext context, {
    required LanguageModel selected,
    required ValueChanged<LanguageModel> onSelected,
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
                    itemCount: languages.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final language = languages[index];
                      final isSelected = language.code == selected.code;

                      return ListTile(
                        leading: Text(
                          language.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          language.nativeName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 17,
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
    return Row(
      children: [
        Expanded(
          child: _LanguageChip(
            language: sourceLanguage,
            onTap: () => _openPicker(
              context,
              selected: sourceLanguage,
              onSelected: onSourceChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: IconButton(
            onPressed: onSwap,
            icon: Icon(
              Icons.arrow_forward_rounded,
              color: colors.onSurfaceVariant,
              size: 34,
            ),
          ),
        ),
        Expanded(
          child: _LanguageChip(
            language: targetLanguage,
            onTap: () => _openPicker(
              context,
              selected: targetLanguage,
              onSelected: onTargetChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final LanguageModel language;
  final VoidCallback onTap;

  const _LanguageChip({required this.language, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  language.nativeName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
