const playerImageBase = '/players/'

function member(accountId, id, realName, role) {
  return {
    accountId,
    id,
    realName: realName?.trim() || '实名信息待补充',
    role,
    image: `${playerImageBase}${accountId}.png`,
  }
}

export const teamRosters = {
  Falcons: { teamName: 'Team Falcons', members: [member(10366616, 'Sneyking', 'JingJun Wu', '辅助'), member(25907144, 'Cr1t-', 'Andreas Franck Nielsen', '辅助'), member(100058342, 'skiter', 'Oliver Lepko', '核心'), member(183719386, 'AMMAR_THE_F', 'AMMAR SALEH MOUSA ALASSAF', '核心'), member(898455820, 'Malr1ne', 'POTORAK STANISLAV', '中单')] },
  LGD: { teamName: 'LGD Gaming', members: [member(81306398, 'KingJungles', 'MATHEUS SANTOS JUNGLES DINIZ', '辅助'), member(105045291, 'Thiolicor', 'Thiago Oliveira Cordeiro', '辅助'), member(177203952, 'Yuma', 'Yuma Benjamin Langlet', '核心'), member(292921272, 'Wisper', 'Adrian Cespedes Dobles', '核心'), member(94054712, 'Topson', 'Topias Miikka', '中单')] },
  IronWing: { teamName: 'Iron Wing', members: [member(86698277, '33', 'Neta Shapira', '核心'), member(93618577, 'bzm', 'Bozhidar Bogdanov', '中单'), member(136829091, 'Whitemon', 'Matthew Filemon', '辅助'), member(331855530, 'Pure', 'Ivan Moskalenko', '核心'), member(346412363, 'Ari', 'Matthew Walker', '辅助')] },
  Nigma: { teamName: 'Nigma Galaxy', members: [member(101356886, 'GH', 'Maroun Merhej', '辅助'), member(111620041, 'SumaiL-', 'Sumail Syed', '核心'), member(138880576, 'Davai', 'Cedric Alexander Deckmyn', '核心'), member(152168157, 'OmaR', 'Omar Habib Moughrabi', '辅助'), member(210053851, 'lorenof', 'Artem Melnyk', '中单')] },
  BoomBoys: { teamName: 'BoomBoys', members: [member(165564598, 'MieRo', 'Matvei Vasiunin', '核心'), member(172099728, 'Kiritych~', 'Ilia Ulianov', '核心'), member(196878136, 'Kataomi`', 'Vladislav Semenov', '辅助'), member(317880638, 'Save-', 'Vitalie Melnic', '辅助'), member(480412663, 'gpk~', 'Skutin Danil Aleksandrovich', '中单')] },
  OG: { teamName: 'OG', members: [member(100594231, 'skem', 'Rolen Andrei Gabriel Lim Ong', '辅助'), member(132309493, 'Raven', 'Marc Polo Luis Fausto', '核心'), member(155494381, 'TIMS', 'Timothy John Manaloto Randrup', '辅助'), member(324277900, 'Yopaj-', 'Erin Jasper B Ferrer', '中单'), member(355168766, 'Natsumi', 'John Anthony Hortezuela Vargas', '核心')] },
  Vision: { teamName: 'TEAM VISION', members: [member(73401082, 'Dukalis', 'Andrey Kuropatkin', '辅助'), member(106573901, 'No[o]ne-', 'Volodymyr Minenko', '中单'), member(164199202, '9Class', 'Edgar Naltakian', '辅助'), member(195108598, 'Noticed', 'Evgeniy Ignatenko', '核心'), member(1044002267, 'Satanic', 'Alan Gallyamov', '核心')] },
  Resilience: { teamName: 'Team Resilience', members: [member(145957968, 'niu', '李孔博', '核心'), member(150961567, 'planet', '林灏', '辅助'), member(170896543, 'YSR-04E', '杨绍瀚', '核心'), member(249835593, 'zzq', '张子强', '辅助'), member(315272623, 'Echozz', '许子良', '中单')] },
  Spirit: { teamName: 'Team Spirit', members: [member(106305042, 'Larl', 'DENIS SIGITOV', '中单'), member(218231587, 'not_me', 'Alexey Kosmynin', '辅助'), member(302214028, 'Collapse', 'Magomed Khalilov', '核心'), member(321580662, 'Yatoro', 'Illia Muliarchuk', '核心'), member(847565596, 'rue', 'Alexander Filin', '辅助')] },
  XG: { teamName: 'Xtreme Gaming', members: [member(129958758, 'Xxs', 'LIN JING', '核心'), member(898754153, 'Ame', 'WANG CHUNYU', '核心'), member(173978074, 'NothingToSay', 'CHENG JIN XIANG', '中单'), member(94296097, 'xNova', 'YAP JIAN WEI', '辅助'), member(101695162, 'fy', 'XU LINSEN', '辅助')] },
  Liquid: { teamName: 'Team Liquid', members: [member(16497807, 'tOfu', 'Erik Engel', '辅助'), member(77490514, 'Boxi', 'Samuel Svahn', '辅助'), member(97590558, 'Ace', 'Marcus Folke Hoelgaard Christensen', '核心'), member(152962063, 'm1CKe', 'Michael Vu', '核心'), member(201358612, 'Nisha', 'Michal Jankowski', '中单')] },
  Vici: { teamName: 'Vici Gaming', members: [member(111114687, 'y`', 'ZHANG YIPING', '辅助'), member(118134220, 'Bach', 'Ruida Zhang', '核心'), member(137129583, 'Xm', 'Guo Hongcheng', '中单'), member(157475523, 'XinQ', 'ZHAO ZIXING', '辅助'), member(320252024, 'shiro', 'Xuanang Guo', '核心')] },
  Aurora: { teamName: 'Aurora Gaming', members: [member(124801257, 'Nightfall', 'Egor Grigorenko', '核心'), member(126842529, 'Ws`', 'Chung Wei Shen', '核心'), member(256156323, 'Mira', 'Myroslav Kolpakov', '辅助'), member(301750126, 'Mikoto', 'Rafli Fathurrahman', '中单'), member(320219866, 'kaori', 'Oeh Medvedok', '辅助')] },
  GamerLegion: { teamName: 'GamerLegion', members: [member(90423751, 'Bignum', 'Daniil Shekhovtsov', '辅助'), member(154974246, 'RCY', 'Francis Fundemera', '中单'), member(160119017, 'Fayde', 'Victor Zuev', '核心'), member(191362875, 'Speeed', 'Paul Bocchicchio', '辅助'), member(206642367, 'Ghost', 'CHAN KOK HONG', '核心')] },
  Yandex: { teamName: 'Team Yandex', members: [member(56351509, 'DM', 'Dmitrii Dorokhin', '核心'), member(93817671, 'Maladych', 'Arman Orazbayev', '辅助'), member(103735745, 'Saksa', 'Martin Sazdov', '辅助'), member(171262902, 'watson', 'Alimzhan Islambekov', '核心'), member(312436974, 'CHIRA_JUNIOR', 'Ilia', '中单')] },
  Huligani: { teamName: 'HULIGANI', members: [member(92487440, 'Corrupted', 'Ivan German', '核心'), member(123787715, 'RESPECT', 'Yahor Prakurat', '辅助'), member(140251702, 'Mirage`', 'Miras Mutan', '中单'), member(145065875, 'sayuw', 'Oleg Kalenbet', '辅助'), member(320017600, 'ssnovv1', 'Ilia Kondrashov', '核心')] },
}

