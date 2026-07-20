import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../../history/providers/history_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lang = settings.appLanguage;

    String t(String en, String id, String zh) {
      if (lang == 'Indonesia') return id;
      if (lang == '中文') return zh;
      return en;
    }

    Future<void> showPickerDialog(
      String title,
      List<String> options,
      String current,
      Function(String) onSelect,
    ) async {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: options
              .map((option) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, option),
                    child: Text(option,
                        style: TextStyle(
                            fontWeight: option == current
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ))
              .toList(),
        ),
      );
      if (selected != null) {
        onSelect(selected);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(t('Settings', 'Pengaturan', '设置'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  settings.userName.isNotEmpty ? settings.userName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(settings.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(settings.userEmail),
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: () async {
                final nameController = TextEditingController(text: settings.userName);
                final emailController = TextEditingController(text: settings.userEmail);
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t('Edit Profile', 'Edit Profil', '编辑个人资料')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: t('Name', 'Nama', '姓名'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: t('Email', 'Email', '电子邮件'),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('Cancel', 'Batal', '取消')),
                      ),
                      TextButton(
                        onPressed: () {
                          notifier.updateProfile(nameController.text.trim(), emailController.text.trim());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('Profile updated', 'Profil diperbarui', '个人资料已更新'))),
                          );
                        },
                        child: Text(t('Save', 'Simpan', '保存')),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Text(t('General', 'Umum', '常规'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          SwitchListTile(
            title: Text(t('Dark Mode', 'Mode Gelap', '深色模式')),
            secondary: const Icon(Icons.dark_mode),
            value: settings.darkMode,
            onChanged: (val) => notifier.updateDarkMode(val),
          ),
          ListTile(
            title: Text(t('Language', 'Bahasa', '语言')),
            subtitle: Text(settings.appLanguage),
            leading: const Icon(Icons.language),
            onTap: () => showPickerDialog(t('Select Language', 'Pilih Bahasa', '选择语言'), ['English', 'Indonesia', '中文'], settings.appLanguage, (val) => notifier.updateAppLanguage(val)),
          ),
          ListTile(
            title: Text(t('Default Translation Language', 'Bahasa Terjemahan Default', '默认翻译语言')),
            subtitle: Text('${settings.defaultSourceLang} -> ${settings.defaultTargetLang}'),
            leading: const Icon(Icons.translate),
            onTap: () async {
              await showPickerDialog(t('Select Source Language', 'Pilih Bahasa Sumber', '选择源语言'), ['English', 'Indonesia', '中文'], settings.defaultSourceLang, (src) async {
                await showPickerDialog(t('Select Target Language', 'Pilih Bahasa Tujuan', '选择目标语言'), ['English', 'Indonesia', '中文'], settings.defaultTargetLang, (tgt) {
                  notifier.updateDefaultTranslationLanguage(src, tgt);
                });
              });
            },
          ),
          const Divider(),

          Text(t('Speech', 'Suara', '语音'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ListTile(
            title: Text(t('Speech Speed', 'Kecepatan Bicara', '语速')),
            subtitle: Text(settings.speechSpeed),
            leading: const Icon(Icons.speed),
            onTap: () => showPickerDialog(t('Speech Speed', 'Kecepatan Bicara', '语速'), ['Slow', 'Normal', 'Fast'], settings.speechSpeed, (val) => notifier.updateSpeechSpeed(val)),
          ),
          ListTile(
            title: Text(t('Voice Gender', 'Gender Suara', '语音性别')),
            subtitle: Text(settings.voiceGender),
            leading: const Icon(Icons.person_outline),
            onTap: () => showPickerDialog(t('Voice Gender', 'Gender Suara', '语音性别'), ['Male', 'Female'], settings.voiceGender, (val) => notifier.updateVoiceGender(val)),
          ),
          ListTile(
            title: Text(
              t('TTS Voice Data Guide', 'Petunjuk Paket Suara (TTS)', '语音包安装指南'),
            ),
            subtitle: Text(
              t(
                'Install voice packs for translation audio',
                'Cara unduh suara Indonesia / 中文 / English',
                '安装印尼语 / 中文 / 英语语音包',
              ),
            ),
            leading: const Icon(Icons.record_voice_over_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TtsGuidePage(appLanguage: lang),
              ),
            ),
          ),
          const Divider(),

          Text(t('Preferences', 'Preferensi', '偏好设置'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          SwitchListTile(
            title: Text(t('Auto Play Translation', 'Putar Terjemahan Otomatis', '自动播放翻译')),
            secondary: const Icon(Icons.play_circle_outline),
            value: settings.autoPlayTranslation,
            onChanged: (val) => notifier.updateAutoPlayTranslation(val),
          ),
          SwitchListTile(
            title: Text(t('Auto Save History', 'Simpan Riwayat Otomatis', '自动保存历史记录')),
            secondary: const Icon(Icons.history),
            value: settings.autoSaveHistory,
            onChanged: (val) => notifier.updateAutoSaveHistory(val),
          ),
          SwitchListTile(
            title: Text(t('Notifications', 'Notifikasi', '通知')),
            secondary: const Icon(Icons.notifications_none),
            value: settings.notifications,
            onChanged: (val) => notifier.updateNotifications(val),
          ),
          const Divider(),
          
          ListTile(
            title: Text(t('Clear Cache', 'Hapus Cache', '清除缓存')),
            leading: const Icon(Icons.delete_sweep),
            onTap: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(t('Clear Cache?', 'Hapus Cache?', '清除缓存?')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: Text(t('No', 'Tidak', '否'))),
                  TextButton(
                    onPressed: () {
                      PaintingBinding.instance.imageCache.clear();
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Cache cleared', 'Cache dihapus', '缓存已清除'))));
                    },
                    child: Text(t('Yes', 'Ya', '是')),
                  )
                ],
              ),
            ),
          ),
          ListTile(
            title: Text(t('Clear History', 'Hapus Riwayat', '清除历史记录')),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(t('Clear History?', 'Hapus Riwayat?', '清除历史记录?')),
                content: Text(t('This action cannot be undone.', 'Tindakan ini tidak dapat dibatalkan.', '此操作无法撤消。')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: Text(t('No', 'Tidak', '否'))),
                  TextButton(
                    onPressed: () {
                      ref.read(historyListProvider.notifier).clearAll();
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('History cleared', 'Riwayat dihapus', '历史记录已清除'))));
                    },
                    child: Text(t('Yes', 'Ya', '是')),
                  )
                ],
              ),
            ),
          ),
          const Divider(),

          Text(t('About', 'Tentang', '关于'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ListTile(
            title: Text(t('About IWIP TalkBridge', 'Tentang IWIP TalkBridge', '关于 IWIP TalkBridge')),
            leading: const Icon(Icons.info_outline),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              return ListTile(
                title: Text(t('Version', 'Versi', '版本')),
                subtitle: Text(snapshot.hasData ? snapshot.data!.version : 'Loading...'),
                leading: const Icon(Icons.numbers),
              );
            },
          ),
          ListTile(
            title: Text(t('Privacy Policy', 'Kebijakan Privasi', '隐私政策')),
            leading: const Icon(Icons.privacy_tip_outlined),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/IWIP-Logo-150.png', height: 100),
            const Text('IWIP TalkBridge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Real-Time Conversation Translator'),
          ],
        ),
      ),
    );
  }
}

