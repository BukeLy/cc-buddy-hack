#!/usr/bin/env bun

// Buddy 宠物暴力破解脚本
// 用法: bun brute.ts [目标稀有度] [搜索次数]
// 例如: bun brute.ts legendary 10000000

// ---- 从源码复刻的常量和算法 ----

const SPECIES = [
  'duck', 'goose', 'blob', 'cat', 'dragon', 'octopus', 'owl', 'penguin',
  'turtle', 'snail', 'ghost', 'axolotl', 'capybara', 'cactus', 'robot',
  'rabbit', 'mushroom', 'chonk',
] as const

const EYES = ['·', '✦', '×', '◉', '@', '°'] as const
const HATS = ['none', 'crown', 'tophat', 'propeller', 'halo', 'wizard', 'beanie', 'tinyduck'] as const
const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary'] as const
const STAT_NAMES = ['DEBUGGING', 'PATIENCE', 'CHAOS', 'WISDOM', 'SNARK'] as const

type Rarity = (typeof RARITIES)[number]
type StatName = (typeof STAT_NAMES)[number]

const RARITY_WEIGHTS: Record<Rarity, number> = {
  common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1,
}

const RARITY_FLOOR: Record<Rarity, number> = {
  common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50,
}

const SALT = 'friend-2026-401'

// ---- Mulberry32 PRNG ----

