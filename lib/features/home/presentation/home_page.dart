import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_colors.dart';
import '../../settings/providers/settings_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('--- AUDIT: HomePage build() called');
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    
    final lang = settings.appLanguage;
    final translateText = lang == 'Indonesia' ? 'Terjemahkan teks atau suara' : (lang == '中文' ? '翻译文字或语音' : 'Translate text or voice');
    final moreTools = lang == 'Indonesia' ? 'Alat lainnya' : (lang == '中文' ? '更多工具' : 'More tools');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Minimalist AppBar
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            elevation: 0,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/IWIP-Logo-150.png',
                      height: 28,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.business_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IWIP TalkBridge',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Industrial Translator',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hint Text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      translateText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ),
                  
                  // Input Translation Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => context.push('/translate'),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == 'Indonesia'
                                    ? 'Masukkan teks...'
                                    : (lang == '中文' ? '输入文字...' : 'Enter text...'),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 48),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _ActionButton(
                                        icon: Icons.content_paste_rounded,
                                        label: lang == 'Indonesia' ? 'Tempel' : 'Paste',
                                        onTap: () {},
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionButton(
                                        icon: Icons.camera_alt_rounded,
                                        label: lang == 'Indonesia' ? 'Kamera' : 'Camera',
                                        onTap: () => context.push('/camera'),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _ActionButton(
                                        icon: Icons.backspace_rounded,
                                        label: lang == 'Indonesia' ? 'Hapus' : 'Clear',
                                        onTap: () {},
                                        isSmall: true,
                                      ),
                                      const SizedBox(width: 12),
                                      _ActionButton(
                                        icon: Icons.mic_rounded,
                                        label: lang == 'Indonesia' ? 'Suara' : 'Voice',
                                        isPrimary: true,
                                        onTap: () => context.push('/translate'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  Text(
                    moreTools,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    padding: EdgeInsets.zero,
                    children: [
                      _QuickActionCard(
                        icon: Icons.history_rounded,
                        title: lang == 'Indonesia' ? 'Riwayat' : (lang == '中文' ? '历史记录' : 'History'),
                        onTap: () => context.push('/history'),
                        color: AppColors.sky,
                      ),
                      _QuickActionCard(
                        icon: Icons.star_rounded,
                        title: lang == 'Indonesia' ? 'Favorit' : (lang == '中文' ? '收藏' : 'Favorite'),
                        onTap: () => context.push('/favorite'),
                        color: AppColors.violet,
                      ),
                      _QuickActionCard(
                        icon: Icons.cloud_download_rounded,
                        title: lang == 'Indonesia' ? 'Offline' : (lang == '中文' ? '离线' : 'Offline'),
                        onTap: () => context.push('/offline'),
                        color: AppColors.mint,
                      ),
                      _QuickActionCard(
                        icon: Icons.settings_rounded,
                        title: lang == 'Indonesia' ? 'Pengaturan' : (lang == '中文' ? '设置' : 'Settings'),
                        onTap: () => context.push('/settings'),
                        color: AppColors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSmall;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final bgColor = isPrimary ? theme.colorScheme.primaryContainer : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 12,
            vertical: isSmall ? 8 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isSmall ? 20 : 24, color: color),
              if (!isSmall) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