class TtsGuidePage extends StatelessWidget {
  final String appLanguage;

  const TtsGuidePage({super.key, required this.appLanguage});

  String t(String en, String id, String zh) {
    if (appLanguage == 'Indonesia') return id;
    if (appLanguage == '中文') return zh;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('TTS Voice Data Guide', 'Petunjuk Paket Suara (TTS)', '语音包安装指南')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            color: colors.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t(
                        'If translation works but you hear no audio, install Google TTS voice data on your phone.',
                        'Jika terjemahan berhasil tapi tidak ada suara, unduh paket suara Google TTS di HP.',
                        '如果翻译成功但没有声音，请在手机上下载 Google TTS 语音包。',
                      ),
                      style: TextStyle(height: 1.5, color: colors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('Samsung — easiest way', 'Samsung — cara termudah', '三星手机 — 最简单方法'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'One UI 6.1 (Android 14): Settings → General management → Text-to-speech (direct, no "Language and input").',
              'One UI 6.1 (Android 14): Pengaturan → Manajemen umum → Ubah teks menjadi suara (langsung, tanpa "Bahasa dan masukan").',
              'One UI 6.1（Android 14）：设置 → 常规管理 → 文字转语音（直接入口，无需“语言和输入”）。',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          ..._steps(
            context,
            [
              t(
                'Open Settings → Apps.',
                'Buka Pengaturan → Aplikasi.',
                '打开 设置 → 应用。',
              ),
              t(
                'Find and open Speech Services by Google.',
                'Cari dan buka Layanan Ucapan oleh Google.',
                '找到并打开 Speech Services by Google。',
              ),
              t(
                'Tap Install voice data (or Offline speech recognition).',
                'Ketuk Instal data suara (atau Pengenalan ucapan offline).',
                '点击 安装语音数据（或离线语音识别）。',
              ),
              t(
                'Download Indonesia, 中文 (Mandarin), and English.',
                'Unduh: Indonesia, 中文 (Mandarin China), dan English.',
                '下载：印尼语、中文（普通话）和英语。',
              ),
              t(
                'Return to TalkBridge and tap the speaker icon to test.',
                'Kembali ke TalkBridge → ketuk ikon speaker (🔊) untuk uji suara.',
                '返回 TalkBridge，点击扬声器图标测试。',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t('Samsung — alternative paths', 'Samsung — jalur alternatif', '三星手机 — 其他路径'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Menu names differ by One UI version. Use Settings search if needed.',
              'Nama menu beda tiap versi One UI. Gunakan pencarian di Pengaturan jika perlu.',
              '不同 One UI 版本菜单名称不同。可在设置中搜索。',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          ..._steps(
            context,
            [
              t(
                'Settings search: type "text to speech" or "teks menjadi suara".',
                'Di Pengaturan, ketik di kolom cari: "teks menjadi suara" atau "text to speech".',
                '在设置搜索框输入：“文字转语音”或“text to speech”。',
              ),
              t(
                'Path A (One UI 6.1): General management → Text-to-speech.',
                'Jalur A (One UI 6.1): Manajemen umum → Ubah teks menjadi suara.',
                '路径 A（One UI 6.1）：常规管理 → 文字转语音。',
              ),
              t(
                'Under Preferred engine, choose Speech Services by Google.',
                'Pada Mesin yang disukai, pilih Layanan Ucapan oleh Google.',
                '在首选引擎中选择 Speech Services by Google。',
              ),
              t(
                'Tap gear icon next to engine → Install voice data.',
                'Ketuk ikon roda gigi (⚙) di samping mesin → Instal data suara.',
                '点击引擎旁的齿轮图标 → 安装语音数据。',
              ),
              t(
                'Path B: Accessibility → Installed apps → Speech Services by Google.',
                'Jalur B: Aksesibilitas → Aplikasi terinstal → Layanan Ucapan oleh Google.',
                '路径 B：无障碍 → 已安装的应用 → Speech Services by Google。',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t('Other Android phones', 'HP Android lainnya', '其他安卓手机'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._steps(
            context,
            [
              t(
                'Open Settings → Apps → Speech Services by Google.',
                'Buka Settings → Apps → Speech Services by Google.',
                '打开 设置 → 应用 → Speech Services by Google。',
              ),
              t(
                'Open the app → Install voice data (or Offline speech).',
                'Buka aplikasi → Install voice data (atau Offline speech).',
                '打开应用 → 安装语音数据（或离线语音）。',
              ),
              t(
                'Download Indonesia, 中文, and English voice packs.',
                'Unduh paket suara Indonesia, 中文, dan English.',
                '下载印尼语、中文和英语语音包。',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t('Tips', 'Tips', '提示'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _tip(
            context,
            t(
              'Turn off "Auto Play Translation" in Settings if you only need text.',
              'Matikan "Putar Terjemahan Otomatis" di Pengaturan jika cukup baca teks saja.',
              '如果只需要文字，可在设置中关闭“自动播放翻译”。',
            ),
          ),
          _tip(
            context,
            t(
              'Check phone volume and silent mode before testing TTS.',
              'Cek volume HP dan mode senyap sebelum uji suara.',
              '测试前请检查手机音量和静音模式。',
            ),
          ),
          _tip(
            context,
            t(
              'Chinese voice pack is required for 中文 translation audio.',
              'Paket suara 中文 wajib untuk audio terjemahan ke Mandarin.',
              '中文语音包是播放中文翻译所必需的。',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _steps(BuildContext context, List<String> items) {
    final colors = Theme.of(context).colorScheme;
    return List.generate(items.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primary,
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                items[i],
                style: const TextStyle(height: 1.45, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _tip(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('IWIP TalkBridge Privacy Policy',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Last updated: July 2026',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 20),
          _PolicySection(
            title: '1. Data yang Kami Kumpulkan',
            content:
                'IWIP TalkBridge berjalan sepenuhnya di perangkat Anda. Kami tidak mengumpulkan, menyimpan, atau mengirim data pribadi ke server kami.\n\n'
                '• Riwayat terjemahan disimpan secara lokal di perangkat Anda\n'
                '• Favorit disimpan secara lokal di perangkat Anda\n'
                '• Pengaturan profil (nama, email) disimpan secara lokal\n'
                '• Tidak ada data yang dikirim ke server IWIP',
          ),
          _PolicySection(
            title: '2. Layanan Terjemahan',
            content:
                'Untuk terjemahan online, teks yang Anda masukkan dikirim ke layanan pihak ketiga:\n\n'
                '• Google Translate API (translate.googleapis.com) — untuk terjemahan utama\n'
                '• MyMemory API (mymemory.translated.net) — sebagai fallback\n\n'
                'Untuk terjemahan offline, semua proses dilakukan sepenuhnya di perangkat Anda menggunakan Google ML Kit tanpa koneksi internet.',
          ),
          _PolicySection(
            title: '3. Izin Aplikasi',
            content:
                '• Mikrofon: Untuk fitur Speech-to-Text\n'
                '• Kamera & Galeri: Untuk fitur Camera Translate (OCR)\n'
                '• Internet: Untuk terjemahan online dan download model offline\n'
                '• Storage: Untuk menyimpan data lokal (riwayat, favorit, pengaturan)',
          ),
          _PolicySection(
            title: '4. Layanan Pihak Ketiga',
            content:
                'Aplikasi ini menggunakan layanan Google ML Kit untuk:\n'
                '• Pengenalan teks (OCR) dari gambar\n'
                '• Terjemahan offline\n\n'
                'Data gambar yang diproses untuk OCR tidak meninggalkan perangkat Anda.',
          ),
          _PolicySection(
            title: '5. Keamanan Data',
            content:
                'Semua data disimpan secara lokal menggunakan SharedPreferences Android yang aman. '
                'Kami tidak memiliki akses ke data Anda.',
          ),
          _PolicySection(
            title: '6. Hubungi Kami',
            content:
                'Jika Anda memiliki pertanyaan tentang kebijakan privasi ini, hubungi:\n\n'
                'Email: privacy@iwip.com\n'
                'Website: https://iwip.com',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content,
              style: TextStyle(
                  height: 1.6,
                  color: theme.textTheme.bodyMedium?.color)),
          const Divider(height: 32),
        ],
      ),
    );
  }
}

