# CC Buddy Hack

Brute-force your CC `/buddy` companion to get the rarity, species, and traits you want.

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
- **`buddy-patch.sh`** — Wrapper script that temporarily swaps your `accountUuid` before launching CC

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

# Find epic companions
bun brute.ts epic

# Other rarities: common, uncommon, rare, epic, legendary
```

### 2. Launch CC with the desired companion

```bash
# Use the default UUID (edit buddy-patch.sh to set your preferred one)
./buddy-patch.sh

# Or specify a UUID directly
./buddy-patch.sh <uuid-from-step-1>
```

### 3. Hatch your new companion

Once CC starts, run `/buddy` to hatch a new companion with your chosen traits.

## How buddy-patch.sh works

1. **Before launch**: Replaces `accountUuid` in `~/.claude.json` with the target UUID
2. **During session**: Background watcher re-patches every 2s (in case OAuth token refresh restores the original)
3. **On exit** (including Ctrl+C): Automatically restores the original `accountUuid`

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
