import 'package:flutter/material.dart';

import '../../../language/data/language_model.dart';

/// Pemilih bahasa tujuan saja — bahasa sumber dideteksi otomatis.
class TargetLanguageSelector extends StatelessWidget {
  final LanguageModel detectedSource;
  final LanguageModel targetLanguage;
  final ValueChanged<LanguageModel> onTargetChanged;
  final bool twoWayMode;
  final ValueChanged<bool>? onTwoWayChanged;

  const TargetLanguageSelector({
    super.key,
    required this.detectedSource,
    required this.targetLanguage,
    required this.onTargetChanged,
    this.twoWayMode = true,
    this.onTwoWayChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
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
                    'Pilih Bahasa Tujuan',
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
                      final isSelected = language.code == targetLanguage.code;

                      return ListTile(
                        leading: Text(
                          language.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          language.nativeName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
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
      onTargetChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _LangPill(
            label: 'Auto',
            value: detectedSource.nativeName,
            muted: true,
            colors: colors,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        Expanded(
          child: _LangPill(
            label: 'Ke',
            value: targetLanguage.nativeName,
            onTap: () => _openPicker(context),
            colors: colors,
          ),
        ),
        if (onTwoWayChanged != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: twoWayMode ? 'Mode dua arah aktif' : 'Mode satu arah',
            visualDensity: VisualDensity.compact,
            onPressed: () => onTwoWayChanged!(!twoWayMode),
            icon: Icon(
              Icons.swap_horiz_rounded,
              size: 22,
              color: twoWayMode ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _LangPill extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final ColorScheme colors;
  final VoidCallback? onTap;

  const _LangPill({
    required this.label,
    required this.value,
    required this.colors,
    this.muted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: muted
            ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
            : colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.expand_more_rounded, size: 18, color: colors.onSurfaceVariant),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class _AutoDetectChip extends StatelessWidget {
  final LanguageModel detectedSource;
  final ColorScheme colors;

  const _AutoDetectChip({
    required this.detectedSource,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 16, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detectedSource.nativeName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final LanguageModel language;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _TargetChip({
    required this.language,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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

/// Pemilih bahasa sumber + tujuan (legacy).
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
