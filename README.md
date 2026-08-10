# TI 2026 Predictor

Vue 3 + Vite frontend with optional Supabase-backed anonymous predictions.

## Local development

Requires Node.js 20.19 or newer.

```powershell
pnpm install
pnpm dev
```

Without Supabase environment variables the site runs in local demo mode.

## Shareable routes

The frontend uses hash routes so each menu can be shared directly from a static host:

- `/#/` overview
- `/#/standings` group standings
- `/#/groups` Swiss-round schedule
- `/#/elimination-round` Elimination Round
- `/#/playoffs` playoffs bracket
- `/#/my-predictions` my predictions

## Supabase setup

1. Create a Supabase project.
2. Open `Authentication > Providers > Anonymous` and enable anonymous sign-ins.
3. Open the Supabase SQL Editor and run [`supabase/schema.sql`](./supabase/schema.sql).
4. Copy `.env.example` to `.env.local`.
5. Set the project URL and anon/publishable key:

```dotenv
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-publishable-key
```

6. Restart the Vite development server.

The anon key is designed for browser use. Never put the Supabase service-role key in a `VITE_` environment variable.

## Data model

- `prediction_matches` stores server-validated matchups and lock times.
- `match_predictions` stores one row per anonymous user and match.
- `user_profiles` stores the nickname for each anonymous user.
- `submit_match_prediction` validates and upserts a vote.
- `get_prediction_totals` returns aggregate counts without exposing voters.
- `get_my_predictions` returns only the current anonymous user's choices.
- `get_my_profile` creates and returns a default nickname.
- `update_my_nickname` validates and updates the current user's nickname.

Update `prediction_matches` when the official playoff bracket changes. Matches automatically reject new predictions after `lock_at`.
