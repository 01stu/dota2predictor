<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import {
  ArrowRight, CalendarDays, ChevronDown, Clock3, Database,
  LayoutDashboard, ListOrdered, Medal, Menu, Pencil, Radio, Shield, Sparkles, Swords,
  Target, Trophy, UserRound, Users, X
} from 'lucide-vue-next'
import TeamLogo from './components/TeamLogo.vue'
import { heroes } from './data/heroes'
import { playerIds } from './data/playerIds'
import {
  initializePredictionStore,
  isSupabaseConfigured,
  submitCloudPrediction,
  updateCloudNickname,
} from './services/predictions'

const profileStorageKey = 'ti2026-profile-v1'
const legacyNicknamePattern = /^(?:(?:天辉|夜魇|不朽|精准|冷静|神秘)(?:预言家|信使|队长|选手|观战者|教练)\d{3}|预测者-[A-F0-9]{6})$/i

function randomItem(items) {
  return items[Math.floor(Math.random() * items.length)]
}

function createDefaultProfile(hero = randomItem(heroes)) {
  const compatiblePlayerIds = playerIds.filter(playerId => `${playerId}-${hero.nameLoc}`.length <= 20)
  const playerId = randomItem(compatiblePlayerIds.length ? compatiblePlayerIds : playerIds)
  return {
    nickname: `${playerId}-${hero.nameLoc}`,
    heroId: hero.id,
  }
}

function saveLocalProfile(profile) {
  localStorage.setItem(profileStorageKey, JSON.stringify(profile))
  localStorage.setItem('ti2026-nickname', profile.nickname)
}

function loadLocalProfile() {
  try {
    const storedProfile = JSON.parse(localStorage.getItem(profileStorageKey))
    if (storedProfile?.nickname && heroes.some(hero => hero.id === storedProfile.heroId)) {
      return storedProfile
    }
  } catch {
    // Fall through to legacy nickname migration.
  }

  const existingNickname = localStorage.getItem('ti2026-nickname')?.trim()
  const generatedProfile = createDefaultProfile()
  if (existingNickname && !legacyNicknamePattern.test(existingNickname)) {
    generatedProfile.nickname = existingNickname
  }
  saveLocalProfile(generatedProfile)
  return generatedProfile
}

const viewPaths = {
  overview: '/',
  standings: '/standings',
  groups: '/groups',
  elimination: '/elimination-round',
  playoffs: '/playoffs',
  'my-picks': '/my-predictions',
}
const pathViews = Object.fromEntries(Object.entries(viewPaths).map(([view, path]) => [path, view]))

