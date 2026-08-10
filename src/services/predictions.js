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
