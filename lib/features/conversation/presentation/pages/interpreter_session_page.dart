import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_colors.dart';
import '../../../language/data/language_model.dart';
import '../../domain/entities/interpreter_session_model.dart';
import '../../providers/conversation_provider.dart';

/// Layar setup sebelum sesi Auto Interpreter dimulai.
///
/// User memilih Language A (pembicara pertama) dan Language B (pembicara
/// kedua) sekali di sini. Setelah "Mulai Sesi" ditekan, pilihan dikunci
/// untuk seluruh durasi sesi.
///
/// Desain ini menggunakan [ConversationPage] yang sudah ada sebagai
/// halaman interpreter — tidak ada halaman baru yang dibuat untuk
/// conversation flow itu sendiri.
class InterpreterSessionPage extends ConsumerStatefulWidget {
  const InterpreterSessionPage({super.key});

  @override
  ConsumerState<InterpreterSessionPage> createState() =>
      _InterpreterSessionPageState();
}

class _InterpreterSessionPageState
    extends ConsumerState<InterpreterSessionPage> {
  LanguageModel _languageA = languageByCode('id');
  LanguageModel _languageB = languageByCode('zh');

  Future<void> _pickLanguage({
    required bool isLangA,
    required LanguageModel current,
  }) async {
    final other = isLangA ? _languageB : _languageA;
    final picked = await showModalBottomSheet<LanguageModel>(
      context: context,
      backgroundColor: AppColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    isLangA ? 'Pilih Bahasa Anda' : 'Pilih Bahasa Lawan Bicara',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: languages.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final lang = languages[index];
                      final isSelected = lang.code == current.code;
                      final isDisabled = lang.code == other.code;

                      return ListTile(
                        enabled: !isDisabled,
                        leading: Text(
                          lang.flag,
                          style: TextStyle(
                            fontSize: 26,
                            color: isDisabled ? AppColors.textMuted : null,
                          ),
                        ),
                        title: Text(
                          lang.nativeName,
                          style: TextStyle(
                            color: isDisabled
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: isDisabled
                            ? const Text(
                                'Sudah dipilih sebagai bahasa lain',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.accentBlue,
                              )
                            : null,
                        onTap: isDisabled
                            ? null
                            : () => Navigator.pop(context, lang),
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

    if (picked == null || !mounted) return;
    setState(() {
      if (isLangA) {
        _languageA = picked;
      } else {
        _languageB = picked;
      }
    });
  }

  void _startSession() {
    final session = InterpreterSessionModel.create(
      languageA: _languageA,
      languageB: _languageB,
    );

    // Inisialisasi state sesi sebelum navigasi.
    ref.read(conversationProvider.notifier).startInterpreterSession(session);

    // Navigasi ke ConversationPage dengan session model sebagai extra.
    context.push('/translate', extra: session);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.translateBg,
      ),
      child: Scaffold(
        backgroundColor: AppColors.translateBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto Interpreter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Pilih pasangan bahasa untuk sesi ini',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Info card ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accentBlue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.accentBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Bahasa dipilih sekali dan dikunci selama sesi. '
                                'Mic akan mendeteksi siapa yang berbicara secara otomatis.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Language A ─────────────────────────────────────
                      const _SectionLabel(label: 'BAHASA ANDA'),
                      const SizedBox(height: 10),
                      _LanguagePickerCard(
                        language: _languageA,
                        role: 'Pembicara A',
                        onTap: () => _pickLanguage(
                          isLangA: true,
                          current: _languageA,
                        ),
                      ),

                      // ── Divider dengan panah ───────────────────────────
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(color: AppColors.divider),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Icon(
                                Icons.swap_vert_rounded,
                                color: AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                            Expanded(
                              child: Divider(color: AppColors.divider),
                            ),
                          ],
                        ),
                      ),

                      // ── Language B ─────────────────────────────────────
                      const _SectionLabel(label: 'BAHASA LAWAN BICARA'),
                      const SizedBox(height: 10),
                      _LanguagePickerCard(
                        language: _languageB,
                        role: 'Pembicara B',
                        onTap: () => _pickLanguage(
                          isLangA: false,
                          current: _languageB,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ── Tombol Mulai ────────────────────────────────────
                      _StartSessionButton(
                        languageA: _languageA,
                        languageB: _languageB,
                        onPressed: _startSession,
                      ),

                      const SizedBox(height: 16),

                      // ── Catatan stabilitas ──────────────────────────────
                      const Center(
                        child: Text(
                          'Sesi dapat berlangsung 2–4 jam tanpa interupsi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _LanguagePickerCard extends StatelessWidget {
  final LanguageModel language;
  final String role;
  final VoidCallback onTap;

  const _LanguagePickerCard({
    required this.language,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              Text(
                language.flag,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      language.nativeName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      language.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartSessionButton extends StatelessWidget {
  final LanguageModel languageA;
  final LanguageModel languageB;
  final VoidCallback onPressed;

  const _StartSessionButton({
    required this.languageA,
    required this.languageB,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          child: Column(
            children: [
              const Text(
                'Mulai Sesi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${languageA.flag} ${languageA.nativeName} ↔ '
                '${languageB.flag} ${languageB.nativeName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
