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

create table if not exists public.advancement_predictions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  slots jsonb not null check (jsonb_typeof(slots) = 'array'),
  is_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.advancement_prediction_settings (
  id boolean primary key default true check (id),
  lock_at timestamptz,
  is_open boolean not null default true,
  result_slots jsonb check (result_slots is null or jsonb_typeof(result_slots) = 'array'),
  results_published boolean not null default false,
  published_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.swiss_predictions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  picks jsonb not null default '{}'::jsonb check (jsonb_typeof(picks) = 'object'),
  play_in_pairings jsonb not null default '{}'::jsonb check (jsonb_typeof(play_in_pairings) = 'object'),
  play_in_winners jsonb not null default '{}'::jsonb check (jsonb_typeof(play_in_winners) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.swiss_prediction_settings (
  id boolean primary key default true check (id),
  lock_at timestamptz not null,
  is_open boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.advancement_prediction_settings (id, lock_at)
values (true, '2026-08-13 10:00:00+08')
on conflict (id) do nothing;

insert into public.swiss_prediction_settings (id, lock_at)
values (true, '2026-08-13 10:00:00+08')
on conflict (id) do update set lock_at = excluded.lock_at;

create index if not exists match_predictions_totals_idx
  on public.match_predictions (match_key, selected_team);

create index if not exists advancement_predictions_complete_idx
  on public.advancement_predictions (is_complete)
  where is_complete;

create index if not exists swiss_predictions_updated_idx
  on public.swiss_predictions (updated_at desc);

alter table public.prediction_matches enable row level security;
alter table public.match_predictions enable row level security;
alter table public.user_profiles enable row level security;
alter table public.advancement_predictions enable row level security;
alter table public.advancement_prediction_settings enable row level security;
alter table public.swiss_predictions enable row level security;
alter table public.swiss_prediction_settings enable row level security;

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

create or replace function public.validate_advancement_slots(
  p_slots text[],
  p_require_complete boolean default false
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_selected_count integer;
  v_distinct_count integer;
begin
  if coalesce(array_length(p_slots, 1), 0) <> 16 or array_lower(p_slots, 1) <> 1 then
    raise exception 'Advancement prediction must contain exactly 16 slots';
  end if;

  if exists (
    select 1
    from unnest(p_slots) as selected(team_id)
    where selected.team_id is not null
      and selected.team_id <> all (array[
        'Falcons', 'LGD', 'IronWing', 'Nigma', 'BoomBoys', 'OG', 'Vision', 'Resilience',
        'Spirit', 'XG', 'Liquid', 'Vici', 'Aurora', 'GamerLegion', 'Yandex', 'Huligani'
      ]::text[])
  ) then
    raise exception 'Advancement prediction contains an unknown team';
  end if;

  select count(team_id)::integer, count(distinct team_id)::integer
  into v_selected_count, v_distinct_count
  from unnest(p_slots) as selected(team_id)
  where selected.team_id is not null;

  if v_selected_count <> v_distinct_count then
    raise exception 'Each team may only appear once';
  end if;

  if p_require_complete and v_selected_count <> 16 then
    raise exception 'All 16 teams are required';
  end if;

  return v_selected_count;
end;
$$;

create or replace function public.advancement_bucket(p_position bigint)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when p_position = 1 then '4-0'
    when p_position between 2 and 3 then '4-1'
    when p_position between 4 and 8 then 'playin-winner'
    when p_position between 9 and 13 then 'playin-loser'
    when p_position between 14 and 15 then '1-4'
    when p_position = 16 then '0-4'
  end;
$$;

create or replace function public.advancement_correct_count(
  p_prediction jsonb,
  p_result jsonb
)
returns integer
language sql
immutable
strict
set search_path = ''
as $$
  select count(*)::integer
  from jsonb_array_elements_text(p_prediction) with ordinality as predicted(team_id, position)
  join jsonb_array_elements_text(p_result) with ordinality as actual(team_id, position)
    using (team_id)
  where public.advancement_bucket(predicted.position) = public.advancement_bucket(actual.position);
$$;

create or replace function public.submit_advancement_prediction(p_slots text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_settings public.advancement_prediction_settings%rowtype;
  v_selected_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_settings
  from public.advancement_prediction_settings
  where id = true;

  if not found
    or not v_settings.is_open
    or v_settings.results_published
    or (v_settings.lock_at is not null and now() >= v_settings.lock_at)
  then
    raise exception 'Advancement predictions are locked';
  end if;

  v_selected_count := public.validate_advancement_slots(p_slots, false);

  insert into public.advancement_predictions (user_id, slots, is_complete)
  values (v_user_id, to_jsonb(p_slots), v_selected_count = 16)
  on conflict (user_id)
  do update set
    slots = excluded.slots,
    is_complete = excluded.is_complete,
    updated_at = now();
end;
$$;

create or replace function public.get_advancement_prediction_summary()
returns table (
  prediction_slots jsonb,
  accepting_predictions boolean,
  lock_at timestamptz,
  results_published boolean,
  result_slots jsonb,
  selected_count integer,
  my_correct_count integer,
  my_accuracy numeric,
  total_players bigint,
  average_accuracy numeric,
  perfect_players bigint,
  my_rank bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_settings public.advancement_prediction_settings%rowtype;
  v_prediction_slots jsonb;
  v_is_complete boolean := false;
  v_accepting boolean;
  v_selected_count integer := 0;
  v_my_correct_count integer;
  v_my_accuracy numeric;
  v_total_players bigint := 0;
  v_average_accuracy numeric;
  v_perfect_players bigint;
  v_my_rank bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_settings
  from public.advancement_prediction_settings
  where id = true;

  if not found then
    raise exception 'Advancement prediction settings are missing';
  end if;

  select p.slots, p.is_complete
  into v_prediction_slots, v_is_complete
  from public.advancement_predictions p
  where p.user_id = v_user_id;

  if v_prediction_slots is not null then
    select count(*)::integer into v_selected_count
    from jsonb_array_elements(v_prediction_slots) as slot(value)
    where slot.value <> 'null'::jsonb;
  end if;

  v_accepting := v_settings.is_open
    and not v_settings.results_published
    and (v_settings.lock_at is null or now() < v_settings.lock_at);

  select count(*)::bigint into v_total_players
  from public.advancement_predictions p
  where p.is_complete;

  if v_settings.results_published and v_settings.result_slots is not null then
    if v_is_complete then
      v_my_correct_count := public.advancement_correct_count(v_prediction_slots, v_settings.result_slots);
      v_my_accuracy := round(v_my_correct_count * 100.0 / 16, 1);
    end if;

    select
      round(avg(public.advancement_correct_count(p.slots, v_settings.result_slots) * 100.0 / 16), 1),
      count(*) filter (where public.advancement_correct_count(p.slots, v_settings.result_slots) = 16)::bigint
    into v_average_accuracy, v_perfect_players
    from public.advancement_predictions p
    where p.is_complete;

    if v_is_complete then
      select (1 + count(*))::bigint into v_my_rank
      from public.advancement_predictions p
      where p.is_complete
        and public.advancement_correct_count(p.slots, v_settings.result_slots) > v_my_correct_count;
    end if;
  end if;

  return query select
    v_prediction_slots,
    v_accepting,
    v_settings.lock_at,
    v_settings.results_published,
    v_settings.result_slots,
    v_selected_count,
    v_my_correct_count,
    v_my_accuracy,
    v_total_players,
    v_average_accuracy,
    v_perfect_players,
    v_my_rank;
end;
$$;

create or replace function public.validate_swiss_prediction(
  p_picks jsonb,
  p_play_in_pairings jsonb,
  p_play_in_winners jsonb
)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_allowed_teams text[] := array[
    'Falcons', 'LGD', 'IronWing', 'Nigma', 'BoomBoys', 'OG', 'Vision', 'Resilience',
    'Spirit', 'XG', 'Liquid', 'Vici', 'Aurora', 'GamerLegion', 'Yandex', 'Huligani'
  ]::text[];
  v_count integer;
begin
  if p_picks is null or jsonb_typeof(p_picks) <> 'object'
    or p_play_in_pairings is null or jsonb_typeof(p_play_in_pairings) <> 'object'
    or p_play_in_winners is null or jsonb_typeof(p_play_in_winners) <> 'object'
  then
    raise exception 'Swiss prediction fields must be JSON objects';
  end if;

  select count(*)::integer into v_count from jsonb_each_text(p_picks);
  if v_count > 39 then
    raise exception 'Swiss prediction contains too many matches';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_picks) as prediction(match_key, winner)
    where prediction.match_key !~ '^sim-r[1-5]-[A-Za-z0-9]+--[A-Za-z0-9]+$'
      or prediction.winner <> all (v_allowed_teams)
      or split_part(regexp_replace(prediction.match_key, '^sim-r[1-5]-', ''), '--', 1) <> all (v_allowed_teams)
      or split_part(regexp_replace(prediction.match_key, '^sim-r[1-5]-', ''), '--', 2) <> all (v_allowed_teams)
      or prediction.winner not in (
        split_part(regexp_replace(prediction.match_key, '^sim-r[1-5]-', ''), '--', 1),
        split_part(regexp_replace(prediction.match_key, '^sim-r[1-5]-', ''), '--', 2)
      )
  ) then
    raise exception 'Swiss prediction contains an invalid match or team';
  end if;

  select count(*)::integer into v_count from jsonb_each_text(p_play_in_pairings);
  if v_count > 5 then
    raise exception 'Swiss prediction contains too many play-in pairings';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_play_in_pairings) as pairing(selector, opponent)
    where pairing.selector <> all (v_allowed_teams)
      or pairing.opponent <> all (v_allowed_teams)
      or pairing.selector = pairing.opponent
  ) or (
    select count(*) from jsonb_each_text(p_play_in_pairings)
  ) <> (
    select count(distinct pairing.opponent)
    from jsonb_each_text(p_play_in_pairings) as pairing(selector, opponent)
  ) then
    raise exception 'Swiss prediction contains invalid play-in pairings';
  end if;

  select count(*)::integer into v_count from jsonb_each_text(p_play_in_winners);
  if v_count > 5 then
    raise exception 'Swiss prediction contains too many play-in winners';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_play_in_winners) as result(selector, winner)
    where not (p_play_in_pairings ? result.selector)
      or result.winner <> result.selector
        and result.winner <> p_play_in_pairings ->> result.selector
  ) then
    raise exception 'Swiss prediction contains an invalid play-in winner';
  end if;
