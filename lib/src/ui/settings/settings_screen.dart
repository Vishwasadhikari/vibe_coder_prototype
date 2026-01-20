import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Signed in as: ${auth.email ?? '-'}'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => ref.read(authControllerProvider).logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Prototype toggles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: true,
                    onChanged: null,
                    title: const Text('Enable agent suggestions'),
                    subtitle: const Text('Mocked in this prototype'),
                  ),
                  SwitchListTile(
                    value: true,
                    onChanged: null,
                    title: const Text('Enable run preview'),
                    subtitle: const Text('Mocked in this prototype'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
