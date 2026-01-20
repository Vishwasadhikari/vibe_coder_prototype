import 'package:flutter/material.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final List<String> _logs = <String>['Ready. Select a project and click Run.'];

  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _logs.insert(0, 'Starting run…');
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    setState(() => _logs.insert(0, 'Building…'));

    await Future<void>.delayed(const Duration(milliseconds: 500));
    setState(() => _logs.insert(0, 'Launching preview…'));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    setState(() {
      _running = false;
      _logs.insert(0, 'Done. (Prototype run output)');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run & Preview'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running…' : 'Run'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a mock runner for the prototype. Later you can connect it to a backend build service or device preview.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.separated(
                    reverse: true,
                    itemCount: _logs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final line = _logs[index];
                      return Text(
                        line,
                        style: const TextStyle(fontFamily: 'monospace'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