end;
$$;

create or replace function public.submit_swiss_prediction(
  p_picks jsonb,
  p_play_in_pairings jsonb,
  p_play_in_winners jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_settings public.swiss_prediction_settings%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_settings
  from public.swiss_prediction_settings
  where id = true;

  if not found
    or not v_settings.is_open
    or now() >= v_settings.lock_at
  then
    raise exception 'Swiss predictions are locked';
  end if;

  perform public.validate_swiss_prediction(p_picks, p_play_in_pairings, p_play_in_winners);

  insert into public.swiss_predictions (user_id, picks, play_in_pairings, play_in_winners)
  values (v_user_id, p_picks, p_play_in_pairings, p_play_in_winners)
  on conflict (user_id)
  do update set
    picks = excluded.picks,
    play_in_pairings = excluded.play_in_pairings,
    play_in_winners = excluded.play_in_winners,
    updated_at = now();
end;
$$;

create or replace function public.get_my_swiss_prediction()
returns table (
  has_prediction boolean,
  prediction_picks jsonb,
  play_in_pairings jsonb,
  play_in_winners jsonb,
  accepting_predictions boolean,
  lock_at timestamptz,
  saved_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_settings public.swiss_prediction_settings%rowtype;
  v_prediction public.swiss_predictions%rowtype;
  v_has_prediction boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_settings
  from public.swiss_prediction_settings
  where id = true;

  if not found then
    raise exception 'Swiss prediction settings are missing';
  end if;

  select * into v_prediction
  from public.swiss_predictions
  where user_id = v_user_id;
  v_has_prediction := found;

  return query select
    v_has_prediction,
    coalesce(v_prediction.picks, '{}'::jsonb),
    coalesce(v_prediction.play_in_pairings, '{}'::jsonb),
    coalesce(v_prediction.play_in_winners, '{}'::jsonb),
    v_settings.is_open and now() < v_settings.lock_at,
    v_settings.lock_at,
    v_prediction.updated_at;
end;
$$;

create or replace function public.publish_advancement_results(p_slots text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.validate_advancement_slots(p_slots, true);

  update public.advancement_prediction_settings
  set
    result_slots = to_jsonb(p_slots),
    results_published = true,
    is_open = false,
    published_at = now(),
    updated_at = now()
  where id = true;
end;
$$;

revoke all on public.match_predictions from anon, authenticated;
revoke all on public.user_profiles from anon, authenticated;
revoke all on public.advancement_predictions from anon, authenticated;
revoke all on public.advancement_prediction_settings from anon, authenticated;
revoke all on public.swiss_predictions from anon, authenticated;
revoke all on public.swiss_prediction_settings from anon, authenticated;
grant select on public.prediction_matches to anon, authenticated;

revoke all on function public.submit_match_prediction(text, text) from public;
revoke all on function public.get_prediction_totals(text[]) from public;
revoke all on function public.get_my_predictions() from public;
revoke all on function public.get_my_profile() from public;
revoke all on function public.update_my_nickname(text) from public;
revoke all on function public.validate_advancement_slots(text[], boolean) from public;
revoke all on function public.advancement_bucket(bigint) from public;
revoke all on function public.advancement_correct_count(jsonb, jsonb) from public;
revoke all on function public.submit_advancement_prediction(text[]) from public;
revoke all on function public.get_advancement_prediction_summary() from public;
revoke all on function public.publish_advancement_results(text[]) from public;
revoke all on function public.validate_swiss_prediction(jsonb, jsonb, jsonb) from public;
revoke all on function public.submit_swiss_prediction(jsonb, jsonb, jsonb) from public;
revoke all on function public.get_my_swiss_prediction() from public;

grant execute on function public.submit_match_prediction(text, text) to authenticated;
grant execute on function public.get_prediction_totals(text[]) to anon, authenticated;
grant execute on function public.get_my_predictions() to authenticated;
grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.update_my_nickname(text) to authenticated;
grant execute on function public.submit_advancement_prediction(text[]) to authenticated;
grant execute on function public.get_advancement_prediction_summary() to authenticated;
grant execute on function public.submit_swiss_prediction(jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.get_my_swiss_prediction() to authenticated;

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
