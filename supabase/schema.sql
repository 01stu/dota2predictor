-- Run this file once in the Supabase SQL Editor.
-- Anonymous Auth must also be enabled in Authentication > Providers > Anonymous.

create table if not exists public.prediction_matches (
  match_key text primary key,
  stage text not null,
  team_a text not null,
  team_b text not null,
  lock_at timestamptz,
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_predictions (
  id uuid primary key default gen_random_uuid(),
  match_key text not null references public.prediction_matches(match_key) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  selected_team text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint one_prediction_per_user_match unique (match_key, user_id)
);

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 2 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists match_predictions_totals_idx
  on public.match_predictions (match_key, selected_team);

alter table public.prediction_matches enable row level security;
alter table public.match_predictions enable row level security;
alter table public.user_profiles enable row level security;

drop policy if exists "public match metadata is readable" on public.prediction_matches;
create policy "public match metadata is readable"
  on public.prediction_matches for select
  to anon, authenticated
  using (true);

-- No direct policies are created for match_predictions. All access goes through
-- the security-definer functions below, so individual voters are never exposed.

create or replace function public.submit_match_prediction(
  p_match_key text,
  p_selected_team text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_match public.prediction_matches%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_match
  from public.prediction_matches
  where match_key = p_match_key;

  if not found then
    raise exception 'Unknown match';
  end if;

  if not v_match.is_open or (v_match.lock_at is not null and now() >= v_match.lock_at) then
    raise exception 'Predictions are locked for this match';
  end if;

  if p_selected_team <> v_match.team_a and p_selected_team <> v_match.team_b then
    raise exception 'Selected team is not part of this match';
  end if;

  insert into public.match_predictions (match_key, user_id, selected_team)
  values (p_match_key, v_user_id, p_selected_team)
  on conflict (match_key, user_id)
  do update set
    selected_team = excluded.selected_team,
    updated_at = now();
end;
$$;

create or replace function public.get_prediction_totals(p_match_keys text[] default null)
returns table (match_key text, selected_team text, vote_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select p.match_key, p.selected_team, count(*)::bigint as vote_count
  from public.match_predictions p
  where p_match_keys is null or p.match_key = any(p_match_keys)
  group by p.match_key, p.selected_team
  order by p.match_key, p.selected_team;
$$;

create or replace function public.get_my_predictions()
returns table (match_key text, selected_team text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.match_key, p.selected_team
  from public.match_predictions p
  where p.user_id = auth.uid();
$$;

create or replace function public.get_my_profile()
returns table (nickname text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.user_profiles (user_id, nickname)
  values (
    v_user_id,
    '预测者-' || upper(substr(replace(v_user_id::text, '-', ''), 1, 6))
  )
  on conflict (user_id) do nothing;

  return query
  select p.nickname
  from public.user_profiles p
  where p.user_id = v_user_id;
end;
$$;

create or replace function public.update_my_nickname(p_nickname text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_nickname text := trim(p_nickname);
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if char_length(v_nickname) < 2 or char_length(v_nickname) > 20 then
    raise exception 'Nickname must be between 2 and 20 characters';
  end if;

  insert into public.user_profiles (user_id, nickname)
  values (v_user_id, v_nickname)
  on conflict (user_id)
  do update set
    nickname = excluded.nickname,
    updated_at = now();

  return v_nickname;
end;
$$;

revoke all on public.match_predictions from anon, authenticated;
revoke all on public.user_profiles from anon, authenticated;
grant select on public.prediction_matches to anon, authenticated;

revoke all on function public.submit_match_prediction(text, text) from public;
revoke all on function public.get_prediction_totals(text[]) from public;
revoke all on function public.get_my_predictions() from public;
revoke all on function public.get_my_profile() from public;
revoke all on function public.update_my_nickname(text) from public;

grant execute on function public.submit_match_prediction(text, text) to authenticated;
grant execute on function public.get_prediction_totals(text[]) to anon, authenticated;
grant execute on function public.get_my_predictions() to authenticated;
grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.update_my_nickname(text) to authenticated;

insert into public.prediction_matches (match_key, stage, team_a, team_b, lock_at)
values
  ('1', 'group', 'Falcons', 'LGD', '2026-08-13 10:00:00+08'),
  ('2', 'group', 'IronWing', 'Nigma', '2026-08-13 10:00:00+08'),
  ('3', 'group', 'BoomBoys', 'OG', '2026-08-13 10:00:00+08'),
  ('4', 'group', 'Vision', 'Resilience', '2026-08-13 10:00:00+08'),
  ('5', 'group', 'Spirit', 'XG', '2026-08-13 13:00:00+08'),
  ('6', 'group', 'Liquid', 'Vici', '2026-08-13 13:00:00+08'),
  ('7', 'group', 'Aurora', 'GamerLegion', '2026-08-13 13:00:00+08'),
  ('8', 'group', 'Yandex', 'Huligani', '2026-08-13 13:00:00+08'),
  ('e1', 'elimination', 'Nigma', 'GamerLegion', '2026-08-20 10:00:00+08'),
  ('e2', 'elimination', 'OG', 'Vici', '2026-08-20 13:00:00+08'),
  ('e3', 'elimination', 'Vision', 'BoomBoys', '2026-08-20 16:00:00+08'),
  ('e4', 'elimination', 'Liquid', 'Resilience', '2026-08-20 19:00:00+08'),
  ('e5', 'elimination', 'Yandex', 'Huligani', '2026-08-20 22:00:00+08'),
  ('u1', 'upper', 'Falcons', 'Aurora', '2026-08-22 10:00:00+02'),
  ('u2', 'upper', 'Spirit', 'OG', '2026-08-22 13:00:00+02'),
  ('u3', 'upper', 'Falcons', 'Spirit', '2026-08-24 10:00:00+02'),
  ('u4', 'upper', 'Liquid', 'XG', '2026-08-22 16:00:00+02'),
  ('u5', 'upper', 'Liquid', 'LGD', '2026-08-24 13:00:00+02'),
  ('u6', 'upper', 'Falcons', 'Liquid', '2026-08-27 13:00:00+02'),
  ('u7', 'upper', 'LGD', 'Yandex', '2026-08-22 16:00:00+02'),
  ('l1', 'lower', 'Nigma', 'GamerLegion', '2026-08-23 10:00:00+02'),
  ('l2', 'lower', 'Vici', 'BoomBoys', '2026-08-23 13:00:00+02'),
  ('l3', 'lower', 'LGD', 'Nigma', '2026-08-25 10:00:00+02'),
  ('l4', 'lower', 'Yandex', 'Vici', '2026-08-25 13:00:00+02'),
  ('l5', 'lower', 'Nigma', 'Yandex', '2026-08-26 13:00:00+02'),
  ('l6', 'lower', 'Yandex', 'Spirit', '2026-08-28 13:00:00+02'),
  ('final', 'final', 'Falcons', 'Yandex', '2026-08-30 16:00:00+02')
on conflict (match_key) do update set
  stage = excluded.stage,
  team_a = excluded.team_a,
  team_b = excluded.team_b,
  lock_at = excluded.lock_at,
  updated_at = now();
