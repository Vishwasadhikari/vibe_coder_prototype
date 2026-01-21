import 'dart:convert';

import 'package:http/http.dart' as http;

class GroqLuaService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _modelOverride = String.fromEnvironment('GROQ_MODEL');

  static List<String>? _cachedModels;
  static DateTime? _cachedAt;

  bool get usesDirect => _apiKey.trim().isNotEmpty;
  bool get usesProxy => !usesDirect;

  bool get isConfigured => usesDirect || usesProxy;

  Uri _proxyUri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    final base = Uri.base;
    if (base.hasScheme && base.host.isNotEmpty) {
      return Uri.parse('${base.origin}$p');
    }
    return Uri.parse(p);
  }

  Never _proxyNotFoundError(String endpoint) {
    throw StateError(
      'Proxy endpoint not found (HTTP 404): $endpoint. '
      'If you are running locally, Flutter dev server does not serve /api/*; use your deployed Vercel URL or run `vercel dev` from the project root.',
    );
  }

  List<String> _parseSteps(dynamic steps) {
    if (steps is! List) return const <String>[];
    final out = <String>[];
    for (final s in steps) {
      if (s is String) {
        final t = s.trim();
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  Future<void> checkProxyHealth() async {
    final uri = _proxyUri('/api/health');
    final resp = await http.get(uri);
    if (resp.statusCode == 404) {
      _proxyNotFoundError('/api/health');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Proxy health failed HTTP ${resp.statusCode}: ${resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body}',
      );
    }
  }

  Future<List<String>> _fetchAvailableModels({required String apiKey}) async {
    final now = DateTime.now();
    final cached = _cachedModels;
    final cachedAt = _cachedAt;
    if (cached != null && cachedAt != null) {
      if (now.difference(cachedAt) < const Duration(minutes: 10)) {
        return cached;
      }
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/models');
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Groq models HTTP ${resp.statusCode}: ${resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    final data = decoded['data'];
    if (data is! List) {
      throw StateError('Groq models response missing data');
    }

    final ids = <String>[];
    for (final item in data) {
      if (item is Map && item['id'] is String) {
        ids.add((item['id'] as String).trim());
      }
    }

    if (ids.isEmpty) {
      throw StateError('No models returned by Groq');
    }

    _cachedModels = ids;
    _cachedAt = now;
    return ids;
  }

  String _pickBestModel(List<String> models) {
    final override = _modelOverride.trim();
    if (override.isNotEmpty && models.contains(override)) {
      return override;
    }

    int score(String m) {
      final s = m.toLowerCase();
      var sc = 0;
      if (s.contains('llama')) sc += 50;
      if (s.contains('3.3') || s.contains('3.2') || s.contains('3.1')) sc += 25;
      if (s.contains('70b')) sc += 20;
      if (s.contains('versatile') ||
          s.contains('instruct') ||
          s.contains('it')) {
        sc += 10;
      }
      if (s.contains('8b')) sc += 5;
      if (s.contains('vision')) sc -= 5;
      if (s.contains('whisper') ||
          s.contains('tts') ||
          s.contains('embedding')) {
        sc -= 100;
      }
      return sc;
    }

    var bestIdx = 0;
    var bestScore = -999999;
    for (var i = 0; i < models.length; i++) {
      final sc = score(models[i]);
      if (sc > bestScore) {
        bestScore = sc;
        bestIdx = i;
      }
    }

    return models[bestIdx];
  }

  Future<({String lua, List<String> steps})> _generateViaProxyWithSteps({
    required String prompt,
  }) async {
    final uri = _proxyUri('/api/generate');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    if (resp.statusCode == 404) {
      _proxyNotFoundError('/api/generate');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Proxy HTTP ${resp.statusCode}: ${resp.body.length > 600 ? resp.body.substring(0, 600) : resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    final lua = decoded is Map ? decoded['lua'] : null;
    final text = (lua is String) ? lua.trim() : '';
    if (text.isEmpty) {
      throw StateError('Empty response from proxy');
    }

    final steps = decoded is Map
        ? _parseSteps(decoded['steps'])
        : const <String>[];
    return (lua: text, steps: steps);
  }

  Future<String> _fixViaProxy({
    required String existingLua,
    required String issue,
  }) async {
    final uri = _proxyUri('/api/generate');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mode': 'fix',
        'existingLua': existingLua,
        'issue': issue,
      }),
    );

    if (resp.statusCode == 404) {
      _proxyNotFoundError('/api/generate');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Proxy HTTP ${resp.statusCode}: ${resp.body.length > 600 ? resp.body.substring(0, 600) : resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    final lua = decoded is Map ? decoded['lua'] : null;
    final text = (lua is String) ? lua.trim() : '';
    if (text.isEmpty) {
      throw StateError('Empty response from proxy');
    }

    return text;
  }

  Future<String> _updateViaProxy({
    required String existingLua,
    required String instruction,
  }) async {
    final uri = _proxyUri('/api/generate');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mode': 'update',
        'prompt': instruction,
        'existingLua': existingLua,
      }),
    );

    if (resp.statusCode == 404) {
      _proxyNotFoundError('/api/generate');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Proxy HTTP ${resp.statusCode}: ${resp.body.length > 600 ? resp.body.substring(0, 600) : resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    final lua = decoded is Map ? decoded['lua'] : null;
    final text = (lua is String) ? lua.trim() : '';
    if (text.isEmpty) {
      throw StateError('Empty response from proxy');
    }

    return text;
  }

  Future<String> _generateDirect({required String prompt}) async {
    final key = _apiKey.trim();
    final models = await _fetchAvailableModels(apiKey: key);
    final preferredModel = _pickBestModel(models);

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    const system = '''You are an expert Roblox developer.
Generate a single Roblox Lua script for Roblox Studio based on the user prompt.

Rules:
- Output ONLY Lua code (no markdown, no backticks, no explanations).
- Prefer a single Script that can be placed in ServerScriptService.
- If the prompt needs parts/models, include a short Lua comment block at top with exact Workspace object names to create.
- Use safe defaults and avoid external assets.
- Keep the script concise but functional.
''';

    final modelCandidates = <String>[
      preferredModel,
      ...models.where((m) => m != preferredModel),
    ];

    Object? lastError;

    for (final model in modelCandidates) {
      try {
        final body = {
          'model': model,
          'temperature': 0.2,
          'max_tokens': 1200,
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': prompt},
          ],
        };

        final resp = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw StateError(
            'Groq HTTP ${resp.statusCode} (model=$model): ${resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body}',
          );
        }

        final decoded = jsonDecode(resp.body);
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) {
          throw StateError('Groq response missing choices (model=$model)');
        }

        final msg = choices[0]['message'];
        final content = msg is Map ? msg['content'] : null;
        final text = (content is String) ? content.trim() : '';
        if (text.isEmpty) {
          throw StateError('Empty response from Groq (model=$model)');
        }

        return text;
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError(lastError?.toString() ?? 'Groq request failed');
  }

  Future<List<String>> _generateStepsDirect({required String prompt}) async {
    const system =
        'You are an expert Roblox Studio instructor. Create 8-12 short one-line steps to build the game. Output ONLY the steps, one per line, no markdown.';

    final text = await _callDirect(
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': prompt.trim()},
      ],
    );

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lines.take(14).toList();
  }

  Future<String> _callDirect({
    required List<Map<String, String>> messages,
  }) async {
    final key = _apiKey.trim();
    final models = await _fetchAvailableModels(apiKey: key);
    final preferredModel = _pickBestModel(models);
    final modelCandidates = <String>[
      preferredModel,
      ...models.where((m) => m != preferredModel),
    ];

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    Object? lastError;

    for (final model in modelCandidates) {
      try {
        final body = {
          'model': model,
          'temperature': 0.2,
          'max_tokens': 1200,
          'messages': messages,
        };

        final resp = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw StateError(
            'Groq HTTP ${resp.statusCode} (model=$model): ${resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body}',
          );
        }

        final decoded = jsonDecode(resp.body);
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) {
          throw StateError('Groq response missing choices (model=$model)');
        }

        final msg = choices[0]['message'];
        final content = msg is Map ? msg['content'] : null;
        final text = (content is String) ? content.trim() : '';
        if (text.isEmpty) {
          throw StateError('Empty response from Groq (model=$model)');
        }

        return text;
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError(lastError?.toString() ?? 'Groq request failed');
  }

  Future<String> generateRobloxLua({required String prompt}) async {
    final res = await generateRobloxLuaWithSteps(prompt: prompt);
    return res.lua;
  }

  Future<({String lua, List<String> steps})> generateRobloxLuaWithSteps({
    required String prompt,
  }) async {
    final p = prompt.trim();
    if (p.isEmpty) {
      throw StateError('Missing prompt');
    }

    if (usesDirect) {
      final lua = await _generateDirect(prompt: p);
      final steps = await _generateStepsDirect(prompt: p);
      return (lua: lua, steps: steps);
    }

    return _generateViaProxyWithSteps(prompt: p);
  }

  Future<String> fixLua({
    required String existingLua,
    required String issue,
  }) async {
    final lua = existingLua.trim();
    final i = issue.trim();
    if (lua.isEmpty) throw StateError('Missing existing Lua');
    if (i.isEmpty) throw StateError('Missing issue');

    if (usesDirect) {
      const system =
          'You are an expert Roblox developer. Fix the provided Lua script based on the problem report. Output ONLY the full corrected Lua script.';
      return _callDirect(
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': 'Problem report:\n$i'},
          {'role': 'user', 'content': 'Existing Lua script:\n\n$lua'},
        ],
      );
    }

    return _fixViaProxy(existingLua: lua, issue: i);
  }

  Future<String> updateLua({
    required String existingLua,
    required String instruction,
  }) async {
    final lua = existingLua.trim();
    final ins = instruction.trim();
    if (lua.isEmpty) throw StateError('Missing existing Lua');
    if (ins.isEmpty) throw StateError('Missing instruction');

    if (usesDirect) {
      const system =
          'You are an expert Roblox developer. Apply the change request to the provided Lua script. Output ONLY the full updated Lua script.';
      return _callDirect(
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': 'Change request:\n$ins'},
          {'role': 'user', 'content': 'Existing Lua script:\n\n$lua'},
        ],
      );
    }

    return _updateViaProxy(existingLua: lua, instruction: ins);
  }
}