const countryFlags = {
  Russia: '/flags/54px-Ru_hd.png', China: '/flags/54px-Cn_hd.png', Ukraine: '/flags/54px-Ua_hd.png', Philippines: '/flags/54px-Ph_hd.png', Malaysia: '/flags/54px-My_hd.png',
  'United States': '/flags/54px-Us_hd.png', Kazakhstan: '/flags/54px-Kz_hd.png', Brazil: '/flags/54px-Br_hd.png', Denmark: '/flags/54px-Dk_hd.png', Indonesia: '/flags/54px-Id_hd.png',
  Lebanon: '/flags/54px-Lb_hd.png', Sweden: '/flags/54px-Se_hd.png', Belarus: '/flags/54px-By_hd.png', Belgium: '/flags/54px-Be_hd.png', Bolivia: '/flags/54px-Bo_hd.png', Bulgaria: '/flags/54px-Bg_hd.png',
  Finland: '/flags/54px-Fi_hd.png', Germany: '/flags/54px-De_hd.png', Israel: '/flags/54px-Il_hd.png', Jordan: '/flags/54px-Jo_hd.png', Moldova: '/flags/54px-Md_hd.png', Nicaragua: '/flags/54px-Ni_hd.png',
  'North Macedonia': '/flags/54px-Mk_hd.png', Pakistan: '/flags/54px-Pk_hd.png', Peru: '/flags/54px-Pe_hd.png', Poland: '/flags/54px-Pl_hd.png', Slovakia: '/flags/54px-Sk_hd.png',
  'United Kingdom': '/flags/54px-Gb_hd.png',
}

