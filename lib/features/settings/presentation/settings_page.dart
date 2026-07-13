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

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const Padding(padding: EdgeInsets.all(16), child: Text('Privacy policy content here...')),
    );
  }
}
