import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey)

const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false,
      },
    })
  : null

function totalsToMap(rows = []) {
  return rows.reduce((totals, row) => {
    const matchKey = String(row.match_key)
    totals[matchKey] ||= {}
    totals[matchKey][row.selected_team] = Number(row.vote_count)
    return totals
  }, {})
}

function advancementSummaryFromRows(rows = []) {
  const row = rows?.[0]
  if (!row) return null
  const numberOrNull = value => value === null || value === undefined ? null : Number(value)
  return {
    slots: Array.isArray(row.prediction_slots) ? row.prediction_slots : null,
    acceptingPredictions: Boolean(row.accepting_predictions),
    lockAt: row.lock_at || null,
    resultsPublished: Boolean(row.results_published),
    resultSlots: Array.isArray(row.result_slots) ? row.result_slots : null,
    selectedCount: Number(row.selected_count || 0),
    myCorrectCount: numberOrNull(row.my_correct_count),
    myAccuracy: numberOrNull(row.my_accuracy),
    totalPlayers: Number(row.total_players || 0),
    averageAccuracy: numberOrNull(row.average_accuracy),
    perfectPlayers: Number(row.perfect_players || 0),
    myRank: numberOrNull(row.my_rank),
  }
}

function swissPredictionFromRows(rows = []) {
  const row = rows?.[0]
  if (!row) return null
  return {
    hasPrediction: Boolean(row.has_prediction),
    picks: row.prediction_picks && typeof row.prediction_picks === 'object' ? row.prediction_picks : {},
    playInPairings: row.play_in_pairings && typeof row.play_in_pairings === 'object' ? row.play_in_pairings : {},
    playInWinners: row.play_in_winners && typeof row.play_in_winners === 'object' ? row.play_in_winners : {},
    acceptingPredictions: Boolean(row.accepting_predictions),
    lockAt: row.lock_at || null,
    savedAt: row.saved_at || null,
  }
}

async function ensureAnonymousSession() {
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession()
  if (sessionError) throw sessionError
  if (sessionData.session) return sessionData.session

  const { data, error } = await supabase.auth.signInAnonymously()
  if (error) throw error
  return data.session
}

export async function initializePredictionStore(matchKeys) {
  if (!supabase) return { configured: false, predictions: {}, totals: {} }

  await ensureAnonymousSession()
  const [myPredictionsResult, totalsResult, profileResult] = await Promise.all([
    supabase.rpc('get_my_predictions'),
    supabase.rpc('get_prediction_totals', { p_match_keys: matchKeys.map(String) }),
    supabase.rpc('get_my_profile'),
  ])

  if (myPredictionsResult.error) throw myPredictionsResult.error
  if (totalsResult.error) throw totalsResult.error
  if (profileResult.error) throw profileResult.error

  return {
    configured: true,
    predictions: (myPredictionsResult.data || []).reduce((items, row) => {
      items[String(row.match_key)] = row.selected_team
      return items
    }, {}),
    totals: totalsToMap(totalsResult.data),
    nickname: profileResult.data?.[0]?.nickname || '',
  }
}

export async function updateCloudNickname(nickname) {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.rpc('update_my_nickname', {
    p_nickname: nickname,
  })
  if (error) throw error
  return data
}

export async function submitCloudPrediction(matchKey, selectedTeam, matchKeys) {
  if (!supabase) throw new Error('Supabase is not configured')

  const { error } = await supabase.rpc('submit_match_prediction', {
    p_match_key: String(matchKey),
    p_selected_team: selectedTeam,
  })
  if (error) throw error

  const { data, error: totalsError } = await supabase.rpc('get_prediction_totals', {
    p_match_keys: matchKeys.map(String),
  })
  if (totalsError) throw totalsError
  return totalsToMap(data)
}

export async function getCloudAdvancementPrediction() {
  if (!supabase) return null
  await ensureAnonymousSession()

  const { data, error } = await supabase.rpc('get_advancement_prediction_summary')
  if (error) throw error
  return advancementSummaryFromRows(data)
}

export async function submitCloudAdvancementPrediction(slots) {
  if (!supabase) throw new Error('Supabase is not configured')
  await ensureAnonymousSession()

  const { error } = await supabase.rpc('submit_advancement_prediction', {
    p_slots: slots,
  })
  if (error) throw error
  return getCloudAdvancementPrediction()
}

export async function getCloudSwissPrediction() {
  if (!supabase) return null
  await ensureAnonymousSession()

  const { data, error } = await supabase.rpc('get_my_swiss_prediction')
  if (error) throw error
  return swissPredictionFromRows(data)
}

export async function submitCloudSwissPrediction({ picks, playInPairings, playInWinners }) {
  if (!supabase) throw new Error('Supabase is not configured')
  await ensureAnonymousSession()

  const { error } = await supabase.rpc('submit_swiss_prediction', {
    p_picks: picks,
    p_play_in_pairings: playInPairings,
    p_play_in_winners: playInWinners,
  })
  if (error) throw error
  return getCloudSwissPrediction()
}
