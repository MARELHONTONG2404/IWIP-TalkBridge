import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Edit your profile details'),
            ),
          ),
          const SizedBox(height: 16),

          // General Settings
          const Text('General', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode),
            value: false,
            onChanged: (val) {},
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: const Text('English (US)'),
            leading: const Icon(Icons.language),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Default Translation Language'),
            subtitle: const Text('Indonesian'),
            leading: const Icon(Icons.translate),
            onTap: () {},
          ),
          const Divider(),

          // Speech Settings
          const Text('Speech', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ListTile(
            title: const Text('Speech Speed'),
            subtitle: const Text('Normal'),
            leading: const Icon(Icons.speed),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Voice Gender'),
            subtitle: const Text('Female'),
            leading: const Icon(Icons.person_outline),
            onTap: () {},
          ),
          const Divider(),

          // Preferences
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          SwitchListTile(
            title: const Text('Auto Play Translation'),
            secondary: const Icon(Icons.play_circle_outline),
            value: true,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text('Auto Save History'),
            secondary: const Icon(Icons.history),
            value: true,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            secondary: const Icon(Icons.notifications_none),
            value: true,
            onChanged: (val) {},
          ),
          const Divider(),

          // About
          const Text('About', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ListTile(
            title: const Text('About IWIP TalkBridge'),
            leading: const Icon(Icons.info_outline),
            onTap: () {},
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0+1'),
            leading: Icon(Icons.numbers),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            onTap: () {},
          ),
          const Divider(),

          // Logout
          ListTile(
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
