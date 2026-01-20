import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/mock_agent_service.dart';

final chatControllerProvider =
    StateNotifierProvider.family<ChatController, List<ChatMessage>, String>((
      ref,
      projectId,
    ) {
      final agent = ref.watch(mockAgentServiceProvider);
      return ChatController(agent: agent, projectId: projectId);
    });

class ChatController extends StateNotifier<List<ChatMessage>> {
  ChatController({required this.agent, required this.projectId}) : super([]) {
    _seed();
  }

  final MockAgentService agent;
  final String projectId;

  void _seed() {
    state = [
      ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.agent,
        text:
            'Describe what you want to build and I\'ll generate a plan + next steps.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> send(String text) async {
    final now = DateTime.now();
    state = [
      ...state,
      ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.user,
        text: text,
        createdAt: now,
      ),
    ];

    final reply = await agent.reply(projectId: projectId, message: text);

    state = [
      ...state,
      ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.agent,
        text: reply,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
