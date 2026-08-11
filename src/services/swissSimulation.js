export const swissSimulationTeams = [
  { id: 'Falcons', initialGroup: 'A', seed: 1 },
  { id: 'LGD', initialGroup: 'A', seed: 2 },
  { id: 'IronWing', initialGroup: 'A', seed: 3 },
  { id: 'Nigma', initialGroup: 'A', seed: 4 },
  { id: 'BoomBoys', initialGroup: 'A', seed: 5 },
  { id: 'OG', initialGroup: 'A', seed: 6 },
  { id: 'Vision', initialGroup: 'A', seed: 7 },
  { id: 'Resilience', initialGroup: 'A', seed: 8 },
  { id: 'Spirit', initialGroup: 'B', seed: 9 },
  { id: 'XG', initialGroup: 'B', seed: 10 },
  { id: 'Liquid', initialGroup: 'B', seed: 11 },
  { id: 'Vici', initialGroup: 'B', seed: 12 },
  { id: 'Aurora', initialGroup: 'B', seed: 13 },
  { id: 'GamerLegion', initialGroup: 'B', seed: 14 },
  { id: 'Yandex', initialGroup: 'B', seed: 15 },
  { id: 'Huligani', initialGroup: 'B', seed: 16 },
]

const initialRound = [
  ['Falcons', 'LGD', '8月13日 10:00'],
  ['IronWing', 'Nigma', '8月13日 10:00'],
  ['BoomBoys', 'OG', '8月13日 10:00'],
  ['Vision', 'Resilience', '8月13日 10:00'],
  ['Spirit', 'XG', '8月13日 13:00'],
  ['Liquid', 'Vici', '8月13日 13:00'],
  ['Aurora', 'GamerLegion', '8月13日 13:00'],
  ['Yandex', 'Huligani', '8月13日 13:00'],
]

function matchId(round, a, b) {
  return `sim-r${round}-${[a, b].sort().join('--')}`
}

function createMatch(round, a, b, records, time = '模拟生成') {
  const record = records[a] ? `${records[a].wins}-${records[a].losses}` : '0-0'
  return { id: matchId(round, a, b), round, a, b, record, time, bestOf: 'BO3' }
}

function createRecords() {
  return Object.fromEntries(swissSimulationTeams.map(team => [team.id, {
    team: team.id,
    initialGroup: team.initialGroup,
    seed: team.seed,
    wins: 0,
    losses: 0,
    opponents: [],
  }]))
}

function buchholz(team, records) {
  return records[team].opponents.reduce((total, opponent) => total + records[opponent].wins, 0)
}

function rankedTeams(records) {
  return swissSimulationTeams.map(team => team.id).sort((a, b) => (
    records[b].wins - records[a].wins
    || records[a].losses - records[b].losses
    || buchholz(b, records) - buchholz(a, records)
    || records[a].seed - records[b].seed
  ))
}

function pairingRestriction(round, a, b, records) {
  if (round === 2 || round === 3) return records[a].initialGroup === records[b].initialGroup
  if (round === 4) return records[a].initialGroup !== records[b].initialGroup
  return true
}

function pairScore(round, record, a, b, records, rankMap) {
  const repeated = records[a].opponents.includes(b) ? 1 : 0
  const rankGap = Math.abs(rankMap[a] - rankMap[b])
  const rankingScore = round === 5 && record === '1-3' ? -(rankGap ** 2) : rankGap
  return repeated * 100000 + rankingScore
}

function bestPairing(teamIds, round, record, records, rankMap) {
  const ordered = [...teamIds].sort((a, b) => rankMap[a] - rankMap[b])

  function search(remaining) {
    if (!remaining.length) return { pairs: [], score: 0, key: '' }
    const first = remaining[0]
    let best = null

    for (let index = 1; index < remaining.length; index += 1) {
      const second = remaining[index]
      if (!pairingRestriction(round, first, second, records)) continue
      const rest = remaining.filter((_, itemIndex) => itemIndex !== 0 && itemIndex !== index)
      const tail = search(rest)
      if (!tail) continue
      const score = pairScore(round, record, first, second, records, rankMap) + tail.score
      const pairs = [[first, second], ...tail.pairs]
      const key = pairs.map(pair => pair.join('-')).join('|')
      if (!best || score < best.score || (score === best.score && key < best.key)) best = { pairs, score, key }
    }
    return best
  }

  return search(ordered)?.pairs || []
}

function generateRound(round, records) {
  const activeTeams = rankedTeams(records).filter(team => records[team].wins < 4 && records[team].losses < 4)
  const rankMap = Object.fromEntries(rankedTeams(records).map((team, index) => [team, index]))
  const recordGroups = new Map()

  activeTeams.forEach(team => {
    const record = `${records[team].wins}-${records[team].losses}`
    if (!recordGroups.has(record)) recordGroups.set(record, [])
    recordGroups.get(record).push(team)
  })

  return [...recordGroups.entries()]
    .sort(([recordA], [recordB]) => Number(recordB[0]) - Number(recordA[0]))
    .flatMap(([record, teams]) => bestPairing(teams, round, record, records, rankMap)
      .map(([a, b]) => createMatch(round, a, b, records)))
}

function applyWinner(match, winner, records) {
  if (winner !== match.a && winner !== match.b) return false
  const loser = winner === match.a ? match.b : match.a
  records[winner].wins += 1
  records[loser].losses += 1
  records[match.a].opponents.push(match.b)
  records[match.b].opponents.push(match.a)
  return true
}

function standings(records) {
  return rankedTeams(records).map((team, index) => {
    const entry = records[team]
    let status = '进行中'
    if (entry.wins >= 4) status = '直接晋级'
    else if (entry.losses >= 4) status = '已淘汰'
    else if (entry.wins + entry.losses === 5) status = '晋级附加赛'
    return { ...entry, rank: index + 1, buchholz: buchholz(team, records), status }
  })
}

export function buildSwissSimulation(picks = {}) {
  const records = createRecords()
  const rounds = [{
    round: 1,
    matches: initialRound.map(([a, b, time]) => createMatch(1, a, b, records, time)),
  }]

  for (let roundNumber = 1; roundNumber <= 5; roundNumber += 1) {
    const round = rounds[roundNumber - 1]
    if (!round) break
    round.matches = round.matches.map(match => ({ ...match, winner: picks[match.id] || null }))
    round.matches.forEach(match => applyWinner(match, match.winner, records))
    round.completed = round.matches.length > 0 && round.matches.every(match => match.winner)
    if (!round.completed || roundNumber === 5) break

    const nextMatches = generateRound(roundNumber + 1, records)
    rounds.push({ round: roundNumber + 1, matches: nextMatches })
  }

  const table = standings(records)
  const completedRounds = rounds.filter(round => round.completed).length
  const finished = completedRounds === 5
  return {
    rounds,
    standings: table,
    completedRounds,
    finished,
    playInSelectors: finished ? table.filter(row => row.wins === 3 && row.losses === 2) : [],
    playInOpponents: finished ? table.filter(row => row.wins === 2 && row.losses === 3) : [],
  }
}
