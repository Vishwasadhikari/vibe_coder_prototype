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

    const { prompt } = req.body || {};
    if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
      res.status(400).json({ error: 'Missing prompt' });
      return;
    }

    const models = await listModels(apiKey);
    const model = pickBestModel(models, process.env.GROQ_MODEL);

    const system = `You are an expert Roblox developer.
Generate a single Roblox Lua script for Roblox Studio based on the user prompt.

Rules:
- Output ONLY Lua code (no markdown, no backticks, no explanations).
- Prefer a single Script that can be placed in ServerScriptService.
- If the prompt needs parts/models, include a short Lua comment block at top with exact Workspace object names to create.
- Use safe defaults and avoid external assets.
- Keep the script concise but functional.`;

    const body = {
      model,
      temperature: 0.2,
      max_tokens: 1200,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: prompt },
      ],
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

    res.status(200).json({ lua: text, model });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
}
