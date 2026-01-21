import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

import '../../services/groq_lua_service.dart';
import '../../services/lua_generator.dart';
import '../../utils/file_download.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _StepsPanel extends StatelessWidget {
  const _StepsPanel({required this.steps, required this.accent});

  final List<String> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _CyberCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Build Steps',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          if (steps.isEmpty)
            Text(
              'Generate a game to see step-by-step build instructions.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            )
          else
            ...List<Widget>.generate(steps.length, (i) {
              final s = steps[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.45),
                        ),
                        color: const Color(0xFF0F1A2D),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.error,
    required this.accent,
    required this.status,
    required this.onRetry,
    required this.onDismiss,
  });

  final String error;
  final Color accent;
  final String status;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final short = error.length > 900 ? '${error.substring(0, 900)}…' : error;
    return _CyberCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Error',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SelectableText(
            short,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: Colors.white70,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _promptController = TextEditingController(
    text: 'create me a coin game where the player collects coins',
  );
  final _codeController = TextEditingController();

  final _luaGenerator = LuaGenerator();
  final _groq = GroqLuaService();

  final List<String> _recentPrompts = <String>[];
  bool _showLineNumbers = true;
  bool _syntaxHighlight = true;

  static const List<String> _presets = <String>[
    'Create a coin collector game with score + win when you collect 25 coins',
    'Create a door that opens when the player touches it',
    'Create a spinning hazard that kills player on touch',
    'Create a zombie that chases the nearest player',
    'Create a simple leaderboard with Coins + Kills',
  ];

  String _generatedLua = '';
  List<String> _buildSteps = const <String>[];
  bool _isGenerating = false;
  String _status = 'Ready';
  String? _lastGroqError;
  String? _lastAction;
  String? _lastPrompt;
  String? _lastIssue;
  String? _lastInstruction;

  @override
  void initState() {
    super.initState();
    _generatedLua = '';
  }

  @override
  void dispose() {
    _promptController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _retryLast() async {
    final action = _lastAction;
    if (action == 'generate' && _lastPrompt != null) {
      _promptController.text = _lastPrompt!;
      await _generate();
      return;
    }
    if (action == 'fix' && _lastIssue != null) {
      _promptController.text = _lastIssue!;
      await _fixAndRegenerate();
      return;
    }
    if (action == 'update' && _lastInstruction != null) {
      _promptController.text = _lastInstruction!;
      await _applyUpdate();
      return;
    }
  }

  List<String> _offlineSteps(String prompt) {
    final p = prompt.trim();
    return <String>[
      'Create a new Baseplate experience and save it. ($p)',
      'Create the required Workspace objects mentioned in the script header (if any).',
      'Insert a Script into ServerScriptService and paste the generated Lua.',
      'Press Play and verify the core loop works (win/lose/score).',
      'Adjust values (speed, coin amount, damage) and test again.',
      'Publish the experience and test with another player if needed.',
    ];
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a game description.')),
      );
      return;
    }

    _lastAction = 'generate';
    _lastPrompt = prompt;

    _rememberPrompt(prompt);

    setState(() {
      _isGenerating = true;
      _status = 'Generating…';
      _lastGroqError = null;
      _buildSteps = const <String>[];
    });

    try {
      String lua;
      if (_groq.isConfigured) {
        final res = await _groq.generateRobloxLuaWithSteps(prompt: prompt);
        lua = res.lua;
        final steps = res.steps;
        setState(() {
          _buildSteps = steps.isNotEmpty ? steps : _offlineSteps(prompt);
        });
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        lua = _luaGenerator.generateFromPrompt(prompt);
        setState(() {
          _buildSteps = _offlineSteps(prompt);
        });
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
        _buildSteps = _offlineSteps(prompt);
        _isGenerating = false;
        _lastGroqError = err;
        _status = 'Done (fallback)';
      });
    }
  }

  Future<void> _fixAndRegenerate() async {
    final issue = _promptController.text.trim();
    final lua = _codeController.text.trim();
    if (issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe the error/issue to fix in Description.'),
        ),
      );
      return;
    }
    if (lua.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the existing Lua code to fix.')),
      );
      return;
    }

    _lastAction = 'fix';
    _lastIssue = issue;

    setState(() {
      _isGenerating = true;
      _status = 'Fixing…';
      _lastGroqError = null;
    });

    try {
      if (!_groq.isConfigured) {
        throw StateError('Groq is not configured');
      }
      final fixed = await _groq.fixLua(existingLua: lua, issue: issue);
      setState(() {
        _generatedLua = fixed;
        _codeController.text = fixed;
        _isGenerating = false;
        _status = 'Fixed';
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _lastGroqError = e.toString();
        _status = 'Fix failed';
      });
    }
  }

  Future<void> _applyUpdate() async {
    final instruction = _promptController.text.trim();
    final lua = _codeController.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Describe what you want to change/update in Description.',
          ),
        ),
      );
      return;
    }
    if (lua.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the existing Lua code to update.')),
      );
      return;
    }

    _lastAction = 'update';
    _lastInstruction = instruction;

    setState(() {
      _isGenerating = true;
      _status = 'Updating…';
      _lastGroqError = null;
    });

    try {
      if (!_groq.isConfigured) {
        throw StateError('Groq is not configured');
      }
      final updated = await _groq.updateLua(
        existingLua: lua,
        instruction: instruction,
      );
      setState(() {
        _generatedLua = updated;
        _codeController.text = updated;
        _isGenerating = false;
        _status = 'Updated';
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _lastGroqError = e.toString();
        _status = 'Update failed';
      });
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

  void _rememberPrompt(String prompt) {
    final p = prompt.trim();
    if (p.isEmpty) return;
    setState(() {
      _recentPrompts.removeWhere((x) => x == p);
      _recentPrompts.insert(0, p);
      if (_recentPrompts.length > 8) {
        _recentPrompts.removeRange(8, _recentPrompts.length);
      }
    });
  }

  String _formatWithLineNumbers(String code) {
    final trimmed = code.trimRight();
    if (trimmed.isEmpty) return trimmed;
    final lines = trimmed.split('\n');
    final width = lines.length.toString().length;
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final n = (i + 1).toString().padLeft(width, ' ');
      out.add('$n | ${lines[i]}');
    }
    return out.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    const cyberCyan = Color(0xFF22D3EE);
    const cyberGreen = Color(0xFF34D399);
    const cardFill = Color(0xFF0A1024);

    final background = Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.9),
          radius: 1.2,
          colors: [Color(0xFF1B0B3A), Color(0xFF050814)],
        ),
      ),
      child: Opacity(
        opacity: 0.35,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2A2F), Color(0xFF120A2A)],
            ),
          ),
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
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: cardFill.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cyberCyan.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cyberCyan.withValues(alpha: 0.22),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                      ? cyberCyan.withValues(alpha: 0.16)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _groq.isConfigured
                                        ? cyberCyan.withValues(alpha: 0.45)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  _groq.isConfigured ? 'Groq: ON' : 'Groq: OFF',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _isGenerating
                                      ? cyberGreen.withValues(alpha: 0.16)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _isGenerating
                                        ? cyberGreen.withValues(alpha: 0.45)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  _isGenerating ? 'Running' : 'Idle',
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
                        codeController: _codeController,
                        isGenerating: _isGenerating,
                        status: _status,
                        lastError: _lastGroqError,
                        presets: _presets,
                        accent: cyberCyan,
                        onGenerate: _generate,
                        onFix: _fixAndRegenerate,
                        onUpdate: _applyUpdate,
                        onPreset: (p) {
                          _promptController.text = p;
                        },
                        onClear: () {
                          _promptController.clear();
                        },
                        onExample: () {
                          _promptController.text =
                              'create me a coin game where the player collects coins';
                          _generate();
                        },
                        groqConfigured: _groq.isConfigured,
                      );

                      final history = _HistoryPanel(
                        prompts: _recentPrompts,
                        accent: cyberCyan,
                        onUse: (p) {
                          _promptController.text = p;
                          _generate();
                        },
                        onRemove: (p) {
                          setState(() => _recentPrompts.remove(p));
                        },
                        onClearAll: () {
                          setState(_recentPrompts.clear);
                        },
                      );

                      final stepsPanel = _StepsPanel(
                        steps: _buildSteps,
                        accent: cyberGreen,
                      );

                      final leftBottom = _TipsPanel(
                        tips: const [
                          'Be specific: “create door that opens on touch”',
                          'Mention events: touch, click, proximity',
                          'Ask for UI: “create simple leaderboard”',
                        ],
                        accent: cyberGreen,
                      );

                      final rightTop = _CodePanel(
                        title: 'Generated Lua',
                        code: _showLineNumbers
                            ? _formatWithLineNumbers(_generatedLua)
                            : _generatedLua,
                        onCopy: _copyLua,
                        onDownload: _downloadLua,
                        showLineNumbers: _showLineNumbers,
                        syntaxHighlight: _syntaxHighlight,
                        rawCode: _generatedLua,
                        accent: cyberCyan,
                        filename: 'game.lua',
                        onToggleLineNumbers: (v) {
                          setState(() => _showLineNumbers = v);
                        },
                        onToggleHighlight: (v) {
                          setState(() => _syntaxHighlight = v);
                        },
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
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            leftTop,
                                            const SizedBox(height: 16),
                                            stepsPanel,
                                            const SizedBox(height: 16),
                                            history,
                                            const SizedBox(height: 16),
                                            leftBottom,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          if (_lastGroqError != null &&
                                              _lastGroqError!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            _ErrorPanel(
                                              error: _lastGroqError!,
                                              accent: cyberCyan,
                                              status: _status,
                                              onRetry: _retryLast,
                                              onDismiss: () => setState(
                                                () => _lastGroqError = null,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          Expanded(child: rightTop),
                                        ],
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
                          stepsPanel,
                          const SizedBox(height: 16),
                          history,
                          const SizedBox(height: 16),
                          if (_lastGroqError != null &&
                              _lastGroqError!.trim().isNotEmpty) ...[
                            _ErrorPanel(
                              error: _lastGroqError!,
                              accent: cyberCyan,
                              status: _status,
                              onRetry: _retryLast,
                              onDismiss: () =>
                                  setState(() => _lastGroqError = null),
                            ),
                            const SizedBox(height: 16),
                          ],
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
    required this.codeController,
    required this.isGenerating,
    required this.status,
    required this.lastError,
    required this.presets,
    required this.accent,
    required this.onGenerate,
    required this.onFix,
    required this.onUpdate,
    required this.onPreset,
    required this.onClear,
    required this.onExample,
    required this.groqConfigured,
  });

  final TextEditingController promptController;
  final TextEditingController codeController;
  final bool isGenerating;
  final String status;
  final String? lastError;
  final List<String> presets;
  final Color accent;
  final VoidCallback onGenerate;
  final VoidCallback onFix;
  final VoidCallback onUpdate;
  final ValueChanged<String> onPreset;
  final VoidCallback onClear;
  final VoidCallback onExample;
  final bool groqConfigured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CyberCard(
      accent: accent,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets.take(5))
                ActionChip(
                  onPressed: isGenerating ? null : () => onPreset(p),
                  label: Text(
                    p.length > 34 ? '${p.substring(0, 34)}…' : p,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  backgroundColor: Colors.white10,
                  shape: StadiumBorder(
                    side: BorderSide(color: accent.withValues(alpha: 0.30)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: promptController,
            minLines: 5,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Describe the game OR paste an error/change request (for Fix/Update)\nExample: “Coins not increasing when touched. Fix it.”',
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
          TextField(
            controller: codeController,
            minLines: 3,
            maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Optional: paste existing Lua here (required for Fix/Update). If empty, only Generate is available.',
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
              _GenerateButton(
                isGenerating: isGenerating,
                accent: accent,
                onPressed: onGenerate,
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: (!groqConfigured || isGenerating)
                    ? null
                    : (codeController.text.trim().isEmpty ? null : onFix),
                child: const Text('Fix & Regenerate'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: (!groqConfigured || isGenerating)
                    ? null
                    : (codeController.text.trim().isEmpty ? null : onUpdate),
                child: const Text('Apply Update'),
              ),
              TextButton(
                onPressed: isGenerating ? null : onExample,
                child: const Text('Try Example'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Clear',
                onPressed: isGenerating ? null : onClear,
                icon: const Icon(Icons.clear, color: Colors.white70),
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
    );
  }
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({required this.tips, required this.accent});

  final List<String> tips;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _CyberCard(
      accent: accent,
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
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.prompts,
    required this.accent,
    required this.onUse,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> prompts;
  final Color accent;
  final ValueChanged<String> onUse;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return _CyberCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent prompts',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: prompts.isEmpty ? null : onClearAll,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (prompts.isEmpty)
            Text(
              'Your recent prompts will appear here.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in prompts)
                  InputChip(
                    label: Text(
                      p.length > 44 ? '${p.substring(0, 44)}…' : p,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onPressed: () => onUse(p),
                    onDeleted: () => onRemove(p),
                    deleteIconColor: Colors.white54,
                    backgroundColor: Colors.white10,
                    shape: StadiumBorder(
                      side: BorderSide(color: accent.withValues(alpha: 0.30)),
                    ),
                  ),
              ],
            ),
        ],
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
    required this.rawCode,
    required this.filename,
    required this.accent,
    required this.showLineNumbers,
    required this.onToggleLineNumbers,
    required this.syntaxHighlight,
    required this.onToggleHighlight,
  });

  final String title;
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onDownload;
  final String rawCode;
  final String filename;
  final Color accent;
  final bool showLineNumbers;
  final ValueChanged<bool> onToggleLineNumbers;
  final bool syntaxHighlight;
  final ValueChanged<bool> onToggleHighlight;

  @override
  Widget build(BuildContext context) {
    final displayText = (syntaxHighlight ? rawCode : code).trim();

    return _CyberCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TerminalHeader(
            title: title,
            filename: filename,
            accent: accent,
            showLineNumbers: showLineNumbers,
            onToggleLineNumbers: (v) {
              if (!syntaxHighlight) onToggleLineNumbers(v);
            },
            syntaxHighlight: syntaxHighlight,
            onToggleHighlight: onToggleHighlight,
            onCopy: displayText.isEmpty ? null : onCopy,
            onDownload: displayText.isEmpty ? null : onDownload,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: displayText.isEmpty
                    ? SelectableText(
                        '-- Generated code will appear here',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.35,
                          color: Colors.white54,
                        ),
                      )
                    : (syntaxHighlight
                          ? HighlightView(
                              rawCode,
                              language: 'lua',
                              padding: EdgeInsets.zero,
                              textStyle: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    height: 1.35,
                                    color: Colors.white70,
                                  ),
                              theme: const {
                                'root': TextStyle(
                                  backgroundColor: Colors.transparent,
                                  color: Color(0xFFD1D5DB),
                                ),
                                'keyword': TextStyle(color: Color(0xFF22D3EE)),
                                'built_in': TextStyle(color: Color(0xFFA78BFA)),
                                'literal': TextStyle(color: Color(0xFF34D399)),
                                'string': TextStyle(color: Color(0xFFFBBF24)),
                                'comment': TextStyle(color: Color(0xFF6B7280)),
                                'number': TextStyle(color: Color(0xFF60A5FA)),
                                'function': TextStyle(color: Color(0xFFE879F9)),
                                'title': TextStyle(color: Color(0xFFE879F9)),
                              },
                            )
                          : SelectableText(
                              code,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    height: 1.35,
                                    color: Colors.white70,
                                  ),
                            )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberCard extends StatelessWidget {
  const _CyberCard({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Card(
        color: const Color(0xFF0B1220).withValues(alpha: 0.78),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isGenerating,
    required this.accent,
    required this.onPressed,
  });

  final bool isGenerating;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isGenerating ? 1 : 0),
      duration: const Duration(milliseconds: 350),
      builder: (context, t, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (t > 0)
                BoxShadow(
                  color: accent.withValues(alpha: 0.25 * t),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: child,
        );
      },
      child: FilledButton(
        onPressed: isGenerating ? null : onPressed,
        child: isGenerating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Generate Code'),
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({
    required this.title,
    required this.filename,
    required this.accent,
    required this.showLineNumbers,
    required this.onToggleLineNumbers,
    required this.syntaxHighlight,
    required this.onToggleHighlight,
    required this.onCopy,
    required this.onDownload,
  });

  final String title;
  final String filename;
  final Color accent;
  final bool showLineNumbers;
  final ValueChanged<bool> onToggleLineNumbers;
  final bool syntaxHighlight;
  final ValueChanged<bool> onToggleHighlight;
  final VoidCallback? onCopy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                filename,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Text(
                'HL',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white70),
              ),
              Switch(value: syntaxHighlight, onChanged: onToggleHighlight),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Text(
                'Lines',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: syntaxHighlight ? Colors.white38 : Colors.white70,
                ),
              ),
              Switch(
                value: showLineNumbers,
                onChanged: syntaxHighlight ? null : onToggleLineNumbers,
              ),
            ],
          ),
        ),
        TextButton(onPressed: onCopy, child: const Text('Copy')),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onDownload,
          child: const Text('Download .lua'),
        ),
      ],
    );
  }
}
