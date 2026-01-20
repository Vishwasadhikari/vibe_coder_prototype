import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final mockAgentServiceProvider = Provider<MockAgentService>((ref) {
  return MockAgentService();
});

class MockAgentService {
  final _rng = Random();

  Future<String> reply({
    required String projectId,
    required String message,
  }) async {
    await Future<void>.delayed(Duration(milliseconds: 450 + _rng.nextInt(450)));

    final m = message.trim().toLowerCase();

    if (m.contains('plan') || m.contains('steps') || m.contains('roadmap')) {
      return [
        'Plan for this prototype:',
        '1) Define screens + data model',
        '2) Build dashboard + workspace layout',
        '3) Connect agent chat to actions (create file, update doc, run)',
        '4) Add persistence (local DB) and real API later',
        '',
        'Tell me: what should the app generate (UI, code, content)?',
      ].join('\n');
    }

    if (m.contains('flutter')) {
      return 'Got it. I can generate: routes, Riverpod state, Material 3 UI, and a workspace layout. What feature do you want first: Dashboard or Workspace?';
    }

    return [
      'I understand you want:',
      '- $message',
      '',
      'Next question: should I generate UI components, data models, or a full feature flow?',
    ].join('\n');
  }
}