function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return function () {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// 与 Claude Code 源码完全一致的 hashString
function hashString(s: string): number {
  if (typeof Bun !== 'undefined') {
    return Number(BigInt(Bun.hash(s)) & 0xffffffffn)
  }
  // FNV-1a fallback (Node 环境，结果会不同)
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

// ---- Roll 逻辑 ----

function pick<T>(rng: () => number, arr: readonly T[]): T {
  return arr[Math.floor(rng() * arr.length)]!
}

function rollRarity(rng: () => number): Rarity {
  const total = Object.values(RARITY_WEIGHTS).reduce((a, b) => a + b, 0)
  let roll = rng() * total
  for (const rarity of RARITIES) {
    roll -= RARITY_WEIGHTS[rarity]
    if (roll < 0) return rarity
  }
  return 'common'
}

function rollStats(rng: () => number, rarity: Rarity): Record<StatName, number> {
  const floor = RARITY_FLOOR[rarity]
  const peak = pick(rng, STAT_NAMES)
  let dump = pick(rng, STAT_NAMES)
  while (dump === peak) dump = pick(rng, STAT_NAMES)

  const stats = {} as Record<StatName, number>
  for (const name of STAT_NAMES) {
    if (name === peak) {
      stats[name] = Math.min(100, floor + 50 + Math.floor(rng() * 30))
    } else if (name === dump) {
      stats[name] = Math.max(1, floor - 10 + Math.floor(rng() * 15))
    } else {
      stats[name] = floor + Math.floor(rng() * 40)
    }
  }
  return stats
}

function rollFull(userId: string) {
  const key = userId + SALT
  const rng = mulberry32(hashString(key))
  const rarity = rollRarity(rng)
  const species = pick(rng, SPECIES)
  const eye = pick(rng, EYES)
  const hat = rarity === 'common' ? 'none' : pick(rng, HATS)
  const shiny = rng() < 0.01
  const stats = rollStats(rng, rarity)
  return { rarity, species, eye, hat, shiny, stats }
}

// ---- 主程序 ----

const isBun = typeof Bun !== 'undefined'
const targetRarity = (process.argv[2] || 'legendary') as Rarity
const shinyOnly = process.argv.includes('--shiny')
const bestMode = process.argv.includes('--best')
const targetSpecies = process.argv.find(a => (SPECIES as readonly string[]).includes(a) && a !== process.argv[2]) || null
const maxAttempts = parseInt(process.argv.find(a => /^\d+$/.test(a) && a !== process.argv[2]) || '100000000', 10)

if (!RARITIES.includes(targetRarity)) {
  console.error(`无效稀有度: ${targetRarity}`)
  console.error(`可选: ${RARITIES.join(', ')}`)
  process.exit(1)
}

console.log(`目标: ${targetRarity}${shinyOnly ? ' + SHINY' : ''}${targetSpecies ? ' + ' + targetSpecies : ''}`)
console.log(`最大搜索次数: ${maxAttempts.toLocaleString()}`)
console.log(`运行时: ${isBun ? 'Bun (hash 精确匹配)' : 'Node (hash 不匹配, 仅供测试)'}`)
console.log(`---`)

type Result = { userId: string; species: string; eye: string; hat: string; shiny: boolean; stats: Record<StatName, number>; total: number }
const results: Result[] = []
const totalStat = (s: Record<StatName, number>) => STAT_NAMES.reduce((a, n) => a + s[n], 0)
const startTime = Date.now()
let checked = 0

// 生成标准 UUID v4 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
function randomUUID(): string {
  const chars = '0123456789abcdef'
  const hex = (n: number) => { let s = ''; for (let i = 0; i < n; i++) s += chars[Math.floor(Math.random() * 16)]; return s }
  const y = '89ab'[Math.floor(Math.random() * 4)]
  return `${hex(8)}-${hex(4)}-4${hex(3)}-${y}${hex(3)}-${hex(12)}`
}

for (let i = 0; i < maxAttempts; i++) {
  const userId = randomUUID()
  const roll = rollFull(userId)
  checked++

  if (roll.rarity === targetRarity && (!shinyOnly || roll.shiny) && (!targetSpecies || roll.species === targetSpecies)) {
    const total = totalStat(roll.stats)

    if (bestMode) {
      // --best 模式：维护 top 10，只在刷新记录时输出
      const worst = results.length >= 10 ? results[results.length - 1].total : 0
      if (results.length < 10 || total > worst) {
        results.push({ userId, ...roll, total })
        results.sort((a, b) => b.total - a.total)
        if (results.length > 10) results.length = 10
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1)
        const shinyTag = roll.shiny ? ' ✨' : ''
        console.log(
          `[TOP ${results.findIndex(r => r.userId === userId) + 1}] total=${total} ${roll.species} (${roll.eye}) ` +
          `hat:${roll.hat}${shinyTag} | ${elapsed}s | #${checked.toLocaleString()}`
        )
        console.log(`  ${STAT_NAMES.map(s => `${s}=${roll.stats[s]}`).join(' ')}`)
      }
    } else {
      results.push({ userId, ...roll, total })
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1)
      const shinyTag = roll.shiny ? ' SHINY!' : ''
      console.log(
        `[#${results.length}] ${roll.rarity} ${roll.species} (${roll.eye}) ` +
        `hat:${roll.hat}${shinyTag} | ${elapsed}s | attempt #${checked.toLocaleString()}`
      )
      console.log(`  userID: ${userId}`)
      console.log(`  stats: ${STAT_NAMES.map(s => `${s}=${roll.stats[s]}`).join(' ')} (total=${total})`)
      console.log()

      const limit = targetRarity === 'legendary' ? 5 : 10
      if (results.length >= limit) break
    }
  }

  if (checked % 1_000_000 === 0) {
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1)
    const rate = (checked / ((Date.now() - startTime) / 1000)).toFixed(0)
    console.log(`... searched ${(checked / 1_000_000).toFixed(0)}M (${elapsed}s, ${rate}/s), found ${results.length}`)
  }
}

const totalTime = ((Date.now() - startTime) / 1000).toFixed(2)
console.log(`===== Done =====`)
console.log(`Searched: ${checked.toLocaleString()} | Time: ${totalTime}s | Found: ${results.length} ${targetRarity}`)

if (results.length > 0) {
  if (bestMode) results.sort((a, b) => b.total - a.total)
  console.log()
  console.log(`Results:`)
  for (const r of results) {
    const shinyTag = r.shiny ? ' SHINY' : ''
    console.log(`  ${r.userId}  =>  ${r.species} (${r.eye}) hat:${r.hat}${shinyTag} total=${r.total}`)
  }
}
