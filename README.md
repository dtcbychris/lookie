# Builder Copilot

A user-controlled, screen-aware copilot for non-technical builders. Capture a
single screenshot, ask a question, get structured AI guidance plus a
copy-pasteable prompt for Claude Code, Lovable, or Cursor.

## Status

- **Phase 1** — capture + UX + mock provider + local history. ✅
- **Phase 2** — real `/api/analyze` route backed by OpenAI vision. ✅
- **Phase 3** — persistent project memory (Project Brain + decisions),
  recent-history injection, sharper Brixley system prompt. ✅ (this commit)
- Phase 4+ — Anthropic provider, redaction, export/share, desktop wrapper.

## Setup

Requires Node 20+.

```bash
npm install
cp .env.example .env
# fill in OPENAI_API_KEY
npm run dev
```

Open <http://localhost:5173>. In **Settings & Privacy → AI provider**, switch
from `mock` to `openai`. Capture, ask, analyze.

### Environment variables

| Variable           | Where it's read | Purpose                                              |
| ------------------ | --------------- | ---------------------------------------------------- |
| `VITE_APP_NAME`    | Frontend        | Display name (optional).                             |
| `AI_PROVIDER`      | Server only     | `openai` (default). Reserved values: `anthropic`.    |
| `OPENAI_API_KEY`   | Server only     | Required when `AI_PROVIDER=openai`.                  |
| `OPENAI_MODEL`     | Server only     | Defaults to `gpt-4o`. Override to `gpt-4o-mini` etc. |
| `ANTHROPIC_API_KEY`| Server only     | Reserved for the next provider; not yet wired.       |

`OPENAI_API_KEY` is **only** read server-side in `api/analyze.ts`. It is never
included in the frontend bundle. Do not prefix it with `VITE_`.

## Local development

`npm run dev` starts Vite on port 5173. A dev-only Vite plugin
(`vite.config.ts → devApiPlugin`) mounts every file in `api/` as a Node
middleware so `/api/analyze` works the same way it will on Vercel — no separate
backend process needed.

The plugin pulls non-`VITE_` keys from `.env` into `process.env`, mirroring
Vercel's runtime. Restart the dev server after editing `.env`.

## Deploying to Vercel

`api/analyze.ts` follows Vercel's serverless-function convention, so deployment
is zero-config:

1. Push the branch to GitHub.
2. Import the repo in Vercel.
3. In **Project Settings → Environment Variables**, add:
   - `OPENAI_API_KEY` (required)
   - `OPENAI_MODEL` (optional, defaults to `gpt-4o`)
   - `AI_PROVIDER=openai` (optional, that's the default)
4. Deploy. Vite builds the static frontend; Vercel hosts `api/analyze.ts` as a
   serverless function at `/api/analyze`.

No `vercel.json` is required. If you later need to tune the function (longer
timeout for large screenshots, region pinning), add one.

## Architecture

```
src/                  React app (Vite + Tailwind)
  lib/
    capture.ts        getDisplayMedia → single PNG, stops the stream immediately
    analyze.ts        Provider abstraction (mock | remote-via-/api/analyze)
    promptTargets.ts  Wraps the model's prompt for Claude Code / Lovable / Cursor
    storage.ts        localStorage for projects, history, settings
  components/         App shell, capture panel, analysis view, settings
  types.ts            Shared types — kept in sync with api/_lib/types.ts

api/
  analyze.ts          POST /api/analyze — Vercel handler
  _lib/
    openai.ts         OpenAI vision call + ProviderError
    prompt.ts         System prompt + JSON parser/validator
    http.ts           readJsonBody + sendJson helpers
    types.ts          Server mirror of AnalysisResponse / AnalyzeRequest
```

### Request contract

```ts
POST /api/analyze
Content-Type: application/json

{
  "imageBase64": "<base64 PNG, no data URL prefix>",
  "question": "What should I do next?",
  "projectContext": "Vibal is a marketplace…",            // legacy/overview, optional
  "projectBrain": "Overview:\nVibal…\n\nTech stack:\n…",   // pre-rendered, optional
  "recentHistoryContext": "Recent project history:\n…"     // last 5 analyses, no images
}
```

`projectBrain` and `recentHistoryContext` are pre-rendered strings produced by
`src/lib/projectContext.ts` so the server contract stays one image + a few
text blocks. The server prefers `projectBrain` over `projectContext` when both
are sent.

Returns `200 AnalysisResponse` on success, or `{ "error": "..." }` with a
non-2xx status. Status-code mapping:

- `400` — missing/invalid image, malformed body
- `405` — non-POST
- `500` — `OPENAI_API_KEY` not set, or auth rejected by OpenAI
- `502` — upstream OpenAI failure or unparseable model output

## Privacy

- Capture is **manual only**. The MediaStream stops the moment one frame is
  taken — no background recording.
- Screenshots are **not saved** unless you opt in under Settings → Privacy.
- Chat history (questions + responses) is on by default but local-only.
- No telemetry. The only outbound request is `/api/analyze` to your own
  backend, which then calls OpenAI.

## Adding the Anthropic provider

`api/_lib/openai.ts` is intentionally isolated. To add Claude:

1. Create `api/_lib/anthropic.ts` with the same `analyzeWith…(input)` shape
   returning `Promise<AnalysisResponse>`.
2. In `api/analyze.ts`, branch on `process.env.AI_PROVIDER`.
3. Add `"anthropic"` to the provider radio in `src/components/SettingsPanel.tsx`.

The wire format and the `AnalysisResponse` shape do not change.