function viewFromHash() {
  const path = window.location.hash.replace(/^#/, '').split('?')[0] || '/'
  return pathViews[path] || 'overview'
}

const activeView = ref(viewFromHash())
const activeSwissRound = ref(1)
const mobileMenu = ref(false)
const toast = ref('')
const dataMode = ref(isSupabaseConfigured ? 'connecting' : 'demo')
const cloudActive = ref(false)
const submittingMatch = ref(null)
const initialProfile = loadLocalProfile()
const nickname = ref(initialProfile.nickname)
const profileHeroId = ref(initialProfile.heroId)
const heroImageFailed = ref(false)
const nicknameDraft = ref('')
const nicknameError = ref('')
const nicknameSaving = ref(false)
const profileOpen = ref(false)

const navItems = [
  { id: 'overview', label: '赛事总览', icon: LayoutDashboard },
  { id: 'standings', label: '小组赛排名', icon: ListOrdered },
  { id: 'groups', label: '小组赛', icon: Users },
  { id: 'elimination', label: '晋级附加赛', icon: Shield },
  { id: 'playoffs', label: '淘汰赛', icon: Swords },
  { id: 'my-picks', label: '我的预测', icon: Target },
]

const swissRounds = [1, 2, 3, 4, 5]

const teamMeta = {
  Falcons: { name: 'Team Falcons', short: 'FLC', color: '#e9ca75', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/9247354.png' },
  LGD: { name: 'LGD Gaming', short: 'LGD', color: '#df3d3b', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/10150538.png' },
  IronWing: { name: 'Iron Wing', short: 'IW', color: '#b6b9c1', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/10150413.png' },
  Nigma: { name: 'Nigma Galaxy', short: 'NGX', color: '#6b93dc', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/10136357.png' },
  BoomBoys: { name: 'BOOMBOYS', short: 'BB', color: '#e85b3e', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/8255888.png' },
  OG: { name: 'OG', short: 'OG', color: '#e9e9e9', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/2586976.png' },
  Vision: { name: 'Team Vision', short: 'VIS', color: '#66b3b8', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/9572001.png' },
  Resilience: { name: 'Team Resilience', short: 'RES', color: '#d8a96d', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/5017210.png' },
  Spirit: { name: 'Team Spirit', short: 'TS', color: '#f0c75d', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/7119388.png' },
  XG: { name: 'Xtreme Gaming', short: 'XG', color: '#e15d58', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/8261500.png' },
  Liquid: { name: 'Team Liquid', short: 'TL', color: '#67a9e6', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/2163.png' },
  Vici: { name: 'Vici Gaming', short: 'VG', color: '#e67b76', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/726228.png' },
  Aurora: { name: 'Aurora Gaming', short: 'AUR', color: '#ad78df', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/9467224.png' },
  GamerLegion: { name: 'GamerLegion', short: 'GL', color: '#df3d39', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/9964962.png' },
  Yandex: { name: 'Team Yandex', short: 'YAN', color: '#e6d65e', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/9823272.png' },
  Huligani: { name: 'HULIGANI', short: 'HUL', color: '#c8c8cd', logo: 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/teamlogos/10149530.png' },
}

const swissStandings = [
  { rank: 1, team: 'Falcons', matches: '0 - 0', games: '0 - 0', rounds: ['LGD', null, null, null, null], zone: 'advance' },
  { rank: 1, team: 'LGD', matches: '0 - 0', games: '0 - 0', rounds: ['Falcons', null, null, null, null], zone: 'advance' },
  { rank: 1, team: 'IronWing', matches: '0 - 0', games: '0 - 0', rounds: ['Nigma', null, null, null, null], zone: 'advance' },
  { rank: 1, team: 'Nigma', matches: '0 - 0', games: '0 - 0', rounds: ['IronWing', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'BoomBoys', matches: '0 - 0', games: '0 - 0', rounds: ['OG', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'OG', matches: '0 - 0', games: '0 - 0', rounds: ['BoomBoys', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Vision', matches: '0 - 0', games: '0 - 0', rounds: ['Resilience', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Resilience', matches: '0 - 0', games: '0 - 0', rounds: ['Vision', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Spirit', matches: '0 - 0', games: '0 - 0', rounds: ['XG', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'XG', matches: '0 - 0', games: '0 - 0', rounds: ['Spirit', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Liquid', matches: '0 - 0', games: '0 - 0', rounds: ['Vici', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Vici', matches: '0 - 0', games: '0 - 0', rounds: ['Liquid', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'Aurora', matches: '0 - 0', games: '0 - 0', rounds: ['GamerLegion', null, null, null, null], zone: 'active' },
  { rank: 1, team: 'GamerLegion', matches: '0 - 0', games: '0 - 0', rounds: ['Aurora', null, null, null, null], zone: 'eliminated' },
  { rank: 1, team: 'Yandex', matches: '0 - 0', games: '0 - 0', rounds: ['Huligani', null, null, null, null], zone: 'eliminated' },
  { rank: 1, team: 'Huligani', matches: '0 - 0', games: '0 - 0', rounds: ['Yandex', null, null, null, null], zone: 'eliminated' },
]

const matches = ref([
  { id: 1, time: '8月13日 10:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Falcons', b: 'LGD', score: '—', status: 'upcoming' },
  { id: 2, time: '8月13日 10:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'IronWing', b: 'Nigma', score: '—', status: 'upcoming' },
  { id: 3, time: '8月13日 10:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'BoomBoys', b: 'OG', score: '—', status: 'upcoming' },
  { id: 4, time: '8月13日 10:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Vision', b: 'Resilience', score: '—', status: 'upcoming' },
  { id: 5, time: '8月13日 13:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Spirit', b: 'XG', score: '—', status: 'upcoming' },
  { id: 6, time: '8月13日 13:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Liquid', b: 'Vici', score: '—', status: 'upcoming' },
  { id: 7, time: '8月13日 13:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Aurora', b: 'GamerLegion', score: '—', status: 'upcoming' },
  { id: 8, time: '8月13日 13:00', group: '瑞士轮 · 第1轮', bestOf: 'BO3', a: 'Yandex', b: 'Huligani', score: '—', status: 'upcoming' },
])

const eliminationMatches = [
  { id: 'e1', time: '8月20日 10:00', group: '晋级附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e2', time: '8月20日 13:00', group: '晋级附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e3', time: '8月20日 16:00', group: '晋级附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e4', time: '8月20日 19:00', group: '晋级附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e5', time: '8月20日 22:00', group: '晋级附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
]

const upperBracketRounds = reactive([
  {
    title: '胜者组四分之一决赛', date: '8月22日', column: 1,
    games: [
      { id: 'u1', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'u2', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'u4', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'u7', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '胜者组半决赛', date: '8月24日', column: 2, longConnector: true,
    games: [
      { id: 'u3', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'u5', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '胜者组决赛', date: '8月27日', column: 4,
    games: [
      { id: 'u6', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '总决赛', date: '8月30日', column: 5, final: true,
    games: [
      { id: 'final', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
])

const lowerBracketRounds = reactive([
  {
    title: '败者组第一轮', date: '8月23日', column: 1,
    games: [
      { id: 'l1', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'l2', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '败者组四分之一决赛', date: '8月25日', column: 2,
    games: [
      { id: 'l3', a: null, b: null, aScore: null, bScore: null, winner: null },
      { id: 'l4', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '败者组半决赛', date: '8月26日', column: 3,
    games: [
      { id: 'l5', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
  {
    title: '败者组决赛', date: '8月28日', column: 4,
    games: [
      { id: 'l6', a: null, b: null, aScore: null, bScore: null, winner: null },
    ],
  },
])

const allMatchKeys = [...new Set([
  ...matches.value.map(match => String(match.id)),
  ...eliminationMatches.map(match => String(match.id)),
  ...upperBracketRounds.flatMap(round => round.games.map(game => String(game.id))),
  ...lowerBracketRounds.flatMap(round => round.games.map(game => String(game.id))),
])]
const totalMatchCount = allMatchKeys.length

const localVoteSeed = {
  1: { Falcons: 1284, LGD: 947 },
  2: { IronWing: 638, Nigma: 1126 },
  3: { BoomBoys: 714, OG: 1538 },
  4: { Vision: 423, Resilience: 366 },
  5: { Spirit: 1864, XG: 1517 },
  6: { Liquid: 1742, Vici: 893 },
  7: { Aurora: 984, GamerLegion: 612 },
  8: { Yandex: 1320, Huligani: 578 },
  e1: { Nigma: 826, GamerLegion: 514 },
  e2: { OG: 1038, Vici: 672 },
  e3: { Vision: 619, BoomBoys: 581 },
  e4: { Liquid: 1246, Resilience: 438 },
  e5: { Yandex: 911, Huligani: 557 },
  u1: { Falcons: 1087, Aurora: 593 },
  u2: { Spirit: 1412, OG: 728 },
  u3: { Falcons: 978, Spirit: 1124 },
  u4: { Liquid: 1055, XG: 884 },
  u5: { Liquid: 912, LGD: 701 },
  u6: { Falcons: 1088, Liquid: 973 },
  u7: { LGD: 836, Yandex: 794 },
  l1: { Nigma: 764, GamerLegion: 442 },
  l2: { Vici: 591, BoomBoys: 537 },
  l3: { LGD: 781, Nigma: 728 },
  l4: { Yandex: 806, Vici: 633 },
  l5: { Nigma: 712, Yandex: 759 },
  l6: { Yandex: 834, Spirit: 1026 },
  final: { Falcons: 1372, Yandex: 916 },
}

function loadPredictions() {
  try {
    return JSON.parse(localStorage.getItem('ti2026-predictions-v2')) || { 1: 'Falcons', 5: 'Spirit' }
  } catch {
    return { 1: 'Falcons', 5: 'Spirit' }
  }
}

function loadVoteTotals() {
  try {
    return JSON.parse(localStorage.getItem('ti2026-vote-totals-v2')) || localVoteSeed
  } catch {
    return localVoteSeed
  }
}

function allBracketGames() {
  return [
    ...upperBracketRounds.flatMap(round => round.games),
    ...lowerBracketRounds.flatMap(round => round.games),
  ]
}

const manualBracketGameIds = new Set(['u1', 'u2', 'u4', 'u7'])
const bracketFlow = {
  u1: { winner: ['u3', 'a'], loser: ['l1', 'a'] },
  u2: { winner: ['u3', 'b'], loser: ['l1', 'b'] },
  u4: { winner: ['u5', 'a'], loser: ['l2', 'a'] },
  u7: { winner: ['u5', 'b'], loser: ['l2', 'b'] },
  u3: { winner: ['u6', 'a'], loser: ['l3', 'b'] },
  u5: { winner: ['u6', 'b'], loser: ['l4', 'b'] },
  l1: { winner: ['l3', 'a'] },
  l2: { winner: ['l4', 'a'] },
  l3: { winner: ['l5', 'a'] },
  l4: { winner: ['l5', 'b'] },
  u6: { winner: ['final', 'a'], loser: ['l6', 'b'] },
  l5: { winner: ['l6', 'a'] },
  l6: { winner: ['final', 'b'] },
  final: {},
}
const bracketFlowOrder = ['u1', 'u2', 'u4', 'u7', 'u3', 'u5', 'l1', 'l2', 'l3', 'l4', 'u6', 'l5', 'l6', 'final']

function bracketGameById(id) {
  return allBracketGames().find(game => String(game.id) === String(id))
}

function isManualBracketSlot(game) {
  return manualBracketGameIds.has(String(game.id))
}

function bracketSlotLabel(game, side) {
  return game[side]
    ? (teamMeta[game[side]]?.name || game[side])
    : (isManualBracketSlot(game) ? '待定' : '等待上轮')
}

function bracketSlotStatus(game, side) {
  if (!game[side]) return '—'
  return game.winner === game[side] ? '胜者' : '选择'
}

function assignBracketTarget(target, teamId) {
  if (!target) return
  const targetGame = bracketGameById(target[0])
  if (targetGame) targetGame[target[1]] = teamId
}

function rebuildEntertainmentBracket() {
  const games = allBracketGames()
  const winnerSelections = new Map(games.map(game => [String(game.id), game.winner]))

  games.forEach(game => {
    if (!manualBracketGameIds.has(String(game.id))) {
      game.a = null
      game.b = null
    }
    game.winner = null
  })

  bracketFlowOrder.forEach(gameId => {
    const game = bracketGameById(gameId)
    const selectedWinner = winnerSelections.get(gameId)
    if (!game?.a || !game?.b || ![game.a, game.b].includes(selectedWinner)) return

    game.winner = selectedWinner
    const loser = selectedWinner === game.a ? game.b : game.a
    assignBracketTarget(bracketFlow[gameId]?.winner, selectedWinner)
    assignBracketTarget(bracketFlow[gameId]?.loser, loser)
  })
}

function sanitizeBracketPredictions(items) {
  const entertainmentMatchIds = new Set(allBracketGames().map(game => String(game.id)))
  return Object.fromEntries(Object.entries(items).filter(([id]) => !entertainmentMatchIds.has(String(id))))
}

const predictions = ref(sanitizeBracketPredictions(loadPredictions()))
const voteTotals = ref(loadVoteTotals())
const bracketPicker = ref(null)
const availableTeamOptions = computed(() => {
  const usedTeams = new Set(allBracketGames()
    .filter(game => manualBracketGameIds.has(String(game.id)))
    .flatMap(game => [game.a, game.b])
    .filter(Boolean))
  return Object.entries(teamMeta)
    .filter(([teamId]) => !usedTeams.has(teamId))
    .map(([id, meta]) => ({ id, meta }))
})
const entertainmentChampion = computed(() => {
  const championId = bracketGameById('final')?.winner
  return championId ? teamMeta[championId]?.name || championId : '待定'
})

const predictionCount = computed(() => Object.keys(predictions.value).length)
const allMatchRecords = [
  ...matches.value,
  ...eliminationMatches,
]
const resolvedMatchCount = computed(() => allMatchRecords.filter(match => match.winner).length)
const correctPredictionCount = computed(() => allMatchRecords.filter(match => (
  match.winner && predictions.value[String(match.id)] === match.winner
)).length)
const predictionAccuracy = computed(() => (
  resolvedMatchCount.value ? `${Math.round(correctPredictionCount.value / resolvedMatchCount.value * 100)}%` : '—'
))
const dataModeLabel = computed(() => ({
  connecting: '连接云端',
  online: '云端统计',
  demo: '本地演示',
  error: '本地降级',
})[dataMode.value])
const nicknameInitial = computed(() => nickname.value.trim().slice(0, 1).toUpperCase() || 'P')
const profileHero = computed(() => heroes.find(hero => hero.id === profileHeroId.value) || null)

function persistCurrentProfile() {
  saveLocalProfile({
    nickname: nickname.value,
    heroId: profileHeroId.value,
  })
}

watch(predictions, value => {
  localStorage.setItem('ti2026-predictions-v2', JSON.stringify(value))
}, { deep: true })

watch(voteTotals, value => {
  if (!cloudActive.value) localStorage.setItem('ti2026-vote-totals-v2', JSON.stringify(value))
}, { deep: true })

function selectView(id) {
  const path = viewPaths[id] || '/'
  if (window.location.hash !== `#${path}`) {
    window.location.hash = path
  } else {
    activeView.value = id
  }
  mobileMenu.value = false
}

function syncViewFromHash() {
  activeView.value = viewFromHash()
  mobileMenu.value = false
}

function showToast(message) {
  toast.value = message
  window.clearTimeout(showToast.timer)
  showToast.timer = window.setTimeout(() => (toast.value = ''), 2200)
}

function openProfileEditor() {
  nicknameDraft.value = nickname.value
  nicknameError.value = ''
  profileOpen.value = true
}

function closeProfileEditor() {
  if (nicknameSaving.value) return
  profileOpen.value = false
  nicknameError.value = ''
}

async function saveNickname() {
  const nextNickname = nicknameDraft.value.trim()
  if (nextNickname.length < 2 || nextNickname.length > 20) {
    nicknameError.value = '昵称长度需要在 2–20 个字符之间'
    return
  }

  nicknameSaving.value = true
  nicknameError.value = ''
  try {
    nickname.value = cloudActive.value ? await updateCloudNickname(nextNickname) : nextNickname
    persistCurrentProfile()
    profileOpen.value = false
    showToast(`昵称已更新为 ${nickname.value}`)
  } catch (error) {
    nicknameError.value = error.message || '昵称保存失败，请稍后重试'
  } finally {
    nicknameSaving.value = false
  }
}

function votesFor(id, teamId) {
  return Number(voteTotals.value[String(id)]?.[teamId] || 0)
}

function totalFor(id) {
  return Object.values(voteTotals.value[String(id)] || {}).reduce((sum, count) => sum + Number(count), 0)
}

function percentFor(id, teamId) {
  const total = totalFor(id)
  return total ? Math.round(votesFor(id, teamId) / total * 100) : 0
}

function applyVoteDelta(id, previousTeam, nextTeam) {
  const key = String(id)
  const totals = { ...(voteTotals.value[key] || {}) }
  if (previousTeam && previousTeam !== nextTeam) {
    totals[previousTeam] = Math.max(0, Number(totals[previousTeam] || 0) - 1)
  }
  if (previousTeam !== nextTeam) totals[nextTeam] = Number(totals[nextTeam] || 0) + 1
  voteTotals.value = { ...voteTotals.value, [key]: totals }
}

async function pick(id, team) {
  if (!team || team === '待定') return
  const key = String(id)
  if (submittingMatch.value === key || predictions.value[key] === team) return

  const previousTeam = predictions.value[key]
  const previousPredictions = { ...predictions.value }
  const previousTotals = JSON.parse(JSON.stringify(voteTotals.value))
  predictions.value = { ...predictions.value, [key]: team }
  applyVoteDelta(key, previousTeam, team)

  if (!cloudActive.value) {
    showToast(`已在本地选择 ${teamMeta[team]?.name || team}`)
    return
  }

  submittingMatch.value = key
  try {
    voteTotals.value = await submitCloudPrediction(key, team, allMatchKeys)
    showToast(`云端预测已更新：${teamMeta[team]?.name || team}`)
  } catch (error) {
    predictions.value = previousPredictions
    voteTotals.value = previousTotals
    showToast(error.message?.includes('locked') ? '该场比赛已经停止预测' : '提交失败，请稍后重试')
  } finally {
    submittingMatch.value = null
  }
}

function openBracketSlot(game, side) {
  if (game[side]) {
    if (!game.a || !game.b) {
      showToast('等待另一支队伍进入该轮')
      return
    }
    game.winner = game[side]
    rebuildEntertainmentBracket()
    showToast(`${teamMeta[game[side]]?.name || game[side]} 晋级`)
    return
  }
  if (!isManualBracketSlot(game)) {
    showToast('等待上轮结果自动填充')
    return
  }
  bracketPicker.value = { gameId: String(game.id), side }
}

function chooseBracketTeam(teamId) {
  if (!bracketPicker.value || !teamMeta[teamId]) return
  if (!availableTeamOptions.value.some(option => option.id === teamId)) return
  const game = allBracketGames().find(item => String(item.id) === bracketPicker.value.gameId)
  if (!game || game[bracketPicker.value.side]) return
  game[bracketPicker.value.side] = teamId
  rebuildEntertainmentBracket()
  bracketPicker.value = null
  showToast(`已设置 ${teamMeta[teamId].name}`)
}

function clearBracketSlot(game, side) {
  if (!isManualBracketSlot(game) || !game[side]) return
  game[side] = null
  rebuildEntertainmentBracket()
  showToast('已移除该队伍')
}

function closeBracketPicker() {
  bracketPicker.value = null
}

function team(id) {
  return teamMeta[id] || { name: id, short: '?', color: '#6d6d74' }
}

onMounted(async () => {
  window.addEventListener('hashchange', syncViewFromHash)
  if (!isSupabaseConfigured) return

  try {
    const result = await initializePredictionStore(allMatchKeys)
    predictions.value = sanitizeBracketPredictions(result.predictions)
    voteTotals.value = result.totals
    if (result.nickname) {
      nickname.value = legacyNicknamePattern.test(result.nickname)
        ? await updateCloudNickname(nickname.value)
        : result.nickname
      const nicknameHero = heroes.find(hero => nickname.value.endsWith(`-${hero.nameLoc}`))
      if (nicknameHero) profileHeroId.value = nicknameHero.id
      heroImageFailed.value = false
      persistCurrentProfile()
    }
    cloudActive.value = true
    dataMode.value = 'online'
  } catch (error) {
    console.error('Supabase prediction initialization failed:', error)
    dataMode.value = 'error'
    showToast('云端连接失败，已切换到本地模式')
  }
})

onUnmounted(() => window.removeEventListener('hashchange', syncViewFromHash))
</script>

<template>
  <div class="app-shell">
    <div class="ambient ambient-one"></div>
    <div class="ambient ambient-two"></div>

    <aside class="sidebar" :class="{ open: mobileMenu }">
      <div class="brand">
        <img src="https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/ti2026_logo.png" alt="TI 2026 官方徽标" />
        <div><strong>THE INTERNATIONAL</strong><span>2026 PREDICTOR</span></div>
      </div>
      <button class="close-menu" aria-label="关闭菜单" @click="mobileMenu = false"><X :size="20" /></button>

      <nav>
        <button v-for="item in navItems" :key="item.id" :class="{ active: activeView === item.id }" @click="selectView(item.id)">
          <component :is="item.icon" :size="18" />
          <span>{{ item.label }}</span>
          <span v-if="item.id === 'my-picks'" class="count">{{ predictionCount }}</span>
        </button>
      </nav>

      <div class="side-footer"><span class="live-dot"></span> 官方赛程 · 预测模拟</div>
    </aside>

    <div v-if="mobileMenu" class="menu-scrim" @click="mobileMenu = false"></div>

    <main>
      <header class="topbar">
        <button class="menu-button" aria-label="打开菜单" @click="mobileMenu = true"><Menu :size="21" /></button>
        <div class="crumb"><span>TI 2026</span><ArrowRight :size="14" /><strong>{{ navItems.find(n => n.id === activeView)?.label }}</strong></div>
        <div class="top-actions">
          <span class="cloud-pill" :class="dataMode"><Database :size="13" /> {{ dataModeLabel }}</span>
          <span class="live-pill"><span class="live-dot"></span> 8月13日开赛</span>
          <button class="profile-button" title="修改昵称" @click="openProfileEditor">
            <span class="profile-avatar">
              <img v-if="profileHero && !heroImageFailed" :src="profileHero.image" :alt="profileHero.nameLoc" referrerpolicy="no-referrer" @error="heroImageFailed = true" />
              <span v-else>{{ nicknameInitial }}</span>
            </span>
            <span class="profile-name">{{ nickname }}</span>
            <Pencil :size="14" />
          </button>
        </div>
      </header>

      <div class="content">
        <template v-if="activeView === 'overview'">
          <section class="hero-band">
            <div class="hero-copy">
              <div class="eyebrow"><Sparkles :size="15" /> THE ROAD TO THE AEGIS</div>
              <h1>谁将举起<br /><em>不朽盾？</em></h1>
              <p>预测 16 支顶尖战队的每一场较量，见证 2026 年王者诞生。</p>
              <button class="primary" @click="selectView('groups')">开始预测 <ArrowRight :size="17" /></button>
            </div>
            <div class="hero-visual" aria-hidden="true">
              <div class="aegis-ring ring-outer"></div>
              <div class="aegis-ring ring-inner"></div>
              <img src="https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/ti2026_logo.png" alt="" />
              <span class="rune rune-a">ᛏ</span><span class="rune rune-b">ᛉ</span><span class="rune rune-c">ᛋ</span>
            </div>
            <div class="hero-stats">
              <div><span>已完成预测</span><strong>{{ predictionCount }}<small>/ {{ totalMatchCount }}</small></strong><em>正确率 {{ predictionAccuracy }}</em></div>
            </div>
          </section>

        </template>

        <template v-else-if="activeView === 'groups'">
          <section class="page-title"><div><span class="section-kicker">SWISS STAGE · FIVE ROUNDS</span><h1>小组赛程</h1><p>瑞士轮共进行五轮，所有比赛均为 BO3；点击队伍即可提交胜负预测。</p></div><div class="stage-badge"><CalendarDays :size="22" /><span>{{ activeSwissRound === 1 ? '比赛日' : '赛程状态' }}<strong>{{ activeSwissRound === 1 ? '8月13日' : '待公布' }}</strong></span></div></section>
          <div class="round-tabs" role="tablist" aria-label="瑞士轮赛程轮次">
            <button v-for="round in swissRounds" :key="round" role="tab" :aria-selected="activeSwissRound === round" :class="{ active: activeSwissRound === round }" @click="activeSwissRound = round">
              <span>第 {{ round }} 轮</span><small>{{ round === 1 ? '8月13日' : '待公布' }}</small>
            </button>
          </div>
          <section class="section-heading schedule-heading"><div><span class="section-kicker">ROUND {{ activeSwissRound }} · BEIJING TIME</span><h2>第 {{ activeSwissRound }} 轮赛程</h2></div><span class="muted">{{ activeSwissRound === 1 ? `共 ${matches.length} 场` : '对阵待公布' }} · BO3</span></section>
          <div v-if="activeSwissRound === 1" class="match-grid schedule-match-grid">
            <article v-for="match in matches" :key="match.id" class="match-card">
              <div class="match-meta"><span><Clock3 :size="13" /> {{ match.time }}</span><span>{{ match.group }} · {{ match.bestOf }}</span></div>
              <div class="match-versus">
                <button :class="['team-pick', { selected: predictions[match.id] === match.a }]" :disabled="submittingMatch === String(match.id)" @click="pick(match.id, match.a)">
                  <TeamLogo :meta="team(match.a)" />
                  <strong>{{ team(match.a).name }}</strong><small>{{ predictions[match.id] === match.a ? '你的选择' : '选择胜者' }}</small>
                </button>
                <div class="vs"><span>VS</span><small>{{ match.bestOf }}</small></div>
                <button :class="['team-pick', { selected: predictions[match.id] === match.b }]" :disabled="submittingMatch === String(match.id)" @click="pick(match.id, match.b)">
                  <TeamLogo :meta="team(match.b)" />
                  <strong>{{ team(match.b).name }}</strong><small>{{ predictions[match.id] === match.b ? '你的选择' : '选择胜者' }}</small>
                </button>
              </div>
              <div class="vote-summary">
                <div class="vote-numbers"><span>{{ percentFor(match.id, match.a) }}% · {{ votesFor(match.id, match.a) }}票</span><small>{{ totalFor(match.id) }} 人已预测</small><span>{{ votesFor(match.id, match.b) }}票 · {{ percentFor(match.id, match.b) }}%</span></div>
                <div class="vote-bar"><i :style="{ width: percentFor(match.id, match.a) + '%' }"></i><b :style="{ width: percentFor(match.id, match.b) + '%' }"></b></div>
              </div>
            </article>
          </div>
          <section v-else class="round-empty-state">
            <span class="round-empty-icon"><CalendarDays :size="30" /></span>
            <div><span class="section-kicker">ROUND {{ activeSwissRound }}</span><h2>第 {{ activeSwissRound }} 轮对阵待公布</h2><p>上一轮结束后，将根据各队当前战绩生成本轮对阵。</p></div>
          </section>
        </template>

        <template v-else-if="activeView === 'standings'">
          <section class="page-title"><div><span class="section-kicker">SWISS STAGE · FIVE ROUNDS</span><h1>小组赛排名</h1><p>16 支战队进行最多五轮 BO3，4 胜直接晋级，4 负淘汰；3-2 与 2-3 进入晋级附加赛。</p></div><div class="stage-badge"><ListOrdered :size="22" /><span>晋级规则<strong>4 胜直接晋级</strong></span></div></section>
          <section class="swiss-section">
            <div class="swiss-section-head"><div><span class="section-kicker">CURRENT STANDINGS</span><h2>小组赛对阵与排名</h2></div><span class="status-note"><span class="live-dot"></span> 第 1 轮待开始</span></div>
            <div class="swiss-table-scroll">
              <div class="swiss-table">
                <div class="swiss-row swiss-head"><span>#</span><span>参赛队伍</span><span>比赛</span><span>局分</span><span>第 1 轮</span><span>第 2 轮</span><span>第 3 轮</span><span>第 4 轮</span><span>第 5 轮</span></div>
                <div v-for="row in swissStandings" :key="row.team" class="swiss-row" :class="`zone-${row.zone}`">
                  <span class="swiss-rank">{{ row.rank }}</span>
                  <span class="swiss-team"><TeamLogo :meta="team(row.team)" compact /><strong>{{ team(row.team).name }}</strong></span>
                  <strong class="swiss-record">{{ row.matches }}</strong>
                  <span class="swiss-record">{{ row.games }}</span>
                  <span v-for="(opponent, roundIndex) in row.rounds" :key="roundIndex" class="swiss-round-cell" :title="opponent ? `第 ${roundIndex + 1} 轮对阵 ${team(opponent).name}` : `第 ${roundIndex + 1} 轮待定`">
                    <TeamLogo v-if="opponent" :meta="team(opponent)" compact />
                    <i v-else></i>
                  </span>
                </div>
              </div>
            </div>
          </section>
          <div class="standings-legend"><span><i class="legend-mark advance"></i> 4 胜直接晋级</span><span><i class="legend-mark active"></i> 3-2 / 2-3 进入晋级附加赛</span><span><i class="legend-mark eliminated"></i> 4 负淘汰</span><span><i class="legend-line"></i> 当前为首轮初始数据</span></div>
        </template>

        <template v-else-if="activeView === 'elimination'">
          <section class="page-title"><div><span class="section-kicker">晋级附加赛 · 最后机会</span><h1>晋级附加赛</h1><p>小组赛五轮结束后，3-2 战绩队伍与 2-3 战绩队伍进行 5 场 BO3，胜者晋级淘汰赛。</p></div><div class="stage-badge gold"><Shield :size="22" /><span>晋级名额<strong>5 场生死战</strong></span></div></section>
          <section class="section-heading elimination-heading"><div><span class="section-kicker">5 MATCHES · BO3</span><h2>晋级淘汰赛之战</h2></div><span class="muted">小组赛结束后进行</span></section>
          <div class="match-grid elimination-match-grid">
            <article v-for="match in eliminationMatches" :key="match.id" class="match-card">
              <div class="match-meta"><span><Clock3 :size="13" /> {{ match.time }}</span><span>{{ match.recordA }} vs {{ match.recordB }} · {{ match.bestOf }}</span></div>
              <div class="match-versus">
                <div class="team-pick pending"><span class="pending-team-icon">?</span><strong>待定</strong><small>小组赛结束后确定</small></div>
                <div class="vs"><span>VS</span><small>{{ match.bestOf }}</small></div>
                <div class="team-pick pending"><span class="pending-team-icon">?</span><strong>待定</strong><small>小组赛结束后确定</small></div>
              </div>
              <div class="match-pending-note">对阵将在小组赛结束后公布</div>
            </article>
          </div>
        </template>

        <template v-else-if="activeView === 'playoffs'">
          <section class="page-title"><div><span class="section-kicker">MAIN EVENT · COLOGNE</span><h1>淘汰赛对阵</h1><p>点击首轮待定格选择队伍，再点击队伍选择胜者，晋级路径会自动填充；正式对阵将在小组赛结束后更新。</p></div><div class="stage-badge gold"><Trophy :size="22" /><span>娱乐模拟冠军<strong>{{ entertainmentChampion }}</strong></span></div></section>
          <div class="complete-bracket-meta"><span><CalendarDays :size="16" /> 8月22日—8月30日</span><span>胜者组与败者组完整对阵</span></div>
          <section class="complete-bracket-wrap">
            <div class="complete-bracket-grid">
              <div class="bracket-lane upper-lane" aria-label="胜者组对阵">
                <div v-for="round in upperBracketRounds" :key="round.title" class="complete-round" :class="{ final: round.final, 'long-connector': round.longConnector }" :style="{ gridColumn: round.column }">
                  <div class="complete-round-title"><strong>{{ round.title }}</strong><span>{{ round.date }}</span></div>
                  <div class="complete-round-games">
                    <article v-for="game in round.games" :key="game.id" class="bracket-game">
                      <button :class="{ selected: game.winner === game.a, pending: !game.a, locked: !game.a && !isManualBracketSlot(game) }" @click="openBracketSlot(game, 'a')">
                        <TeamLogo v-if="game.a" :meta="team(game.a)" compact /><span v-else class="pending-team-icon">?</span><strong>{{ bracketSlotLabel(game, 'a') }}</strong><em>{{ bracketSlotStatus(game, 'a') }}</em><span v-if="game.a && isManualBracketSlot(game)" class="bracket-clear" role="button" tabindex="0" aria-label="移除队伍" @click.stop="clearBracketSlot(game, 'a')" @keydown.enter.stop="clearBracketSlot(game, 'a')"><X :size="13" /></span>
                      </button>
                      <button :class="{ selected: game.winner === game.b, pending: !game.b, locked: !game.b && !isManualBracketSlot(game) }" @click="openBracketSlot(game, 'b')">
                        <TeamLogo v-if="game.b" :meta="team(game.b)" compact /><span v-else class="pending-team-icon">?</span><strong>{{ bracketSlotLabel(game, 'b') }}</strong><em>{{ bracketSlotStatus(game, 'b') }}</em><span v-if="game.b && isManualBracketSlot(game)" class="bracket-clear" role="button" tabindex="0" aria-label="移除队伍" @click.stop="clearBracketSlot(game, 'b')" @keydown.enter.stop="clearBracketSlot(game, 'b')"><X :size="13" /></span>
                      </button>
                      <span v-if="!round.final" class="complete-connector"></span>
                    </article>
                  </div>
                </div>
              </div>
              <div class="bracket-lane lower-lane" aria-label="败者组对阵">
                <div v-for="round in lowerBracketRounds" :key="round.title" class="complete-round" :style="{ gridColumn: round.column }">
                  <div class="complete-round-title"><strong>{{ round.title }}</strong><span>{{ round.date }}</span></div>
                  <div class="complete-round-games">
                    <article v-for="game in round.games" :key="game.id" class="bracket-game">
                      <button :class="{ selected: game.winner === game.a, pending: !game.a, locked: !game.a && !isManualBracketSlot(game) }" @click="openBracketSlot(game, 'a')">
                        <TeamLogo v-if="game.a" :meta="team(game.a)" compact /><span v-else class="pending-team-icon">?</span><strong>{{ bracketSlotLabel(game, 'a') }}</strong><em>{{ bracketSlotStatus(game, 'a') }}</em><span v-if="game.a && isManualBracketSlot(game)" class="bracket-clear" role="button" tabindex="0" aria-label="移除队伍" @click.stop="clearBracketSlot(game, 'a')" @keydown.enter.stop="clearBracketSlot(game, 'a')"><X :size="13" /></span>
                      </button>
                      <button :class="{ selected: game.winner === game.b, pending: !game.b, locked: !game.b && !isManualBracketSlot(game) }" @click="openBracketSlot(game, 'b')">
                        <TeamLogo v-if="game.b" :meta="team(game.b)" compact /><span v-else class="pending-team-icon">?</span><strong>{{ bracketSlotLabel(game, 'b') }}</strong><em>{{ bracketSlotStatus(game, 'b') }}</em><span v-if="game.b && isManualBracketSlot(game)" class="bracket-clear" role="button" tabindex="0" aria-label="移除队伍" @click.stop="clearBracketSlot(game, 'b')" @keydown.enter.stop="clearBracketSlot(game, 'b')"><X :size="13" /></span>
                      </button>
                      <span class="complete-connector"></span>
                    </article>
                  </div>
                </div>
              </div>
            </div>
          </section>
          <div class="bracket-note"><Shield :size="18" /><span>当前淘汰赛路径仅供娱乐，不保存、不参与预测统计；胜者进入下一轮，败者进入败者组，小组赛结束后将更新正式对阵。</span></div>
        </template>

        <template v-else>
          <section class="page-title"><div><span class="section-kicker">MY PREDICTIONS</span><h1>我的预测</h1><p>已完成 {{ predictionCount }} 项预测，继续完善你的 TI 2026 晋级图。</p></div><div class="stage-badge"><Target :size="22" /><span>预测完成度<strong>{{ Math.round(predictionCount / totalMatchCount * 100) }}%</strong></span></div></section>
          <div v-if="predictionCount" class="picks-grid">
            <article v-for="(chosen, id) in predictions" :key="id" class="pick-summary">
              <TeamLogo :meta="team(chosen)" compact />
              <div><small>对局 #{{ id }} · {{ votesFor(id, chosen) }}票 · {{ percentFor(id, chosen) }}%</small><strong>{{ team(chosen).name }}</strong></div>
              <Medal :size="20" />
            </article>
          </div>
          <div class="empty-panel"><img src="https://cdn.steamstatic.com/apps/dota2/images/dota_react/international2026/ti2026_logo.png" alt="TI 2026 官方徽标" /><div><h2>构筑你的冠军之路</h2><p>前往小组赛和淘汰赛页面，选择你看好的战队。</p><button class="primary" @click="selectView('playoffs')">继续预测 <ArrowRight :size="17" /></button></div></div>
        </template>
      </div>
      <Transition name="modal">
        <div v-if="bracketPicker" class="bracket-picker-scrim" @click.self="closeBracketPicker">
          <section class="bracket-picker" role="dialog" aria-modal="true" aria-labelledby="bracket-picker-title">
            <header>
              <div><span class="section-kicker">TEAM SLOT</span><h2 id="bracket-picker-title">选择参赛队伍</h2></div>
              <button aria-label="关闭队伍选择" @click="closeBracketPicker"><X :size="20" /></button>
            </header>
            <div class="bracket-team-options">
              <button v-for="option in availableTeamOptions" :key="option.id" @click="chooseBracketTeam(option.id)">
                <TeamLogo :meta="option.meta" compact /><span>{{ option.meta.name }}</span>
              </button>
              <p v-if="!availableTeamOptions.length" class="bracket-picker-empty">所有队伍都已分配到格子中</p>
            </div>
          </section>
        </div>
      </Transition>
      <footer class="site-footer">
        <p>本站由 <a href="https://01stu.com/" target="_blank" rel="noopener noreferrer">01工作室</a> 制作开发； 本站由 <a href="https://1zhongzhuan.com" target="_blank" rel="noopener noreferrer">壹中转</a> 提供 AI GPT Token 支持</p>
      </footer>
    </main>

    <Transition name="modal">
      <div v-if="profileOpen" class="profile-scrim" @click.self="closeProfileEditor">
        <section class="profile-dialog" role="dialog" aria-modal="true" aria-labelledby="nickname-title">
          <header>
            <div class="profile-dialog-icon"><UserRound :size="25" /></div>
            <div><span>PLAYER PROFILE</span><h2 id="nickname-title">修改昵称</h2></div>
            <button aria-label="关闭昵称设置" @click="closeProfileEditor"><X :size="21" /></button>
          </header>
          <label for="nickname-input">昵称</label>
          <input id="nickname-input" v-model="nicknameDraft" maxlength="20" autocomplete="off" autofocus @keyup.enter="saveNickname" />
          <div class="profile-field-meta"><span :class="{ error: nicknameError }">{{ nicknameError || '2–20 个字符' }}</span><span>{{ nicknameDraft.trim().length }}/20</span></div>
          <footer>
            <button class="secondary-action" :disabled="nicknameSaving" @click="closeProfileEditor">取消</button>
            <button class="primary save-profile" :disabled="nicknameSaving" @click="saveNickname">{{ nicknameSaving ? '保存中…' : '保存昵称' }}</button>
          </footer>
        </section>
      </div>
    </Transition>
    <Transition name="toast"><div v-if="toast" class="toast"><span>✓</span>{{ toast }}</div></Transition>
  </div>
</template>
