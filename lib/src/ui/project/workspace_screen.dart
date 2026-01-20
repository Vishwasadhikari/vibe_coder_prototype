import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message.dart';
import '../../models/project.dart';
import '../../state/chat_controller.dart';
import '../../state/projects_controller.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final _promptController = TextEditingController();
  final _editorController = TextEditingController(
    text:
        '// Prototype editor\n\n// Describe your feature in chat, then implement here.\n',
  );

  @override
  void dispose() {
    _promptController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    _promptController.clear();

    await ref
        .read(chatControllerProvider(widget.projectId).notifier)
        .send(text);
    ref.read(projectsControllerProvider.notifier).touch(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Project? project = ref
        .read(projectsControllerProvider.notifier)
        .byId(widget.projectId);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workspace')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final messages = ref.watch(chatControllerProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                project.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = constraints.maxWidth >= 980;
          if (!wide) {
            return _NarrowWorkspace(
              editorController: _editorController,
              promptController: _promptController,
              messages: messages,
              onSend: _send,
            );
          }

          return Row(
            children: [
              SizedBox(width: 260, child: _FilesPanel()),
              const VerticalDivider(width: 1),
              Expanded(child: _EditorPanel(controller: _editorController)),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 360,
                child: _ChatPanel(
                  messages: messages,
                  promptController: _promptController,
                  onSend: _send,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilesPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Files', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _FileTile(icon: Icons.description_outlined, name: 'README.md'),
          const _FileTile(icon: Icons.code_outlined, name: 'lib/main.dart'),
          const _FileTile(icon: Icons.code_outlined, name: 'lib/app.dart'),
          const _FileTile(
            icon: Icons.data_object_outlined,
            name: 'api/schema.json',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: const Text('New file (prototype)'),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name),
      onTap: () {},
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Editor', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Apply agent patch'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Start coding…',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.promptController,
    required this.onSend,
  });

  final List<ChatMessage> messages;
  final TextEditingController promptController;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agent Chat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final bool user = m.role == ChatRole.user;
                  return Align(
                    alignment: user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: user
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    hintText: 'Ask the agent…',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSend, child: const Icon(Icons.send)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NarrowWorkspace extends StatelessWidget {
  const _NarrowWorkspace({
    required this.editorController,
    required this.promptController,
    required this.messages,
    required this.onSend,
  });

  final TextEditingController editorController;
  final TextEditingController promptController;
  final List<ChatMessage> messages;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Files'),
              Tab(text: 'Editor'),
              Tab(text: 'Chat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FilesPanel(),
                _EditorPanel(controller: editorController),
                _ChatPanel(
                  messages: messages,
                  promptController: promptController,
                  onSend: onSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