const playerNationalities = {
  Sneyking: 'United States', 'Cr1t-': 'Denmark', skiter: 'Slovakia', AMMAR_THE_F: 'Jordan', Malr1ne: 'Russia',
  KingJungles: 'Brazil', Thiolicor: 'Brazil', Yuma: 'Nicaragua', Wisper: 'Bolivia', Topson: 'Finland',
  33: 'Israel', bzm: 'Bulgaria', Whitemon: 'Indonesia', Pure: 'Russia', Ari: 'United Kingdom',
  GH: 'Lebanon', 'SumaiL-': 'Pakistan', Davai: 'Belgium', OmaR: 'Lebanon', lorenof: 'Ukraine',
  MieRo: 'Russia', 'Kiritych~': 'Russia', 'Kataomi`': 'Russia', 'Save-': 'Moldova', 'gpk~': 'Russia',
  skem: 'Philippines', Raven: 'Philippines', TIMS: 'Philippines', 'Yopaj-': 'Philippines', Natsumi: 'Philippines',
  Dukalis: 'Russia', 'No[o]ne-': 'Ukraine', '9Class': 'Russia', Noticed: 'Russia', Satanic: 'Russia',
  niu: 'China', planet: 'China', 'YSR-04E': 'China', zzq: 'China', Echozz: 'China',
  Larl: 'Russia', not_me: 'Russia', Collapse: 'Russia', Yatoro: 'Ukraine', rue: 'Russia',
  Xxs: 'China', Ame: 'China', NothingToSay: 'Malaysia', xNova: 'Malaysia', fy: 'China',
  tOfu: 'Germany', Boxi: 'Sweden', Ace: 'Denmark', m1CKe: 'Sweden', Nisha: 'Poland',
  'y`': 'China', Bach: 'China', Xm: 'China', XinQ: 'China', shiro: 'China',
  Nightfall: 'Russia', 'Ws`': 'Malaysia', Mira: 'Ukraine', Mikoto: 'Indonesia', kaori: 'Ukraine',
  Bignum: 'Ukraine', RCY: 'United States', Fayde: 'United States', Speeed: 'United States', Ghost: 'Malaysia',
  DM: 'Russia', Maladych: 'Kazakhstan', Saksa: 'North Macedonia', watson: 'Kazakhstan', CHIRA_JUNIOR: 'Russia',
  Corrupted: 'Russia', RESPECT: 'Belarus', 'Mirage`': 'Kazakhstan', sayuw: 'Russia', ssnovv1: 'Russia',
}

Object.values(teamRosters).flatMap(roster => roster.members).forEach(player => {
  player.country = playerNationalities[player.id] || 'Unknown'
  player.countryFlag = countryFlags[player.country] || null
})

export const rosterRoleOrder = { 核心: 0, 中单: 1, 辅助: 2 }
