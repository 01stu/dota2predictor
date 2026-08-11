<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import {
  ArrowRight, CalendarDays, CheckCircle2, ChevronDown, Clock3, Database,
  GitBranch, LayoutDashboard, ListOrdered, Menu, Pencil, Radio, RotateCcw, Shield, Sparkles, Swords,
  Target, Trophy, UserRound, Users, X, XCircle
} from 'lucide-vue-next'
import TeamLogo from './components/TeamLogo.vue'
import { heroes } from './data/heroes'
import { playerIds } from './data/playerIds'
import { buildSwissSimulation } from './services/swissSimulation'
import {
  getCloudAdvancementPrediction,
  getCloudSwissPrediction,
  initializePredictionStore,
  isSupabaseConfigured,
  submitCloudAdvancementPrediction,
  submitCloudPrediction,
  submitCloudSwissPrediction,
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
  advancement: '/advancement-prediction',
  playoffs: '/playoffs',
  'my-picks': '/my-predictions',
}
const pathViews = Object.fromEntries(Object.entries(viewPaths).map(([view, path]) => [path, view]))
pathViews['/elimination-round'] = 'groups'

function viewFromHash() {
  const path = window.location.hash.replace(/^#/, '').split('?')[0] || '/'
  return pathViews[path] || 'overview'
}

const activeView = ref(viewFromHash())
const activeSwissRound = ref(window.location.hash.replace(/^#/, '').split('?')[0] === '/elimination-round' ? 'playin' : 1)
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
  { id: 'standings', label: '小组排名', icon: ListOrdered },
  { id: 'groups', label: '小组赛程', icon: Users },
  { id: 'advancement', label: '晋级预测', icon: GitBranch },
  { id: 'playoffs', label: '淘汰赛对阵', icon: Swords },
  { id: 'my-picks', label: '我的预测', icon: Target },
]

const swissRounds = [1, 2, 3, 4, 5]

const teamMeta = {
  Falcons: { name: 'Team Falcons', short: 'FLC', color: '#e9ca75', logo: '/teamlogos/9247354.png' },
  LGD: { name: 'LGD Gaming', short: 'LGD', color: '#df3d3b', logo: '/teamlogos/10150538.png' },
  IronWing: { name: 'Iron Wing', short: 'IW', color: '#b6b9c1', logo: '/teamlogos/10150413.png' },
  Nigma: { name: 'Nigma Galaxy', short: 'NGX', color: '#6b93dc', logo: '/teamlogos/10136357.png' },
  BoomBoys: { name: 'BOOMBOYS', short: 'BB', color: '#e85b3e', logo: '/teamlogos/8255888.png' },
  OG: { name: 'OG', short: 'OG', color: '#e9e9e9', logo: '/teamlogos/2586976.png' },
  Vision: { name: 'Team Vision', short: 'VIS', color: '#66b3b8', logo: '/teamlogos/9572001.png' },
  Resilience: { name: 'Team Resilience', short: 'RES', color: '#d8a96d', logo: '/teamlogos/5017210.png' },
  Spirit: { name: 'Team Spirit', short: 'TS', color: '#f0c75d', logo: '/teamlogos/7119388.png' },
  XG: { name: 'Xtreme Gaming', short: 'XG', color: '#e15d58', logo: '/teamlogos/8261500.png' },
  Liquid: { name: 'Team Liquid', short: 'TL', color: '#67a9e6', logo: '/teamlogos/2163.png' },
  Vici: { name: 'Vici Gaming', short: 'VG', color: '#e67b76', logo: '/teamlogos/726228.png' },
  Aurora: { name: 'Aurora Gaming', short: 'AUR', color: '#ad78df', logo: '/teamlogos/9467224.png' },
  GamerLegion: { name: 'GamerLegion', short: 'GL', color: '#df3d39', logo: '/teamlogos/9964962.png' },
  Yandex: { name: 'Team Yandex', short: 'YAN', color: '#e6d65e', logo: '/teamlogos/9823272.png' },
  Huligani: { name: 'HULIGANI', short: 'HUL', color: '#c8c8cd', logo: '/teamlogos/10149530.png' },
}
Object.entries(teamMeta).forEach(([id, meta]) => { meta.id = id })

const heroTeamFloatLayout = [
  [5, 18, 42, -2, 13], [21, 7, 36, 5, 16], [40, 15, 44, 10, 14], [61, 5, 35, -7, 17],
  [82, 16, 46, -10, 15], [96, 38, 34, -5, 18], [78, 40, 39, 8, 13], [22, 37, 38, 6, 17],
  [4, 53, 35, 9, 15], [12, 80, 46, -5, 18], [31, 72, 36, -10, 14], [43, 92, 42, 7, 16],
  [63, 82, 48, 11, 17], [79, 70, 37, -8, 14], [96, 82, 43, -6, 18], [93, 57, 35, 9, 16],
]
const heroTeamRandomLayout = [...heroTeamFloatLayout]
for (let index = heroTeamRandomLayout.length - 1; index > 0; index -= 1) {
  const swapIndex = Math.floor(Math.random() * (index + 1))
  const current = heroTeamRandomLayout[index]
  heroTeamRandomLayout[index] = heroTeamRandomLayout[swapIndex]
  heroTeamRandomLayout[swapIndex] = current
}
const heroFloatingTeams = Object.entries(teamMeta).map(([id, meta], index) => {
  const [baseX, baseY, size, driftX, duration] = heroTeamRandomLayout[index]
  const x = Math.max(3, Math.min(97, baseX + (Math.random() - .5) * 8))
  const y = Math.max(4, Math.min(96, baseY + (Math.random() - .5) * 8))
  return {
    id,
    meta,
    style: {
      '--float-x': `${x}%`,
      '--float-y': `${y}%`,
      '--float-size': `${size}px`,
      '--float-drift-x': `${driftX}px`,
      '--float-duration': `${duration}s`,
      '--float-delay': `${-(index * 1.17).toFixed(2)}s`,
    },
  }
})

const advancementStorageKey = 'ti2026-advancement-prediction-v2'
const advancementDefaultSlots = Array(16).fill(null)

function loadAdvancementPrediction() {
  try {
    const stored = JSON.parse(localStorage.getItem(advancementStorageKey))
    const validTeams = new Set(Object.keys(teamMeta))
    const assignedTeams = Array.isArray(stored) ? stored.filter(Boolean) : []
    if (
      Array.isArray(stored)
      && stored.length === advancementDefaultSlots.length
      && new Set(assignedTeams).size === assignedTeams.length
      && stored.every(teamId => teamId === null || validTeams.has(teamId))
    ) return stored
  } catch {
    // Fall back to empty slots when local data is invalid.
  }
  return [...advancementDefaultSlots]
}

const advancementSlots = ref(loadAdvancementPrediction())
const advancementPicker = ref(null)
const advancementSaving = ref(false)
const advancementSummary = ref(null)
const advancementTeamOptions = Object.entries(teamMeta).map(([id, meta]) => ({ id, meta }))
const advancementAssignedCount = computed(() => advancementSlots.value.filter(Boolean).length)
const advancementResultsPublished = computed(() => Boolean(advancementSummary.value?.resultsPublished))
const advancementResultSlots = computed(() => advancementSummary.value?.resultSlots || [])
const advancementLocked = computed(() => advancementSummary.value && !advancementSummary.value.acceptingPredictions)

function advancementBucket(index) {
  if (index === 0) return '4-0'
  if (index <= 2) return '4-1'
  if (index <= 7) return 'playin-winner'
  if (index <= 12) return 'playin-loser'
  if (index <= 14) return '1-4'
  return '0-4'
}

function advancementCategory(index) {
  if (index === 0) return '4-0 全胜'
  if (index <= 2) return '4-1 晋级'
  if (index <= 7) return '晋级附加赛胜者'
  if (index <= 12) return '晋级附加赛败者'
  if (index <= 14) return '1-4 淘汰'
  return '0-4 全败'
}

function advancementOutcome(index, teamId) {
  if (!advancementResultsPublished.value || !teamId) return null
  const resultIndex = advancementResultSlots.value.indexOf(teamId)
  if (resultIndex < 0) return 'incorrect'
  return advancementBucket(index) === advancementBucket(resultIndex) ? 'correct' : 'incorrect'
}

function advancementOfficialCategory(teamId) {
  const resultIndex = advancementResultSlots.value.indexOf(teamId)
  return resultIndex >= 0 ? advancementCategory(resultIndex) : '未公布'
}

const advancementCloudStatusText = computed(() => {
  if (advancementSaving.value) return '正在保存晋级预测到云端…'
  if (advancementResultsPublished.value) return '官方结果已公布，预测已锁定并完成全站统计。'
  if (advancementLocked.value) return '晋级预测已截止，当前内容不可修改。'
  if (cloudActive.value) return `已自动保存到云端；填满 16 支队伍后计入全站统计，目前完整提交 ${advancementSummary.value?.totalPlayers || 0} 人。`
  return '当前仅保存在本地；连接云端后会自动同步。'
})

function openAdvancementPicker(index) {
  if (advancementSaving.value) return
  if (advancementLocked.value) {
    showToast(advancementResultsPublished.value ? '官方结果已公布，无法再修改' : '晋级预测已经截止')
    return
  }
  advancementPicker.value = index
}

async function persistAdvancementSlots(nextSlots, successMessage) {
  const previousSlots = [...advancementSlots.value]
  advancementSlots.value = nextSlots
  advancementPicker.value = null

  if (!cloudActive.value) {
    showToast(`${successMessage}，已保存在本地`)
    return
  }

  advancementSaving.value = true
  try {
    advancementSummary.value = await submitCloudAdvancementPrediction(nextSlots)
    showToast(`${successMessage}，已保存到云端`)
  } catch (error) {
    advancementSlots.value = previousSlots
    showToast(error.message?.includes('locked') ? '晋级预测已经截止' : '云端保存失败，请稍后重试')
  } finally {
    advancementSaving.value = false
  }
}

async function chooseAdvancementTeam(teamId) {
  if (advancementPicker.value === null || !teamMeta[teamId]) return
  const targetIndex = advancementPicker.value
  const currentTeam = advancementSlots.value[targetIndex]
  const sourceIndex = advancementSlots.value.indexOf(teamId)
  if (sourceIndex === targetIndex) {
    advancementPicker.value = null
    return
  }

  const nextSlots = [...advancementSlots.value]
  nextSlots[targetIndex] = teamId
  if (sourceIndex >= 0) nextSlots[sourceIndex] = currentTeam
  await persistAdvancementSlots(nextSlots, `已将 ${teamMeta[teamId].name} 调整至${advancementCategory(targetIndex)}`)
}

function closeAdvancementPicker() {
  advancementPicker.value = null
}

async function clearAdvancementSlot() {
  if (advancementPicker.value === null) return
  const nextSlots = [...advancementSlots.value]
  nextSlots[advancementPicker.value] = null
  await persistAdvancementSlots(nextSlots, '已清空该晋级预测位置')
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
  { id: 'e1', time: '8月20日 10:00', group: '附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e2', time: '8月20日 13:00', group: '附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e3', time: '8月20日 16:00', group: '附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e4', time: '8月20日 19:00', group: '附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
  { id: 'e5', time: '8月20日 22:00', group: '附加赛', bestOf: 'BO3', a: null, b: null, recordA: '3-2', recordB: '2-3' },
]

const groupScheduleModeStorageKey = 'ti2026-group-schedule-mode-v1'
const swissSimulationStorageKey = 'ti2026-swiss-simulation-v1'
const swissSimulationPlayInStorageKey = 'ti2026-swiss-simulation-playin-v1'
const swissSimulationPlayInWinnersStorageKey = 'ti2026-swiss-simulation-playin-winners-v1'
const swissSimulationLocalTouchedStorageKey = 'ti2026-swiss-simulation-local-touched-v1'

function loadSwissSimulationPicks() {
  try {
    const stored = JSON.parse(localStorage.getItem(swissSimulationStorageKey))
    return stored && typeof stored === 'object' && !Array.isArray(stored) ? stored : {}
  } catch {
    return {}
  }
}

function loadSwissSimulationPlayIn() {
  try {
    const stored = JSON.parse(localStorage.getItem(swissSimulationPlayInStorageKey))
    return stored && typeof stored === 'object' && !Array.isArray(stored) ? stored : {}
  } catch {
    return {}
  }
}

function loadSwissSimulationPlayInWinners() {
  try {
    const stored = JSON.parse(localStorage.getItem(swissSimulationPlayInWinnersStorageKey))
    return stored && typeof stored === 'object' && !Array.isArray(stored) ? stored : {}
  } catch {
    return {}
  }
}

const groupScheduleMode = ref(localStorage.getItem(groupScheduleModeStorageKey) === 'prediction' ? 'prediction' : 'real')
const swissSimulationPicks = ref(loadSwissSimulationPicks())
const swissSimulationPlayIn = ref(loadSwissSimulationPlayIn())
const swissSimulationPlayInWinners = ref(loadSwissSimulationPlayInWinners())
const simulationOpponentPicker = ref(null)
const swissCloudSummary = ref(null)
const swissCloudSaving = ref(false)
const swissSimulation = computed(() => buildSwissSimulation(swissSimulationPicks.value))
const swissCloudLocked = computed(() => Boolean(swissCloudSummary.value && !swissCloudSummary.value.acceptingPredictions))
const swissCloudStatusText = computed(() => {
  if (swissCloudSaving.value) return '正在保存小组赛排名预测到云端…'
  if (swissCloudLocked.value) return '云端提交已于 8月13日 10:00 截止；你仍可继续模拟，之后的修改仅保存在本地。'
  if (cloudActive.value && swissCloudSummary.value) return '截止时间：8月13日 10:00；截止前的修改会自动保存到云端。'
  return '当前预测保存在本地；云端功能初始化后会自动同步。'
})

function currentSwissSnapshot() {
  return {
    picks: { ...swissSimulationPicks.value },
    playInPairings: { ...swissSimulationPlayIn.value },
    playInWinners: { ...swissSimulationPlayInWinners.value },
  }
}

function hasSwissSnapshotData(snapshot) {
  return Object.keys(snapshot.picks).length > 0
    || Object.keys(snapshot.playInPairings).length > 0
    || Object.keys(snapshot.playInWinners).length > 0
}

function applySwissSnapshot(snapshot) {
  swissSimulationPicks.value = { ...(snapshot.picks || {}) }
  swissSimulationPlayIn.value = { ...(snapshot.playInPairings || {}) }
  swissSimulationPlayInWinners.value = { ...(snapshot.playInWinners || {}) }
  localStorage.setItem(swissSimulationStorageKey, JSON.stringify(swissSimulationPicks.value))
  localStorage.setItem(swissSimulationPlayInStorageKey, JSON.stringify(swissSimulationPlayIn.value))
  localStorage.setItem(swissSimulationPlayInWinnersStorageKey, JSON.stringify(swissSimulationPlayInWinners.value))
  localStorage.setItem(swissSimulationLocalTouchedStorageKey, '1')
}

let pendingSwissCloudSave = null
let swissCloudSaveRunning = false

async function flushSwissCloudSaves() {
  if (swissCloudSaveRunning) return
  swissCloudSaveRunning = true
  swissCloudSaving.value = true

  try {
    while (pendingSwissCloudSave) {
      const pending = pendingSwissCloudSave
      pendingSwissCloudSave = null
      try {
        swissCloudSummary.value = await submitCloudSwissPrediction(pending.snapshot)
        showToast(`${pending.message}，已保存到云端`)
      } catch (error) {
        if (error.message?.toLowerCase().includes('locked')) {
          swissCloudSummary.value = {
            ...(swissCloudSummary.value || {}),
            acceptingPredictions: false,
          }
          pendingSwissCloudSave = null
          showToast(`${pending.message}，截止后仅保存在本地`)
        } else {
          showToast(`${pending.message}，云端保存失败，已保存在本地`)
        }
      }
    }
  } finally {
    swissCloudSaving.value = false
    swissCloudSaveRunning = false
  }
}

function persistSwissSnapshot(message) {
  localStorage.setItem(swissSimulationLocalTouchedStorageKey, '1')
  if (!cloudActive.value) {
    showToast(`${message}，已保存在本地`)
    return
  }
  if (swissCloudLocked.value) {
    showToast(`${message}，截止后仅保存在本地`)
    return
  }

  pendingSwissCloudSave = { snapshot: currentSwissSnapshot(), message }
  void flushSwissCloudSaves()
}

const simulationStandingsRows = computed(() => {
  const selectors = swissSimulation.value.playInSelectors.map(row => row.team)
  const latestRound = swissSimulation.value.rounds.at(-1)
  let orderedStandings = [...swissSimulation.value.standings]
  if (latestRound && !latestRound.completed) {
    const completedRoundPicks = Object.fromEntries(Object.entries(swissSimulationPicks.value).filter(([id]) => {
      const round = Number(id.match(/^sim-r(\d+)-/)?.[1] || 0)
      return round < latestRound.round
    }))
    const stableOrder = buildSwissSimulation(completedRoundPicks).standings.map(row => row.team)
    const stableOrderMap = Object.fromEntries(stableOrder.map((teamId, index) => [teamId, index]))
    orderedStandings.sort((a, b) => stableOrderMap[a.team] - stableOrderMap[b.team])
  }
  const winsByTeam = {}
  const promotionMatchIds = new Set()
  swissSimulation.value.rounds.forEach(round => round.matches.forEach(match => {
    if (!match.winner) return
    winsByTeam[match.winner] = Number(winsByTeam[match.winner] || 0) + 1
    if (winsByTeam[match.winner] === 4) promotionMatchIds.add(match.id)
  }))
  return orderedStandings.map((row, displayIndex) => {
    const selectedOpponent = swissSimulationPlayIn.value[row.team]
    const selectedBy = Object.entries(swissSimulationPlayIn.value).find(([, opponent]) => opponent === row.team)?.[0]
    const selectorIndex = selectors.indexOf(row.team)
    const earlierSelectorsComplete = selectorIndex >= 0 && selectors.slice(0, selectorIndex).every(teamId => swissSimulationPlayIn.value[teamId])
    const playInOpponent = selectedOpponent || selectedBy || null
    const pairingOwner = selectedOpponent ? row.team : selectedBy || (selectorIndex >= 0 ? row.team : null)
    const selectedWinner = pairingOwner ? swissSimulationPlayInWinners.value[pairingOwner] : null
    const validWinner = playInOpponent && [row.team, playInOpponent].includes(selectedWinner) ? selectedWinner : null
    return {
      ...row,
      rank: displayIndex + 1,
      rounds: swissRounds.map(roundNumber => {
        const match = swissSimulation.value.rounds.find(round => round.round === roundNumber)?.matches.find(item => item.a === row.team || item.b === row.team)
        if (!match) return { opponent: null, result: null }
        const opponent = match.a === row.team ? match.b : match.a
        return {
          opponent,
          result: match.winner ? (match.winner === row.team ? 'win' : 'loss') : null,
          promotion: match.winner === row.team && promotionMatchIds.has(match.id),
          match,
        }
      }),
      playIn: {
        opponent: playInOpponent,
        owner: pairingOwner,
        winner: validWinner,
        result: validWinner ? (validWinner === row.team ? 'win' : 'loss') : null,
        selector: selectorIndex >= 0,
        canSelect: swissSimulation.value.finished && selectorIndex >= 0 && (earlierSelectorsComplete || Boolean(selectedOpponent)),
      },
    }
  })
})
const simulationAvailableOpponents = computed(() => {
  const selector = simulationOpponentPicker.value
  const used = new Set(Object.entries(swissSimulationPlayIn.value).filter(([team]) => team !== selector).map(([, opponent]) => opponent))
  return swissSimulation.value.playInOpponents.filter(row => !used.has(row.team))
})

function selectGroupScheduleMode(mode) {
  if (!['real', 'prediction'].includes(mode)) return
  groupScheduleMode.value = mode
  localStorage.setItem(groupScheduleModeStorageKey, mode)
  activeSwissRound.value = 1
}

function simulationStandingZone(row) {
  if (row.wins >= 4) return 'advance'
  if (row.losses >= 4) return 'eliminated'
  return 'active'
}

function pickSimulationStandingWinner(teamId, round) {
  if (!round.match) return
  pickSimulationWinner(round.match, teamId)
}

function simulationPlayInCellTitle(row) {
  if (!swissSimulation.value.finished) return '完成第 5 轮后确定附加赛对阵'
  if (row.playIn.opponent) return `点击 ${team(row.playIn.opponent).name} 队标选择该队获胜${row.playIn.selector ? '；右上角可取消配对' : ''}`
  if (row.playIn.selector) return row.playIn.canSelect ? '点击选择一支 2-3 队伍作为对手' : '等待排名更高的 3-2 队伍先选择对手'
  return '该队不参加晋级附加赛'
}

function pickSimulationWinner(match, teamId) {
  if (teamId !== match.a && teamId !== match.b) return
  if (swissSimulationPicks.value[match.id] === teamId) return
  const nextPicks = Object.fromEntries(Object.entries(swissSimulationPicks.value).filter(([id]) => {
    const round = Number(id.match(/^sim-r(\d+)-/)?.[1] || 0)
    return round <= match.round
  }))
  nextPicks[match.id] = teamId
  swissSimulationPicks.value = nextPicks
  swissSimulationPlayIn.value = {}
  swissSimulationPlayInWinners.value = {}
  localStorage.setItem(swissSimulationStorageKey, JSON.stringify(nextPicks))
  localStorage.removeItem(swissSimulationPlayInStorageKey)
  localStorage.removeItem(swissSimulationPlayInWinnersStorageKey)

  const completedRound = swissSimulation.value.rounds.find(round => round.round === match.round)?.completed
  if (completedRound && match.round < 5) {
    persistSwissSnapshot(`第 ${match.round + 1} 轮模拟对阵已生成`)
  } else {
    persistSwissSnapshot(`已选择 ${teamMeta[teamId]?.name || teamId} 获胜`)
  }
}

function resetSwissSimulation() {
  swissSimulationPicks.value = {}
  swissSimulationPlayIn.value = {}
  swissSimulationPlayInWinners.value = {}
  simulationOpponentPicker.value = null
  activeSwissRound.value = 1
  localStorage.removeItem(swissSimulationStorageKey)
  localStorage.removeItem(swissSimulationPlayInStorageKey)
  localStorage.removeItem(swissSimulationPlayInWinnersStorageKey)
  persistSwissSnapshot('预测模式已重置')
}

function openSimulationOpponentPicker(teamId) {
  const selectors = swissSimulation.value.playInSelectors.map(row => row.team)
  const index = selectors.indexOf(teamId)
  if (index < 0 || selectors.slice(0, index).some(teamIdBefore => !swissSimulationPlayIn.value[teamIdBefore])) {
    showToast('请按 3-2 队伍排名顺序选择对手')
    return
  }
  simulationOpponentPicker.value = teamId
}

function chooseSimulationOpponent(opponentId) {
  if (!simulationOpponentPicker.value || !simulationAvailableOpponents.value.some(row => row.team === opponentId)) return
  const selector = simulationOpponentPicker.value
  swissSimulationPlayIn.value = { ...swissSimulationPlayIn.value, [selector]: opponentId }
  const nextWinners = { ...swissSimulationPlayInWinners.value }
  delete nextWinners[selector]
  swissSimulationPlayInWinners.value = nextWinners
  localStorage.setItem(swissSimulationPlayInStorageKey, JSON.stringify(swissSimulationPlayIn.value))
  localStorage.setItem(swissSimulationPlayInWinnersStorageKey, JSON.stringify(nextWinners))
  simulationOpponentPicker.value = null
  persistSwissSnapshot('晋级附加赛对手已选择')
}

function cancelSimulationPlayIn(selector) {
  if (!swissSimulationPlayIn.value[selector]) return
  const nextPairings = { ...swissSimulationPlayIn.value }
  const nextWinners = { ...swissSimulationPlayInWinners.value }
  delete nextPairings[selector]
  delete nextWinners[selector]
  swissSimulationPlayIn.value = nextPairings
  swissSimulationPlayInWinners.value = nextWinners
  localStorage.setItem(swissSimulationPlayInStorageKey, JSON.stringify(nextPairings))
  localStorage.setItem(swissSimulationPlayInWinnersStorageKey, JSON.stringify(nextWinners))
  simulationOpponentPicker.value = null
  persistSwissSnapshot('已取消该组附加赛对阵')
}

function pickSimulationPlayInWinner(playIn) {
  if (!playIn.owner || !playIn.opponent) return
  const nextWinners = { ...swissSimulationPlayInWinners.value, [playIn.owner]: playIn.opponent }
  swissSimulationPlayInWinners.value = nextWinners
  localStorage.setItem(swissSimulationPlayInWinnersStorageKey, JSON.stringify(nextWinners))
  persistSwissSnapshot(`已选择 ${teamMeta[playIn.opponent]?.name || playIn.opponent} 赢得附加赛`)
}

function realEliminationMatchForTeam(teamId) {
  return eliminationMatches.find(match => match.a === teamId || match.b === teamId) || null
}

function realEliminationOpponent(match, teamId) {
  if (!match) return null
  return match.a === teamId ? match.b : match.a
}

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
const bracketStorageKey = 'ti2026-entertainment-bracket-v1'
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

function restoreEntertainmentBracket() {
  try {
    const stored = JSON.parse(localStorage.getItem(bracketStorageKey))
    if (!stored || typeof stored !== 'object') return

    const usedTeams = new Set()
    manualBracketGameIds.forEach(gameId => {
      const game = bracketGameById(gameId)
      if (!game) return
      ;['a', 'b'].forEach(side => {
        const teamId = stored.slots?.[gameId]?.[side]
        if (!teamMeta[teamId] || usedTeams.has(teamId)) return
        game[side] = teamId
        usedTeams.add(teamId)
      })
    })

    allBracketGames().forEach(game => {
      const winner = stored.winners?.[String(game.id)]
      if (teamMeta[winner]) game.winner = winner
    })
    rebuildEntertainmentBracket()
  } catch {
    // Ignore invalid local state and start with an empty entertainment bracket.
  }
}

function saveEntertainmentBracket() {
  const slots = {}
  const winners = {}

  manualBracketGameIds.forEach(gameId => {
    const game = bracketGameById(gameId)
    if (game) slots[gameId] = { a: game.a, b: game.b }
  })
  allBracketGames().forEach(game => {
    if (game.winner) winners[String(game.id)] = game.winner
  })

  localStorage.setItem(bracketStorageKey, JSON.stringify({ slots, winners }))
}

restoreEntertainmentBracket()

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
const groupPredictionCount = computed(() => Object.keys(predictions.value).filter(key => (
  /^\d+$/.test(key) && Number(key) >= 1 && Number(key) <= 39
)).length)
const playoffPredictionCount = computed(() => allBracketGames().filter(game => game.winner).length)
const allMatchRecords = [...matches.value, ...eliminationMatches]
const predictionRecords = computed(() => allMatchRecords
  .filter(match => predictions.value[String(match.id)])
  .map(match => {
    const chosen = predictions.value[String(match.id)]
    const outcome = !match.winner
      ? { state: 'pending', label: '结果待揭晓' }
      : chosen === match.winner
        ? { state: 'correct', label: '预测正确' }
        : { state: 'incorrect', label: '预测错误' }
    return { ...match, chosen, outcome }
  }))
const resolvedMatchCount = computed(() => predictionRecords.value.filter(match => match.outcome.state !== 'pending').length)
const correctPredictionCount = computed(() => predictionRecords.value.filter(match => match.outcome.state === 'correct').length)
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

watch(advancementSlots, value => {
  localStorage.setItem(advancementStorageKey, JSON.stringify(value))
}, { deep: true })

watch(
  () => allBracketGames().map(game => [game.id, game.a, game.b, game.winner]),
  saveEntertainmentBracket,
  { deep: true },
)

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
  if (window.location.hash.replace(/^#/, '').split('?')[0] === '/elimination-round') activeSwissRound.value = 'playin'
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
  return teamMeta[id] || { id, name: id, short: '?', color: '#6d6d74' }
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

    try {
      let cloudAdvancement = await getCloudAdvancementPrediction()
      if (Array.isArray(cloudAdvancement?.slots) && cloudAdvancement.slots.length === 16) {
        advancementSlots.value = cloudAdvancement.slots
      } else if (advancementAssignedCount.value > 0 && cloudAdvancement?.acceptingPredictions) {
        cloudAdvancement = await submitCloudAdvancementPrediction(advancementSlots.value)
      }
      advancementSummary.value = cloudAdvancement
    } catch (error) {
      console.error('Supabase advancement prediction initialization failed:', error)
      showToast('单场预测已连接，晋级预测云端功能尚未初始化')
    }

    try {
      let cloudSwiss = await getCloudSwissPrediction()
      const localSwiss = currentSwissSnapshot()
      const hasLocalSwiss = localStorage.getItem(swissSimulationLocalTouchedStorageKey) === '1'
        || hasSwissSnapshotData(localSwiss)

      if (cloudSwiss?.hasPrediction) {
        // After the deadline, preserve any newer local-only simulation changes.
        if (cloudSwiss.acceptingPredictions || !hasLocalSwiss) applySwissSnapshot(cloudSwiss)
      } else if (hasLocalSwiss && cloudSwiss?.acceptingPredictions) {
        cloudSwiss = await submitCloudSwissPrediction(localSwiss)
      }
      swissCloudSummary.value = cloudSwiss
    } catch (error) {
      console.error('Supabase Swiss prediction initialization failed:', error)
      showToast('其他预测已连接，小组赛排名预测暂时仅保存在本地')
    }
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
        <img src="/ti2026_logo.png" alt="TI 2026 官方徽标" />
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
              <div class="hero-team-cloud">
                <span v-for="item in heroFloatingTeams" :key="item.id" class="hero-team-float" :style="item.style">
                  <img :src="item.meta.logo" alt="" />
                </span>
              </div>
              <div class="aegis-ring ring-outer"></div>
              <div class="aegis-ring ring-inner"></div>
              <img src="/ti2026_logo.png" alt="" />
            </div>
            <div class="hero-stats">
              <h2>已完成预测</h2>
              <button class="hero-stat-link" aria-label="前往小组排名预测" @click="selectView('standings')"><span>小组排名</span><strong>{{ swissSimulation.completedRounds }}<small>/ 5</small></strong><ArrowRight :size="16" /></button>
              <button class="hero-stat-link" aria-label="前往小组赛程预测" @click="selectView('groups')"><span>小组赛程</span><strong>{{ groupPredictionCount }}<small>/ 39</small></strong><ArrowRight :size="16" /></button>
              <button class="hero-stat-link" aria-label="前往晋级预测" @click="selectView('advancement')"><span>晋级预测<small class="hero-stat-deadline">截止时间: 8月13日10:00</small></span><strong>{{ advancementAssignedCount }}<small>/ 16</small></strong><ArrowRight :size="16" /></button>
              <button class="hero-stat-link" aria-label="前往淘汰赛对阵预测" @click="selectView('playoffs')"><span>淘汰赛对阵</span><strong>{{ playoffPredictionCount }}<small>/ 14</small></strong><ArrowRight :size="16" /></button>
            </div>
          </section>

        </template>

        <template v-else-if="activeView === 'groups'">
          <section class="page-title"><div><span class="section-kicker">SWISS STAGE · FIVE ROUNDS</span><h1>小组赛程</h1><p>瑞士轮共进行五轮，随后进行 5 场附加赛；所有比赛均为 BO3。</p></div><div class="stage-badge"><CalendarDays :size="22" /><span>{{ activeSwissRound === 1 || activeSwissRound === 'playin' ? '比赛日' : '赛程状态' }}<strong>{{ activeSwissRound === 1 ? '8月13日' : activeSwissRound === 'playin' ? '8月20日' : '待公布' }}</strong></span></div></section>
          <div class="round-tabs" role="tablist" aria-label="瑞士轮赛程轮次">
            <button v-for="round in swissRounds" :key="round" role="tab" :aria-selected="activeSwissRound === round" :class="{ active: activeSwissRound === round }" @click="activeSwissRound = round">
              <span>第 {{ round }} 轮</span><small>{{ round === 1 ? '8月13日' : '待公布' }}</small>
            </button>
            <button role="tab" :aria-selected="activeSwissRound === 'playin'" :class="{ active: activeSwissRound === 'playin' }" @click="activeSwissRound = 'playin'">
              <span>附加赛</span><small>8月20日</small>
            </button>
          </div>
          <section class="section-heading schedule-heading"><div><span class="section-kicker">{{ activeSwissRound === 'playin' ? 'ELIMINATION ROUND' : `ROUND ${activeSwissRound}` }} · BEIJING TIME</span><h2>{{ activeSwissRound === 'playin' ? '附加赛赛程' : `第 ${activeSwissRound} 轮赛程` }}</h2></div><span class="muted">{{ activeSwissRound === 1 ? `共 ${matches.length} 场` : activeSwissRound === 'playin' ? '共 5 场' : '对阵待公布' }} · BO3</span></section>
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
          <div v-else-if="activeSwissRound === 'playin'" class="match-grid schedule-match-grid elimination-match-grid">
            <article v-for="match in eliminationMatches" :key="match.id" class="match-card">
              <div class="match-meta"><span><Clock3 :size="13" /> {{ match.time }}</span><span>{{ match.recordA }} vs {{ match.recordB }} · {{ match.bestOf }}</span></div>
              <div v-if="match.a && match.b" class="match-versus">
                <button :class="['team-pick', { selected: predictions[match.id] === match.a }]" :disabled="submittingMatch === String(match.id)" @click="pick(match.id, match.a)">
                  <TeamLogo :meta="team(match.a)" /><strong>{{ team(match.a).name }}</strong><small>{{ predictions[match.id] === match.a ? '你的选择' : '选择胜者' }}</small>
                </button>
                <div class="vs"><span>VS</span><small>{{ match.bestOf }}</small></div>
                <button :class="['team-pick', { selected: predictions[match.id] === match.b }]" :disabled="submittingMatch === String(match.id)" @click="pick(match.id, match.b)">
                  <TeamLogo :meta="team(match.b)" /><strong>{{ team(match.b).name }}</strong><small>{{ predictions[match.id] === match.b ? '你的选择' : '选择胜者' }}</small>
                </button>
              </div>
              <div v-else class="match-versus">
                <div class="team-pick pending"><span class="pending-team-icon">?</span><strong>待定</strong><small>3-2 队伍</small></div>
                <div class="vs"><span>VS</span><small>{{ match.bestOf }}</small></div>
                <div class="team-pick pending"><span class="pending-team-icon">?</span><strong>待定</strong><small>2-3 队伍</small></div>
              </div>
              <div v-if="match.a && match.b" class="vote-summary">
                <div class="vote-numbers"><span>{{ percentFor(match.id, match.a) }}% · {{ votesFor(match.id, match.a) }}票</span><small>{{ totalFor(match.id) }} 人已预测</small><span>{{ votesFor(match.id, match.b) }}票 · {{ percentFor(match.id, match.b) }}%</span></div>
                <div class="vote-bar"><i :style="{ width: percentFor(match.id, match.a) + '%' }"></i><b :style="{ width: percentFor(match.id, match.b) + '%' }"></b></div>
              </div>
              <div v-else class="match-pending-note">对阵将在小组赛结束后公布</div>
            </article>
          </div>
          <section v-else class="round-empty-state">
            <span class="round-empty-icon"><CalendarDays :size="30" /></span>
            <div><span class="section-kicker">ROUND {{ activeSwissRound }}</span><h2>第 {{ activeSwissRound }} 轮对阵待公布</h2><p>上一轮结束后，将根据各队当前战绩生成本轮对阵。</p></div>
          </section>
        </template>

        <template v-else-if="activeView === 'standings'">
          <section class="page-title"><div><span class="section-kicker">SWISS STAGE · FIVE ROUNDS</span><h1>小组赛排名</h1><p>{{ groupScheduleMode === 'real' ? '展示官方公布的真实战绩、排名和各轮对手。' : '根据小组赛预测模式中的胜负选择，实时计算模拟排名与晋级状态。' }}</p></div><div class="stage-badge"><ListOrdered :size="22" /><span>{{ groupScheduleMode === 'real' ? '晋级规则' : '模拟进度' }}<strong>{{ groupScheduleMode === 'real' ? '4 胜直接晋级' : `${swissSimulation.completedRounds} / 5 轮` }}</strong></span></div></section>
          <div class="group-mode-toolbar standings-mode-toolbar">
            <div class="group-mode-switch" role="tablist" aria-label="小组赛排名模式">
              <button role="tab" :aria-selected="groupScheduleMode === 'real'" :class="{ active: groupScheduleMode === 'real' }" @click="selectGroupScheduleMode('real')">真实模式</button>
              <button role="tab" :aria-selected="groupScheduleMode === 'prediction'" :class="{ active: groupScheduleMode === 'prediction' }" @click="selectGroupScheduleMode('prediction')">预测模式</button>
            </div>
            <span>{{ groupScheduleMode === 'real' ? '排名将随官方比赛结果更新。' : `点击各轮的对手队标选择该队获胜，系统自动生成后续对阵。${swissCloudStatusText}` }}</span>
            <button v-if="groupScheduleMode === 'prediction'" class="simulation-reset" title="重置预测模式" @click="resetSwissSimulation"><RotateCcw :size="15" />重置模拟</button>
          </div>
          <section class="swiss-section">
            <div class="swiss-section-head"><div><span class="section-kicker">{{ groupScheduleMode === 'real' ? 'CURRENT STANDINGS' : 'SIMULATED STANDINGS' }}</span><h2>{{ groupScheduleMode === 'real' ? '小组赛对阵与排名' : '预测模式对阵与排名' }}</h2></div><span class="status-note"><span class="live-dot"></span> {{ groupScheduleMode === 'real' ? '第 1 轮待开始' : `已完成 ${swissSimulation.completedRounds} 轮` }}</span></div>
            <div class="swiss-table-scroll">
              <div class="swiss-table">
                <div class="swiss-row swiss-head"><span>#</span><span>参赛队伍</span><span>{{ groupScheduleMode === 'real' ? '比赛' : '战绩' }}</span><span>{{ groupScheduleMode === 'real' ? '局分' : '对手分' }}</span><span>第 1 轮</span><span>第 2 轮</span><span>第 3 轮</span><span>第 4 轮</span><span>第 5 轮</span><span>附加赛</span></div>
                <template v-if="groupScheduleMode === 'real'">
                  <div v-for="row in swissStandings" :key="row.team" class="swiss-row" :class="`zone-${row.zone}`">
                    <span class="swiss-rank">{{ row.rank }}</span>
                    <span class="swiss-team"><TeamLogo :meta="team(row.team)" compact /><strong>{{ team(row.team).name }}</strong></span>
                    <strong class="swiss-record">{{ row.matches }}</strong>
                    <span class="swiss-record">{{ row.games }}</span>
                    <span v-for="(opponent, roundIndex) in row.rounds" :key="roundIndex" class="swiss-round-cell" :title="opponent ? `第 ${roundIndex + 1} 轮对阵 ${team(opponent).name}` : `第 ${roundIndex + 1} 轮待定`">
                      <TeamLogo v-if="opponent" :meta="team(opponent)" compact />
                      <i v-else></i>
                    </span>
                    <button v-if="realEliminationMatchForTeam(row.team)" type="button" class="swiss-round-cell simulation-round-cell playin-round-cell assigned" :class="predictions[realEliminationMatchForTeam(row.team).id] ? (predictions[realEliminationMatchForTeam(row.team).id] === row.team ? 'win' : 'loss') : ''" :disabled="submittingMatch === String(realEliminationMatchForTeam(row.team).id)" :title="`点击选择 ${team(realEliminationOpponent(realEliminationMatchForTeam(row.team), row.team)).name} 赢得附加赛`" @click="pick(realEliminationMatchForTeam(row.team).id, realEliminationOpponent(realEliminationMatchForTeam(row.team), row.team))">
                      <TeamLogo :meta="team(realEliminationOpponent(realEliminationMatchForTeam(row.team), row.team))" compact />
                      <small v-if="predictions[realEliminationMatchForTeam(row.team).id]" class="result-badge">{{ predictions[realEliminationMatchForTeam(row.team).id] === row.team ? '晋' : '负' }}</small>
                    </button>
                    <span v-else class="swiss-round-cell playin-round-cell" title="晋级附加赛对阵待公布"><i></i></span>
                  </div>
                </template>
                <template v-else>
                  <div v-for="row in simulationStandingsRows" :key="row.team" class="swiss-row simulation-swiss-row" :class="`zone-${simulationStandingZone(row)}`">
                    <span class="swiss-rank">{{ row.rank }}</span>
                    <span class="swiss-team"><TeamLogo :meta="team(row.team)" compact /><strong>{{ team(row.team).name }}</strong></span>
                    <strong class="swiss-record">{{ row.wins }} - {{ row.losses }}</strong>
                    <span class="swiss-record">{{ row.buchholz }}</span>
                    <button v-for="(round, roundIndex) in row.rounds" :key="roundIndex" type="button" class="swiss-round-cell simulation-round-cell" :class="[round.result, { promotion: round.promotion }]" :disabled="!round.match" :title="round.opponent ? `点击选择 ${team(round.opponent).name} 在第 ${roundIndex + 1} 轮获胜` : `第 ${roundIndex + 1} 轮待定`" :aria-label="round.opponent ? `选择 ${team(round.opponent).name} 战胜 ${team(row.team).name}` : `第 ${roundIndex + 1} 轮待定`" @click="pickSimulationStandingWinner(round.opponent, round)">
                      <TeamLogo v-if="round.opponent" :meta="team(round.opponent)" compact />
                      <i v-else></i>
                      <small v-if="round.result">{{ round.promotion ? '晋' : round.result === 'win' ? '胜' : '负' }}</small>
                    </button>
                    <div class="swiss-round-cell playin-round-cell" :class="[row.playIn.result, { selectable: row.playIn.canSelect && !row.playIn.opponent, assigned: row.playIn.opponent }]" :title="simulationPlayInCellTitle(row)">
                      <button type="button" class="playin-cell-main" :disabled="!row.playIn.opponent && !row.playIn.canSelect" :aria-label="simulationPlayInCellTitle(row)" @click="row.playIn.opponent ? pickSimulationPlayInWinner(row.playIn) : openSimulationOpponentPicker(row.team)">
                        <TeamLogo v-if="row.playIn.opponent" :meta="team(row.playIn.opponent)" compact />
                        <span v-else-if="row.playIn.selector && swissSimulation.finished" class="playin-cell-placeholder">?</span>
                        <i v-else></i>
                        <small v-if="row.playIn.result" class="result-badge">{{ row.playIn.result === 'win' ? '晋' : '负' }}</small>
                        <small v-else-if="row.playIn.selector && swissSimulation.finished && !row.playIn.opponent" class="playin-choice-status">{{ row.playIn.canSelect ? '选择' : '等待' }}</small>
                      </button>
                      <button v-if="row.playIn.selector && row.playIn.opponent" type="button" class="playin-cell-clear" title="取消该组附加赛对阵" aria-label="取消该组附加赛对阵" @click.stop="cancelSimulationPlayIn(row.team)"><X :size="12" /></button>
                    </div>
                  </div>
                </template>
              </div>
            </div>
          </section>
          <div class="standings-legend"><span><i class="legend-mark advance"></i> 4 胜直接晋级</span><span><i class="legend-mark active"></i> 3-2 / 2-3 进入晋级附加赛</span><span><i class="legend-mark eliminated"></i> 4 负淘汰</span><span><i class="legend-line"></i> {{ groupScheduleMode === 'real' ? '当前为首轮初始数据' : '排名依据战绩、对手分和初始顺位' }}</span></div>
        </template>

        <template v-else-if="activeView === 'advancement'">
          <section class="page-title advancement-page-title"><div><span class="section-kicker">ROAD TO THE MAIN EVENT</span><h1>晋级预测</h1><p>将 16 支队伍分配到最终战绩区间，点击任意格子选择或调整队伍。</p></div><div class="stage-badge gold"><GitBranch :size="22" /><span>{{ advancementResultsPublished ? '官方结果' : '已分配队伍' }}<strong>{{ advancementResultsPublished ? '已公布' : `${advancementAssignedCount} / 16` }}</strong></span></div></section>
          <section v-if="advancementResultsPublished" class="advancement-stats" aria-label="晋级预测结果统计">
            <div><span>我的准确率</span><strong>{{ advancementSummary?.myAccuracy === null ? '—' : `${advancementSummary.myAccuracy}%` }}</strong><small>{{ advancementSummary?.myCorrectCount === null ? '完整填写后参与统计' : `正确 ${advancementSummary.myCorrectCount} / 16` }}</small></div>
            <div><span>全站平均准确率</span><strong>{{ advancementSummary?.averageAccuracy === null ? '—' : `${advancementSummary.averageAccuracy}%` }}</strong><small>仅统计完整预测</small></div>
            <div><span>我的全站排名</span><strong>{{ advancementSummary?.myRank ? `#${advancementSummary.myRank}` : '—' }}</strong><small>共 {{ advancementSummary?.totalPlayers || 0 }} 人参与</small></div>
            <div><span>全部命中</span><strong>{{ advancementSummary?.perfectPlayers || 0 }}</strong><small>准确率 100% 的玩家</small></div>
          </section>
          <div class="advancement-board-scroll">
            <section class="advancement-board" aria-label="小组赛晋级结果预测">
              <div class="advancement-bands advancement-bands-top">
                <div class="advancement-band" style="grid-column: 1 / span 1"><strong>4-0</strong><span>一支全胜的队伍</span></div>
                <div class="advancement-band" style="grid-column: 2 / span 2"><strong>4-1</strong><span>两支四胜一负的队伍</span></div>
                <div class="advancement-band" style="grid-column: 4 / span 5"><strong>晋级附加赛胜者</strong><span>五支在晋级附加赛胜出的队伍</span></div>
              </div>
              <div class="advancement-team-grid">
                <button v-for="(teamId, index) in advancementSlots" :key="index" class="advancement-slot" :class="{ empty: !teamId, correct: advancementOutcome(index, teamId) === 'correct', incorrect: advancementOutcome(index, teamId) === 'incorrect' }" :aria-label="teamId ? `${advancementCategory(index)}：${team(teamId).name}，点击调整` : `${advancementCategory(index)}：待选择队伍`" @click="openAdvancementPicker(index)">
                  <TeamLogo v-if="teamId" :meta="team(teamId)" />
                  <span v-else class="advancement-empty-logo">?</span>
                  <strong>{{ teamId ? team(teamId).name : '待选择' }}</strong>
                  <small v-if="advancementResultsPublished && teamId">实际：{{ advancementOfficialCategory(teamId) }}</small>
                </button>
              </div>
              <div class="advancement-bands advancement-bands-bottom">
                <div class="advancement-band" style="grid-column: 1 / span 5"><span>五支在晋级附加赛失利的队伍</span><strong>晋级附加赛败者</strong></div>
                <div class="advancement-band" style="grid-column: 6 / span 2"><span>两支一胜四负的队伍</span><strong>1-4</strong></div>
                <div class="advancement-band" style="grid-column: 8 / span 1"><span>一支全败的队伍</span><strong>0-4</strong></div>
              </div>
            </section>
          </div>
          <div class="bracket-note"><Shield :size="18" /><span>{{ advancementCloudStatusText }}</span></div>
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
          <div class="bracket-note"><Shield :size="18" /><span>当前淘汰赛路径仅供娱乐，只保存在当前浏览器、不参与预测统计；胜者进入下一轮，败者进入败者组，小组赛结束后将更新正式对阵。</span></div>
        </template>

        <template v-else>
          <section class="page-title"><div><span class="section-kicker">MY PREDICTIONS</span><h1>我的预测</h1><p>已完成 {{ predictionCount }} 项预测，继续完善你的 TI 2026 晋级图。</p></div><div class="stage-badge"><Target :size="22" /><span>预测完成度<strong>{{ Math.round(predictionCount / totalMatchCount * 100) }}%</strong></span></div></section>
          <div v-if="predictionCount" class="picks-grid">
            <article v-for="match in predictionRecords" :key="match.id" class="match-card pick-summary" :class="`is-${match.outcome.state}`">
              <div class="match-meta">
                <span><Clock3 :size="13" /> {{ match.time }}</span>
                <span>{{ match.group }} · {{ match.bestOf }}</span>
              </div>
              <div class="match-versus">
                <div class="team-pick" :class="{ chosen: match.chosen === match.a, winner: match.winner === match.a }">
                  <TeamLogo :meta="team(match.a)" />
                  <strong>{{ team(match.a).name }}</strong>
                  <small>{{ match.chosen === match.a ? '你的预测' : (match.winner === match.a ? '比赛胜者' : '对阵队伍') }}</small>
                </div>
                <div class="vs"><span>VS</span><small>{{ match.score && match.score !== '—' ? match.score : match.bestOf }}</small></div>
                <div class="team-pick" :class="{ chosen: match.chosen === match.b, winner: match.winner === match.b }">
                  <TeamLogo :meta="team(match.b)" />
                  <strong>{{ team(match.b).name }}</strong>
                  <small>{{ match.chosen === match.b ? '你的预测' : (match.winner === match.b ? '比赛胜者' : '对阵队伍') }}</small>
                </div>
              </div>
              <footer class="pick-card-result">
                <span class="pick-outcome" :class="match.outcome.state">
                  <Clock3 v-if="match.outcome.state === 'pending'" :size="15" />
                  <CheckCircle2 v-else-if="match.outcome.state === 'correct'" :size="15" />
                  <XCircle v-else :size="15" />
                  {{ match.outcome.label }}
                </span>
                <span>{{ team(match.chosen).name }} · {{ percentFor(match.id, match.chosen) }}%</span>
              </footer>
            </article>
          </div>
          <div v-else class="empty-panel"><img src="/ti2026_logo.png" alt="TI 2026 官方徽标" /><div><h2>构筑你的冠军之路</h2><p>前往小组赛，选择你看好的战队。</p><button class="primary" @click="selectView('groups')">开始预测 <ArrowRight :size="17" /></button></div></div>
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
      <Transition name="modal">
        <div v-if="advancementPicker !== null" class="bracket-picker-scrim" @click.self="closeAdvancementPicker">
          <section class="bracket-picker advancement-picker" role="dialog" aria-modal="true" aria-labelledby="advancement-picker-title">
            <header>
              <div><span class="section-kicker">{{ advancementCategory(advancementPicker) }}</span><h2 id="advancement-picker-title">选择替换队伍</h2></div>
              <button aria-label="关闭队伍选择" @click="closeAdvancementPicker"><X :size="20" /></button>
            </header>
            <div class="bracket-team-options advancement-team-options">
              <button v-for="option in advancementTeamOptions" :key="option.id" :class="{ active: advancementSlots[advancementPicker] === option.id, used: advancementSlots.includes(option.id) }" :disabled="advancementSlots.includes(option.id)" @click="chooseAdvancementTeam(option.id)">
                <TeamLogo :meta="option.meta" compact /><span>{{ option.meta.name }}</span><small v-if="advancementSlots.includes(option.id)">{{ advancementSlots[advancementPicker] === option.id ? '当前格' : '已选择' }}</small>
              </button>
            </div>
            <button v-if="advancementSlots[advancementPicker]" class="advancement-clear-action" @click="clearAdvancementSlot"><X :size="16" /> 清空当前格</button>
          </section>
        </div>
      </Transition>
      <Transition name="modal">
        <div v-if="simulationOpponentPicker" class="bracket-picker-scrim" @click.self="simulationOpponentPicker = null">
          <section class="bracket-picker" role="dialog" aria-modal="true" aria-labelledby="simulation-opponent-picker-title">
            <header>
              <div><span class="section-kicker">3-2 TEAM SELECTS</span><h2 id="simulation-opponent-picker-title">{{ team(simulationOpponentPicker).name }} 选择对手</h2></div>
              <button aria-label="关闭对手选择" @click="simulationOpponentPicker = null"><X :size="20" /></button>
            </header>
            <div class="bracket-team-options simulation-opponent-options">
              <button v-for="option in simulationAvailableOpponents" :key="option.team" @click="chooseSimulationOpponent(option.team)">
                <TeamLogo :meta="team(option.team)" compact /><span>{{ team(option.team).name }}</span><small>#{{ option.rank }} · 2-3</small>
              </button>
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
