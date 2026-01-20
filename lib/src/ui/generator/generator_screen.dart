import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/groq_lua_service.dart';
import '../../services/lua_generator.dart';
import '../../utils/file_download.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _promptController = TextEditingController(
    text: 'create me a coin game where the player collects coins',
  );

  final _luaGenerator = LuaGenerator();
  final _groq = GroqLuaService();

  String _generatedLua = '';
  bool _isGenerating = false;
  String _status = 'Ready';
  String? _lastGroqError;

  @override
  void initState() {
    super.initState();
    _generatedLua = '';
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a game description.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _status = 'Generating…';
      _lastGroqError = null;
    });

    try {
      String lua;
      if (_groq.isConfigured) {
        lua = await _groq.generateRobloxLua(prompt: prompt);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        lua = _luaGenerator.generateFromPrompt(prompt);
      }

      setState(() {
        _generatedLua = lua;
        _isGenerating = false;
        _status = _groq.isConfigured ? 'Done (Groq)' : 'Done (offline)';
      });
    } catch (e) {
      final err = e.toString();
      final lua = _luaGenerator.generateFromPrompt(prompt);
      setState(() {
        _generatedLua = lua;
        _isGenerating = false;
        _lastGroqError = err;
        _status = 'Done (fallback)';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Groq failed, used offline fallback. Error: ${err.length > 160 ? err.substring(0, 160) : err}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _copyLua() async {
    if (_generatedLua.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generatedLua));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  void _downloadLua() {
    if (_generatedLua.trim().isEmpty) return;
    downloadTextFile(filename: 'game.lua', contents: _generatedLua);
  }

  @override
  Widget build(BuildContext context) {
    final background = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071827), Color(0xFF050B14)],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          background,
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VibeCoder',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Describe → Roblox Lua (MVP)',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _groq.isConfigured
                                      ? const Color(
                                          0xFF1F6FEB,
                                        ).withValues(alpha: 0.25)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  _groq.isConfigured ? 'Groq: ON' : 'Groq: OFF',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _generatedLua.trim().isEmpty
                            ? null
                            : _downloadLua,
                        child: const Text('Download .lua'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _generatedLua.trim().isEmpty
                            ? null
                            : _copyLua,
                        child: const Text('Copy Code'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;

                      final leftTop = _PromptPanel(
                        promptController: _promptController,
                        isGenerating: _isGenerating,
                        status: _status,
                        lastError: _lastGroqError,
                        onGenerate: _generate,
                        onExample: () {
                          _promptController.text =
                              'create me a coin game where the player collects coins';
                          _generate();
                        },
                      );

                      final leftBottom = _TipsPanel(
                        tips: const [
                          'Be specific: “create door that opens on touch”',
                          'Mention events: touch, click, proximity',
                          'Ask for UI: “create simple leaderboard”',
                        ],
                      );

                      final rightTop = _CodePanel(
                        title: 'Generated Lua',
                        code: _generatedLua,
                        onCopy: _copyLua,
                        onDownload: _downloadLua,
                      );

                      if (isWide) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          leftTop,
                                          const SizedBox(height: 16),
                                          leftBottom,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        children: [Expanded(child: rightTop)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Built for the Vibe Coding challenge — demo-ready MVP',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: Colors.white54),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          leftTop,
                          const SizedBox(height: 16),
                          rightTop,
                          const SizedBox(height: 16),
                          leftBottom,
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Built for the Vibe Coding challenge — demo-ready MVP',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({
    required this.promptController,
    required this.isGenerating,
    required this.status,
    required this.lastError,
    required this.onGenerate,
    required this.onExample,
  });

  final TextEditingController promptController;
  final bool isGenerating;
  final String status;
  final String? lastError;
  final VoidCallback onGenerate;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: const Color(0xFF0B1220).withValues(alpha: 0.78),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Describe what you want',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              minLines: 5,
              maxLines: 10,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Describe what you want (e.g. “make a red block that spins when touched”)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0F1A2D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: isGenerating ? null : onGenerate,
                  child: isGenerating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate Code'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: isGenerating ? null : onExample,
                  child: const Text('Try Example'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary.withValues(alpha: 0.9),
              ),
            ),
            if (lastError != null && lastError!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                lastError!.length > 220
                    ? '${lastError!.substring(0, 220)}…'
                    : lastError!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0B1220).withValues(alpha: 0.78),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tips',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '- $t',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.title,
    required this.code,
    required this.onCopy,
    required this.onDownload,
  });

  final String title;
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0B1220).withValues(alpha: 0.78),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: code.trim().isEmpty ? null : onCopy,
                  child: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: code.trim().isEmpty ? null : onDownload,
                  child: const Text('Download .lua'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    code.trim().isEmpty
                        ? '-- Generated code will appear here'
                        : code,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.35,
                      color: Colors.white70,
                    ),
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
