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
- `/#/advancement-prediction` advancement prediction
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
- `advancement_predictions` stores one 16-slot advancement prediction per anonymous user.
- `advancement_prediction_settings` stores the deadline and the official result.
- `swiss_predictions` stores each anonymous user's latest Swiss simulation, including play-in pairings and winners.
- `swiss_prediction_settings` freezes the cloud snapshot at the Swiss prediction deadline.
- `submit_match_prediction` validates and upserts a vote.
- `get_prediction_totals` returns aggregate counts without exposing voters.
- `get_my_predictions` returns only the current anonymous user's choices.
- `get_my_profile` creates and returns a default nickname.
- `update_my_nickname` validates and updates the current user's nickname.
- `submit_advancement_prediction` validates and saves a partial or complete advancement prediction.
- `get_advancement_prediction_summary` returns the current user's prediction and aggregate result statistics.
- `publish_advancement_results` validates and publishes the official result; it is not callable from the frontend.
- `submit_swiss_prediction` validates and saves the latest Swiss simulation snapshot.
- `get_my_swiss_prediction` returns only the current anonymous user's frozen or active snapshot.

Update `prediction_matches` when the official playoff bracket changes. Matches automatically reject new predictions after `lock_at`.

The Swiss prediction deadline is `2026-08-13 10:00:00+08`. Supabase enforces this with its server clock. After the deadline, the standings prediction mode remains editable locally, but its cloud snapshot no longer changes.

## Advancement results

The default advancement prediction deadline is `2026-08-13 10:00:00+08`. Change it before the deadline if the official schedule changes:

```sql
update public.advancement_prediction_settings
set lock_at = '2026-08-13 10:00:00+08', updated_at = now()
where id = true;
```

When all results are official, run `publish_advancement_results` in the Supabase SQL Editor. The 16 team IDs must be unique and ordered by these slots:

1. `4-0`: 1 team
2. `4-1`: 2 teams
3. Elimination Round winners: 5 teams
4. Elimination Round losers: 5 teams
5. `1-4`: 2 teams
6. `0-4`: 1 team

```sql
select public.publish_advancement_results(array[
  'TEAM_4_0',
  'TEAM_4_1_A', 'TEAM_4_1_B',
  'PLAYIN_WINNER_1', 'PLAYIN_WINNER_2', 'PLAYIN_WINNER_3', 'PLAYIN_WINNER_4', 'PLAYIN_WINNER_5',
  'PLAYIN_LOSER_1', 'PLAYIN_LOSER_2', 'PLAYIN_LOSER_3', 'PLAYIN_LOSER_4', 'PLAYIN_LOSER_5',
  'TEAM_1_4_A', 'TEAM_1_4_B',
  'TEAM_0_4'
]::text[]);
```

Replace every placeholder with a valid internal team ID from `src/App.vue`. Publishing also closes predictions. Accuracy compares each team's result category, so ordering inside the same category does not affect the score. Only predictions with all 16 teams assigned are included in global averages and rankings.
