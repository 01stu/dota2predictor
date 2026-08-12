const countryNamesZh = {
  Australia: '澳大利亚', Austria: '奥地利', Belarus: '白俄罗斯', Belgium: '比利时', Bolivia: '玻利维亚',
  'Bosnia and Herzegovina': '波斯尼亚和黑塞哥维那', Brazil: '巴西', Bulgaria: '保加利亚', Canada: '加拿大', China: '中国',
  Croatia: '克罗地亚', Czechia: '捷克', Denmark: '丹麦', Estonia: '爱沙尼亚', Finland: '芬兰', France: '法国',
  Germany: '德国', Greece: '希腊', Indonesia: '印度尼西亚', Israel: '以色列', Jordan: '约旦', Kazakhstan: '哈萨克斯坦',
  Kyrgyzstan: '吉尔吉斯斯坦', Laos: '老挝', Lebanon: '黎巴嫩', Macau: '中国澳门', Malaysia: '马来西亚', Mexico: '墨西哥',
  Moldova: '摩尔多瓦', Netherlands: '荷兰', Nicaragua: '尼加拉瓜', 'Non-representing': '无代表地区',
  'North Macedonia': '北马其顿', Norway: '挪威', Pakistan: '巴基斯坦', Peru: '秘鲁', Philippines: '菲律宾', Poland: '波兰',
  Romania: '罗马尼亚', Russia: '俄罗斯', Serbia: '塞尔维亚', Singapore: '新加坡', Slovakia: '斯洛伐克',
  'South Korea': '韩国', Sweden: '瑞典', Thailand: '泰国', Ukraine: '乌克兰', 'United Kingdom': '英国', 'United States': '美国',
}

const positionNamesZh = {
  Carry: '一号位', Mid: '二号位', Offlane: '三号位', Support: '辅助', Carry4: '四号位', Carry5: '五号位', Coach: '教练', Other: '其他',
}

function parseCsvRows(text) {
  const rows = []
  let row = []
  let field = ''
  let quoted = false

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index]
    if (quoted) {
      if (char === '"' && text[index + 1] === '"') {
        field += '"'
        index += 1
      } else if (char === '"') {
        quoted = false
      } else {
        field += char
      }
    } else if (char === '"') {
      quoted = true
    } else if (char === ',') {
      row.push(field)
      field = ''
    } else if (char === '\n') {
      row.push(field.replace(/\r$/, ''))
      rows.push(row)
      row = []
      field = ''
    } else {
      field += char
    }
  }

  if (field || row.length) {
    row.push(field.replace(/\r$/, ''))
    rows.push(row)
  }
  return rows
}

function normalizePlayer(record) {
  const age = Number.parseInt(record['年龄'], 10)
  const tiCount = Number.parseInt(record['TI次数'], 10)
  const firstValue = value => value?.split(',').map(item => item.trim()).find(Boolean) || ''
  const normalizePositionName = value => {
    const position = value?.trim() || ''
    if (position === 'Offlaner') return 'Offlane'
    if (position.toLowerCase() === 'solo middle') return 'Mid'
    return position
  }
  const normalizePosition = value => {
    const allowedPositions = new Set(['Carry', 'Mid', 'Support', 'Offlane', 'Carry4', 'Carry5', 'Coach'])
    const positions = (value || '').split(',').map(normalizePositionName).filter(Boolean)
    if (allowedPositions.has(positions[0])) return positions[0]
    if (allowedPositions.has(positions[1])) return positions[1]
    return 'Other'
  }
  return {
    id: record['选手ID']?.trim() || '未知',
    team: record['队伍']?.trim() || '',
    country: countryNamesZh[firstValue(record['国籍'])] || firstValue(record['国籍']),
    age: Number.isFinite(age) ? age : null,
    tiCount: Number.isFinite(tiCount) ? tiCount : 0,
    position: positionNamesZh[normalizePosition(record['位置'])] || '其他',
  }
}

export async function loadPlayerData() {
  const response = await fetch('/data/dota2_players.csv')
  if (!response.ok) throw new Error(`选手数据加载失败 (${response.status})`)

  const rows = parseCsvRows(await response.text())
  const headers = rows.shift()?.map(header => header.replace(/^\uFEFF/, '').trim()) || []
  return rows
    .filter(row => row.some(value => value.trim()))
    .map(row => normalizePlayer(Object.fromEntries(headers.map((header, index) => [header, row[index] || '']))))
    .filter(player => player.tiCount > 0)
}
