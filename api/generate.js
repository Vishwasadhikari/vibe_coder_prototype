const GROQ_BASE = 'https://api.groq.com/openai/v1';

function pickBestModel(models, override) {
  if (override && models.includes(override)) return override;

  const score = (m) => {
    const s = String(m).toLowerCase();
    let sc = 0;
    if (s.includes('llama')) sc += 50;
    if (s.includes('3.3') || s.includes('3.2') || s.includes('3.1')) sc += 25;
    if (s.includes('70b')) sc += 20;
    if (s.includes('versatile') || s.includes('instruct') || s.includes('it')) sc += 10;
    if (s.includes('8b')) sc += 5;
    if (s.includes('vision')) sc -= 5;
    if (s.includes('whisper') || s.includes('tts') || s.includes('embedding')) sc -= 100;
    return sc;
  };

  let best = models[0];
  let bestScore = -1e9;
  for (const m of models) {
    const sc = score(m);
    if (sc > bestScore) {
      bestScore = sc;
      best = m;
    }
  }
  return best;
}

async function listModels(apiKey) {
  const resp = await fetch(`${GROQ_BASE}/models`, {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Models HTTP ${resp.status}: ${text.slice(0, 500)}`);
  }

  const json = await resp.json();
  const data = Array.isArray(json.data) ? json.data : [];
  const ids = data
    .map((d) => d && d.id)
    .filter((x) => typeof x === 'string' && x.trim());
  if (!ids.length) throw new Error('No models returned by Groq');
  return ids;
}

function parseSteps(text) {
  if (!text || typeof text !== 'string') return [];
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  const out = [];
  for (const line of lines) {
    const cleaned = line.replace(/^\(?\d+\)?[\.)\-:]*\s*/, '').trim();
    if (cleaned) out.push(cleaned);
  }
  return out.slice(0, 14);
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      res.status(500).json({ error: 'GROQ_API_KEY not configured on server' });
      return;
    }

    const { mode = 'generate', prompt, existingLua, issue } = req.body || {};
    const m = String(mode || 'generate').toLowerCase();

    if (m === 'fix') {
      if (!existingLua || typeof existingLua !== 'string' || !existingLua.trim()) {
        res.status(400).json({ error: 'Missing existingLua' });
        return;
      }
      if (!issue || typeof issue !== 'string' || !issue.trim()) {
        res.status(400).json({ error: 'Missing issue' });
        return;
      }
    } else {
      if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
        res.status(400).json({ error: 'Missing prompt' });
        return;
      }
    }

    const models = await listModels(apiKey);
    const model = pickBestModel(models, process.env.GROQ_MODEL);

    const systemGenerate = `You are an expert Roblox developer.
Generate a single Roblox Lua script for Roblox Studio based on the user prompt.

Rules:
- Output ONLY Lua code (no markdown, no backticks, no explanations).
- Prefer a single Script that can be placed in ServerScriptService.
- If the prompt needs parts/models, include a short Lua comment block at top with exact Workspace object names to create.
- Use safe defaults and avoid external assets.
- Keep the script concise but functional.`;

    const systemFix = `You are an expert Roblox developer.
You will be given an EXISTING Roblox Lua script and a problem report.

Task:
- Fix the script so it works as intended.
- Output the FULL corrected Lua script.

Rules:
- Output ONLY Lua code (no markdown, no backticks, no explanations).
- Keep structure stable, but correct logic, missing services, wrong event usage, nil references, etc.
- Add minimal comments only if required to clarify required Workspace objects.`;

    const systemUpdate = `You are an expert Roblox developer.
You will be given an EXISTING Roblox Lua script and a change request.

Task:
- Apply the requested changes.
- Output the FULL updated Lua script.

Rules:
- Output ONLY Lua code (no markdown, no backticks, no explanations).
- Preserve existing behavior unless the user request changes it.
- If you add new instances/services, do it safely and defensively.`;

    let messages;
    if (m === 'fix') {
      messages = [
        { role: 'system', content: systemFix },
        { role: 'user', content: `Problem report:\n${issue.trim()}` },
        { role: 'user', content: `Existing Lua script:\n\n${existingLua.trim()}` },
      ];
    } else if (m === 'update') {
      messages = [
        { role: 'system', content: systemUpdate },
        { role: 'user', content: `Change request:\n${String(prompt).trim()}` },
        { role: 'user', content: `Existing Lua script:\n\n${String(existingLua || '').trim()}` },
      ];
    } else {
      messages = [
        { role: 'system', content: systemGenerate },
        { role: 'user', content: String(prompt).trim() },
      ];
    }

    const body = {
      model,
      temperature: 0.2,
      max_tokens: 1200,
      messages,
    };

    const resp = await fetch(`${GROQ_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const raw = await resp.text();
    if (!resp.ok) {
      res.status(resp.status).json({ error: raw.slice(0, 2000), model });
      return;
    }

    const json = JSON.parse(raw);
    const content = json?.choices?.[0]?.message?.content;
    const text = typeof content === 'string' ? content.trim() : '';
    if (!text) {
      res.status(502).json({ error: 'Empty content from Groq', model });
      return;
    }

    let steps = [];
    if (m === 'generate') {
      try {
        const stepsSystem = `You are an expert Roblox Studio instructor.
Create a short step-by-step build plan for the user to implement the game in Roblox Studio.

Rules:
- Output ONLY the steps (no headings, no markdown).
- 8 to 12 lines.
- Each line must be ONE short step with a ONE-line explanation.
- Focus on what objects to create (Workspace, ReplicatedStorage, ServerScriptService) and where to place the script(s).`;

        const stepsBody = {
          model,
          temperature: 0.2,
          max_tokens: 500,
          messages: [
            { role: 'system', content: stepsSystem },
            { role: 'user', content: String(prompt).trim() },
          ],
        };

        const stepsResp = await fetch(`${GROQ_BASE}/chat/completions`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(stepsBody),
        });

        if (stepsResp.ok) {
          const stepsRaw = await stepsResp.text();
          const stepsJson = JSON.parse(stepsRaw);
          const stepsContent = stepsJson?.choices?.[0]?.message?.content;
          steps = parseSteps(typeof stepsContent === 'string' ? stepsContent : '');
        }
      } catch {
        steps = [];
      }
    }

    res.status(200).json({ lua: text, model, steps });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
}
