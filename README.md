# CC Buddy Hack

Brute-force your CC `/buddy` companion to get the rarity, species, and traits you want.

## Gallery

<p align="center">
  <img src="buddys-pics/dragon-nacreblur.png" width="150" alt="Shiny Legendary Dragon">
  <img src="buddys-pics/cactus-tuffwick.png" width="150" alt="Shiny Legendary Cactus">
  <img src="buddys-pics/cactus-jamber.png" width="150" alt="Shiny Legendary Cactus">
  <img src="buddys-pics/goose-siltica.png" width="150" alt="Shiny Legendary Goose">
  <img src="buddys-pics/owl-glintcrumb.png" width="150" alt="Shiny Legendary Owl">
</p>

## Example: Finding the Perfect Shiny Legendary Dragon

```
$ bun brute.ts legendary dragon --shiny --best
目标: legendary + SHINY + dragon
最大搜索次数: 100,000,000
运行时: Bun (hash 精确匹配)
---
[TOP 1] total=338 dragon (×) hat:wizard ✨ | 0.1s | #154,447
  DEBUGGING=60 PATIENCE=41 CHAOS=53 WISDOM=84 SNARK=100
[TOP 1] total=349 dragon (°) hat:tinyduck ✨ | 0.1s | #181,044
  DEBUGGING=76 PATIENCE=41 CHAOS=76 WISDOM=56 SNARK=100
[TOP 1] total=370 dragon (◉) hat:none ✨ | 0.3s | #679,915
  DEBUGGING=54 PATIENCE=89 CHAOS=40 WISDOM=87 SNARK=100
[TOP 1] total=400 dragon (@) hat:tophat ✨ | 0.6s | #1,581,984
  DEBUGGING=45 PATIENCE=87 CHAOS=100 WISDOM=89 SNARK=79
...
[TOP 1] total=415 dragon (◉) hat:tophat ✨ | 17.8s | #49,298,662
  DEBUGGING=100 PATIENCE=52 CHAOS=89 WISDOM=87 SNARK=87
...
===== Done =====
Searched: 100,000,000 | Time: 36.62s | Found: 10 legendary

Results:
  976ff944-b631-4326-a3a8-19cfbdb2d520  =>  dragon (◉) hat:tophat SHINY total=415
  adc58f2f-0380-48da-858a-2a18d55f97aa  =>  dragon (◉) hat:wizard SHINY total=405
  2aaf2daf-fd36-4cc0-96af-f72da52d3125  =>  dragon (◉) hat:propeller SHINY total=405
  7cb533ed-9301-4863-a9b3-f828813ff16c  =>  dragon (✦) hat:tinyduck SHINY total=403
  e4235272-0ed3-4fce-89b6-fe12022a70d1  =>  dragon (@) hat:tophat SHINY total=400
```

The `--best` flag searches through all 100M UUIDs and keeps the top 10 by total stats. In this run, the best shiny legendary dragon scored **415/421** (theoretical max) — just 6 points short of perfection.

### Stats breakdown

Each companion has 5 stats. The roll algorithm always picks one **peak** stat (boosted) and one **dump** stat (penalized):

| Stat | Legendary range |
|------|----------------|
| Peak | always 100 |
| Normal (×3) | 50–89 each |
| Dump | 40–54 |
| **Theoretical max** | **421** |

## How it works

CC's `/buddy` system generates a companion pet based on a deterministic hash of your `accountUuid` (OAuth users) or `userID` (API key users). The rarity distribution is:

| Rarity    | Weight | Chance |
|-----------|--------|--------|
| Common    | 60     | 60%    |
| Uncommon  | 25     | 25%    |
| Rare      | 10     | 10%    |
| Epic      | 4      | 4%     |
| Legendary | 1      | 1%     |

Shiny variants have an additional 1% chance on top of rarity.

This project includes:
- **`brute.ts`** — Brute-force script that generates random UUIDs and finds ones that produce desired rarities
- **`buddy-patch.sh`** — Wrapper script that permanently swaps your `accountUuid` before launching CC (use `--recover-userid` to restore)

## Prerequisites

- [Bun](https://bun.sh/) runtime (required for exact hash matching with CC)

```bash
brew install oven-sh/bun/bun
```

## Usage

### 1. Find a UUID with your desired rarity

```bash
# Find legendary companions
bun brute.ts legendary

# Find shiny legendary companions
bun brute.ts legendary --shiny

# Filter by species (e.g. dragon, cat, ghost...)
bun brute.ts legendary dragon --shiny

# Find the highest total stats (searches all 100M and keeps top 10)
bun brute.ts legendary dragon --shiny --best

# Other rarities: common, uncommon, rare, epic, legendary
```

### 2. Launch CC with the desired companion

```bash
# Use the default UUID (edit buddy-patch.sh to set your preferred one)
./buddy-patch.sh

# Or specify a UUID directly
./buddy-patch.sh <uuid-from-step-1>

# Use --renew to delete your current companion and force a re-hatch
./buddy-patch.sh <uuid> --renew
```

### 3. Hatch your new companion

Once CC starts, run `/buddy` to hatch a new companion with your chosen traits.

### 4. Restore your original UUID (optional)

The patch is **permanent** — your `accountUuid` stays replaced after exiting CC. To restore:

```bash
./buddy-patch.sh --recover-userid
```

## How buddy-patch.sh works

1. **Before launch**: Saves the original `accountUuid` to `~/.claude-buddy-original-uuid`, then replaces it in `~/.claude.json` with the target UUID
2. **During session**: Background watcher re-patches every 2s (in case OAuth token refresh restores the original)
3. **On exit**: The target UUID is **kept** (no auto-restore). Use `--recover-userid` to manually restore the original

OAuth authentication uses tokens (stored in keychain), not `accountUuid`, so API calls are unaffected.

## Species

duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

## Traits

- **Eyes**: `·` `✦` `×` `◉` `@` `°`
- **Hats**: none, crown, tophat, propeller, halo, wizard, beanie, tinyduck
- **Shiny**: 1% chance (stacks with rarity)

## Note

- Must use **Bun** to run `brute.ts` — Node.js uses a different hash function (FNV-1a vs Bun's wyhash), so results won't match CC
- The salt `friend-2026-401` is hardcoded in CC and may change in future versions
