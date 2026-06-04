# Economy Rewrite v15 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Tycoon Deep Mine economy with a Cookie‑Clicker‑shape design (single bonusSum capped at +300 %, linear ore values, linear HP, uniform ×1.15 cost ladders, single gem prestige, no Cores / no Mastery / no crit / no depth scaling) per the spec at `docs/superpowers/specs/2026-06-04-economy-rewrite-v15-design.md`.

**Architecture:** All work happens on branch `economy-rewrite-v15`. Each task is one commit, ordered to keep the project compiling at every checkpoint. Removals come before rewrites; data model comes before views. There is no XCTest target — verification is `xcodebuild build`, runtime `precondition`s on invariants, and a final manual smoke playtest.

**Tech Stack:** Swift 5 / SwiftUI iOS 17+; Xcode project `Tycoon Deep Mine.xcodeproj`; scheme `Tycoon Deep Mine`; single target, single source folder `Tycoon Deep Mine/`.

**Build verification command (used at every task):**
```bash
cd "/Users/vik/Documents/development/for_human_review_apps/Tycoon Deep Mine"
xcodebuild -project "Tycoon Deep Mine.xcodeproj" \
  -scheme "Tycoon Deep Mine" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build 2>&1 | tail -30
```
Expected: ends in `** BUILD SUCCEEDED **`. Anything else = stop, fix before commit.

---

## Phase A — Cleanups (delete code without breaking the build)

The point of doing deletions first is that every later task touches fewer lines.

### Task 1: Confirm baseline

**Files:** none.

- [ ] **Step 1: Confirm branch**

```bash
cd "/Users/vik/Documents/development/for_human_review_apps/Tycoon Deep Mine"
git branch --show-current
```
Expected: `economy-rewrite-v15`. If not, run `git checkout economy-rewrite-v15`.

- [ ] **Step 2: Confirm baseline build succeeds**

Run the build verification command above. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Skim the spec**

Open `docs/superpowers/specs/2026-06-04-economy-rewrite-v15-design.md` and read §§ 2, 3, 11. They are the contract for every task below.

No commit (just confirmation).

---

### Task 2: Remove the Cores tab from RootTabView

**Files:**
- Modify: `Tycoon Deep Mine/RootTabView.swift`

- [ ] **Step 1: Locate the Cores tab entry**

Open `RootTabView.swift`. Find the tab list (around lines 14–31 — the `switch tab {}` and the tab enum). Identify the case that renders `CoresView()` and the corresponding tab-bar item.

- [ ] **Step 2: Delete the Cores case + its tab-bar entry**

Remove:
1. The enum case `.cores` (or whichever spelling) from the local tab enum.
2. The `case .cores: CoresView()` line from the body switch.
3. The bottom-bar item that picks `.cores`.

Verify no other site references `.cores`.

- [ ] **Step 3: Build**

Run the build verification command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Tycoon\ Deep\ Mine/RootTabView.swift
git commit -m "remove Cores tab from RootTabView (v15 wipe step 1)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Remove the Mastery tab from RootTabView

**Files:**
- Modify: `Tycoon Deep Mine/RootTabView.swift`

- [ ] **Step 1: Repeat Task 2 for Mastery**

Same procedure: delete the Mastery tab enum case, its `case .mastery: MasteryView()` in the body switch, and its tab-bar item.

- [ ] **Step 2: Build**

Build verification. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Tycoon\ Deep\ Mine/RootTabView.swift
git commit -m "remove Mastery tab from RootTabView (v15 wipe step 2)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Delete CoresView.swift and MasteryView.swift

**Files:**
- Delete: `Tycoon Deep Mine/CoresView.swift`
- Delete: `Tycoon Deep Mine/MasteryView.swift`

- [ ] **Step 1: Remove file references from Xcode project**

Open `Tycoon Deep Mine.xcodeproj/project.pbxproj` in a text editor (or with Xcode UI). Remove every occurrence of `CoresView.swift` and `MasteryView.swift` (3 entries each: file reference, group child, build-phase source).

- [ ] **Step 2: Delete the source files**

```bash
cd "/Users/vik/Documents/development/for_human_review_apps/Tycoon Deep Mine"
rm "Tycoon Deep Mine/CoresView.swift" "Tycoon Deep Mine/MasteryView.swift"
```

- [ ] **Step 3: Build**

Build verification. If `Cannot find 'CoresView' in scope`, you missed a reference in Task 2 or 3 — go fix. Expected when clean: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "delete CoresView and MasteryView source files

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: Delete the Cores enum, meta-perk data, tectonicShift code

**Files:**
- Modify: `Tycoon Deep Mine/Systems.swift` (lines 11–19 + meta perk catalog)
- Modify: `Tycoon Deep Mine/Store.swift` (multiple sites — see Step 1)
- Modify: `Tycoon Deep Mine/GameModel.swift` (Cores‑related @Published fields)

- [ ] **Step 1: Find every Cores reference**

```bash
cd "/Users/vik/Documents/development/for_human_review_apps/Tycoon Deep Mine"
grep -rn -E "metaTree|DDMMetaKind|tectonicShift|pendingCores|coresLifetime|gemsClaimedForCores|collapsesClaimedForCores|forceCore|goldVein|gemResonance|deepStart|autoArm|smelterCore|headStart|\\.research(?!View)" \
  "Tycoon Deep Mine/" | grep -v "//"
```
Note every file:line hit. Expect ~30–50 hits across Store.swift, Systems.swift, GameModel.swift, AwardsView.swift, MoreView.swift.

- [ ] **Step 2: Delete `DDMMetaKind` enum + meta perks catalog**

In `Systems.swift` lines 11–19, delete the entire `enum DDMMetaKind` declaration and its perk catalog struct (the one declaring base cost, growth, effect for each meta perk). Delete any helper like `metaPerk(for:)`.

- [ ] **Step 3: Delete Cores state in GameModel**

In `GameModel.swift`, delete:
- `@Published var cores`
- `@Published var coresLifetime` (or equivalent)
- `@Published var metaTree: [DDMMetaKind: Int]`
- `var gemsClaimedForCores`
- `var totalCollapses` ONLY IF it is exclusively used by Cores (verify — if not used by achievements, remove; if used by achievements, keep)
- `var collapsesClaimedForCores`
- Any `func tectonicShift()` or related.

- [ ] **Step 4: Strip Cores from Store.swift**

In `Store.swift`:
- Lines 64–84: in the `bonusSum` calculation, **delete** every term referencing `forceCore`, `goldVein`, `metaTree[...]`. (We will fully rewrite `bonusSum` in Task 11; for now, just delete the Cores‑sourced terms so the build compiles.)
- Lines 186–201 and any spot that branches on `metaTree[.something]`: delete.
- Lines 828–836: delete `pendingCores` computed property.
- Lines 843–868: delete the `tectonicShift()` function entirely.
- Save/load: delete cores/metaTree decode lines (we will rewrite migration in Task 18; for now drop them).
- Adjust `pendingGems` (lines 755–761) to drop the `(1 + metaLevel(.gemResonance) * 0.08)` factor. Leave the rest alone — Task 15 rewrites this.

- [ ] **Step 5: Strip Cores from supporting views**

In `MoreView.swift`, `AwardsView.swift`, and anywhere else, delete any HUD line that reads `cores`, `coresLifetime`, or `metaTree`. If a view becomes empty, delete the file (Task 4 pattern).

- [ ] **Step 6: Build**

Build verification. Fix any straggler reference. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "strip Cores prestige + meta tree from data model

Removes DDMMetaKind, metaTree, pendingCores, tectonicShift,
forceCore/goldVein/gemResonance/etc. perks. Single prestige
layer (gems) survives. Spec §3.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: Delete per-ore Mastery

**Files:**
- Modify: `Tycoon Deep Mine/Systems.swift` (mastery cost/effect code)
- Modify: `Tycoon Deep Mine/Store.swift` (lines 174–177, mastery purchase code)
- Modify: `Tycoon Deep Mine/GameModel.swift` (oreMastery field)

- [ ] **Step 1: Find Mastery references**

```bash
grep -rn -E "oreMastery|masteryCost|masteryLevel" "Tycoon Deep Mine/"
```

- [ ] **Step 2: Delete Mastery state**

In `GameModel.swift`: delete `@Published var oreMastery: [OreTier: Int]` (or however it’s spelled).

In `Systems.swift` lines 181–189: delete the mastery cost/effect block.

In `Store.swift` lines 174–177: in `oreUnitValue(for:)`, delete `+ Double(oreMastery[ore] ?? 0) * 0.05` (or whatever the additive term is). Also delete any `func buyMastery` / `masteryCost` function.

- [ ] **Step 3: Build**

Build verification. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "strip per-ore mastery system (v15)

Per-ore +5%/level mastery removed — it was an additional
multiplier chain on ore value. Spec §3.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: Delete crit, depth-scaling, ore-amount perks, and dead upgrade catalog entries

**Files:**
- Modify: `Tycoon Deep Mine/GameModel.swift` (upgrade enum lines 232–246, globals enum lines 317–329)
- Modify: `Tycoon Deep Mine/Store.swift` (crit code 321–328 + 388–408, ore-amount uses, etc.)

- [ ] **Step 1: Identify the cases to remove from the upgrade kinds enum**

Upgrade kinds enum (`GameModel.swift:232-246`). Cases to **delete**:
- `.dynamite`
- `.elevator`
- `.drillEfficiency`  (we consolidate into Drill Tuning)
- `.goldFind`
- `.depthScaling`

Cases to **keep** (will be reworked in Tasks 12–13):
- `.pickaxe`, `.drillCount`, `.drillSpeed`, `.cart`, `.oreValue`, `.refiner`, `.autoTapper`, `.multiTap`

- [ ] **Step 2: Identify the cases to remove from the globals enum**

Globals enum (`GameModel.swift:317-329`). Cases to **delete**:
- `.yieldBoost`
- `.tapCrit`
- `.critPower`
- `.treasureLuck`
- `.oreMagnet`
- `.researchRate`
- `.smeltSpeed`

Cases to **keep** (will be reworked in Task 14):
- `.startDepth`  → renamed “Shaft Head Start”
- `.offlineCap`  → renamed “Night Shift”
- `.autoStart`   → renamed “Standing Drill”
- `.startGold`   → renamed “Seed Vault”

Also **add** at the same time: `.widePan` (rename of nothing — this is new; +1 cart level at run start).

- [ ] **Step 3: Delete the enum cases listed above**

Edit `GameModel.swift`: remove each named case. Do NOT yet touch the surviving cases’ effect/cost — Tasks 12–14 do that.

- [ ] **Step 4: Delete every now-dangling reference**

For each removed case, run

```bash
grep -rn "\\.dynamite\\b\\|\\.elevator\\b\\|\\.drillEfficiency\\b\\|\\.goldFind\\b\\|\\.depthScaling\\b\\|\\.yieldBoost\\b\\|\\.tapCrit\\b\\|\\.critPower\\b\\|\\.treasureLuck\\b\\|\\.oreMagnet\\b\\|\\.researchRate\\b\\|\\.smeltSpeed\\b" "Tycoon Deep Mine/"
```

Delete every line returned. Specifically:
- `Store.swift:76-78` — delete the depth‑scaling contribution from damage bonus sum.
- `Store.swift:321-328` — delete `critChance` / `critMultiplier` computed properties.
- `Store.swift:388-408` — in `tapDig()`, delete the crit-roll branch; just apply `tapDamage` flat per strike.
- `Store.swift:461-467` — delete `oreAmountMultiplier`; ore drop amount is always exactly 1 unit.
- `Store.swift:596-607` — delete the `treasureLuck` extra-roll branch; keep the base 3.5 % treasure chance (it pays rubble bonus only — no gems from treasure).

- [ ] **Step 5: Build**

Build verification. Fix straggler references. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "delete crit, depth scaling, ore-amount perks, dead upgrades (v15)

Removes: dynamite, elevator, drillEfficiency, goldFind, depthScaling
upgrades; yieldBoost, tapCrit, critPower, treasureLuck, oreMagnet,
researchRate, smeltSpeed globals; crit code path; oreAmountMultiplier.
Spec §10.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase B — Core data model rewrite

### Task 8: Rewrite OreTier table to 10 linear-value tiers

**Files:**
- Modify: `Tycoon Deep Mine/GameModel.swift` (OreTier enum, declaration around line 5, value table 47–65)

- [ ] **Step 1: Replace OreTier enum cases**

Open `GameModel.swift` and locate the `OreTier` enum (around line 5). Replace the enum case list with exactly these ten cases, in this order:

```swift
enum OreTier: Int, CaseIterable, Codable, Hashable {
    case coal = 0
    case copper
    case tin
    case iron
    case silver
    case gold
    case ruby
    case emerald
    case sapphire
    case diamond
}
```

(Remove mithril, obsidian, adamantite, voidstone, starmetal, aetherium.)

- [ ] **Step 2: Replace `baseValue` table**

Replace the body of the `baseValue` computed property (currently lines 47–65) with:

```swift
var baseValue: Double {
    switch self {
    case .coal: return 1
    case .copper: return 2
    case .tin: return 3
    case .iron: return 4
    case .silver: return 5
    case .gold: return 6
    case .ruby: return 7
    case .emerald: return 8
    case .sapphire: return 9
    case .diamond: return 10
    }
}
```

- [ ] **Step 3: Replace `unlockDepth` table**

Replace the unlockDepth table with the spec values (§ 6):

```swift
var unlockDepth: Int {
    switch self {
    case .coal: return 0
    case .copper: return 100
    case .tin: return 220
    case .iron: return 400
    case .silver: return 650
    case .gold: return 1000
    case .ruby: return 1500
    case .emerald: return 2200
    case .sapphire: return 3100
    case .diamond: return 4200
    }
}
```

- [ ] **Step 4: Update display names**

If the OreTier has a `displayName` computed property, drop the removed tiers from the switch.

- [ ] **Step 5: Build**

Build verification. Any `Cannot find '.mithril'` etc. = leftover reference; grep & delete. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "rewrite OreTier table: 10 tiers, linear value 1..10

Replaces 16 tiers x1.4 with 10 tiers +1.0 (spec §2,4,6).
Unlock depths aligned to zone boundaries.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 9: Rewrite Zones table (10 zones, no multipliers)

**Files:**
- Modify: `Tycoon Deep Mine/GameModel.swift` (Zones struct around line 125, table 141–230)

- [ ] **Step 1: Replace the static zone table**

In `GameModel.swift`, replace the entire `Zone.all` array (currently `static let all: [Zone] = [...]` at lines 141–230) with exactly these ten entries:

```swift
static let all: [Zone] = [
    Zone(index: 0, name: "Surface",          startDepth: 0,    endDepth: 100,  hpMult: 1, goldMult: 1),
    Zone(index: 1, name: "Stone Shelf",      startDepth: 100,  endDepth: 220,  hpMult: 1, goldMult: 1),
    Zone(index: 2, name: "Crystal Caverns",  startDepth: 220,  endDepth: 400,  hpMult: 1, goldMult: 1),
    Zone(index: 3, name: "Magma Veins",      startDepth: 400,  endDepth: 650,  hpMult: 1, goldMult: 1),
    Zone(index: 4, name: "Abyss",            startDepth: 650,  endDepth: 1000, hpMult: 1, goldMult: 1),
    Zone(index: 5, name: "World's Core",     startDepth: 1000, endDepth: 1500, hpMult: 1, goldMult: 1),
    Zone(index: 6, name: "Mantle Forge",     startDepth: 1500, endDepth: 2200, hpMult: 1, goldMult: 1),
    Zone(index: 7, name: "Void Rift",        startDepth: 2200, endDepth: 3100, hpMult: 1, goldMult: 1),
    Zone(index: 8, name: "Stellar Vault",    startDepth: 3100, endDepth: 4200, hpMult: 1, goldMult: 1),
    Zone(index: 9, name: "Aether Wellspring",startDepth: 4200, endDepth: 99_999_999, hpMult: 1, goldMult: 1),
]
```

If the `Zone` struct does not currently have `goldMult`, do NOT add it — drop the field from this table and the struct definition (it’s defunct under spec §6).

- [ ] **Step 2: Confirm zone HP/gold multiplier sites read only `1.0`**

Grep:
```bash
grep -rn "hpMult\|goldMult" "Tycoon Deep Mine/"
```
Every read should now be `× 1.0` — confirm by inspection. If `Zone` no longer has `goldMult`, every reading site must be deleted.

- [ ] **Step 3: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "rewrite Zones table: 10 zones, no per-zone multipliers

Spec §6. Each zone unlocks one ore tier; HP scaling handled
by linear depth formula only.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 10: Rewrite Block HP, boss multiplier, rubble formulas

**Files:**
- Modify: `Tycoon Deep Mine/GameModel.swift` (HP formula 544–556, rubble 575–578, boss flag 582–591)

- [ ] **Step 1: Replace the HP computation**

Locate the function that computes block HP (around 544–556). Replace its body with:

```swift
// Spec §4: HP = 20 + 2 * depth. Boss block = x4.
let baseHP = 20.0 + 2.0 * Double(depth)
let isBoss = (depth == zone.endDepth - 1)
let hp = baseHP * (isBoss ? 4.0 : 1.0)
return hp
```

If the existing signature returns `Int`, cast as `Int(hp)`.

- [ ] **Step 2: Replace the rubble (gold per block) computation**

Around line 575 the current code does `rubble = 1 + depth * 2`. Replace with:

```swift
// Spec §4: rubble = 1 + depth. Boss adds 2 * (1 + depth).
let baseRubble = 1.0 + Double(depth)
let bossBonus  = isBoss ? 2.0 * baseRubble : 0
let rubble = baseRubble + bossBonus
```

Adjust the caller path so it does NOT separately add a boss bonus elsewhere (drop the boss‑gold lines 582–591 entirely if they’re a separate site).

- [ ] **Step 3: Drop treasure / geode gem rewards**

Around lines 596–607, the geode roll may award a gem. Per spec §6 it must not. Edit the geode branch so it awards only the rubble × 2 + depth × 3 gold bonus, no gems.

- [ ] **Step 4: Add a runtime invariant**

At the top of the HP function, add:

```swift
precondition(depth >= 0, "depth must be non-negative")
```

- [ ] **Step 5: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "linear HP, linear rubble, boss x4, no in-run gem drops

HP = 20 + 2*depth. Rubble = 1 + depth. Boss block multiplies
both by 4 (HP) / +2x base rubble (gold). Treasure no longer
awards gems. Spec §4, §6.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 11: Unify into a single `bonusSum` with hard cap

**Files:**
- Modify: `Tycoon Deep Mine/Store.swift` (lines 64–91, every callsite of `goldBonusSum` / `damageBonusSum`)

- [ ] **Step 1: Find every callsite**

```bash
grep -rn "goldBonusSum\|damageBonusSum" "Tycoon Deep Mine/"
```
Expect ~10–15 hits.

- [ ] **Step 2: Replace the two computed properties with one**

Replace the `goldBonusSum` and `damageBonusSum` computed properties (currently 64–91) with a **single** computed property:

```swift
/// Spec §2/4: the only multiplicative bucket on gold AND damage.
/// Hard-capped at +300 % (= ×4.0 final multiplier).
var bonusSum: Double {
    let oreGrader = Double(upgradeLevel[.oreValue] ?? 0) * 0.05
    let refiner   = Double(upgradeLevel[.refiner]  ?? 0) * 0.03
    let sharpTools = Double(techLevel[.sharpTools] ?? 0) * 0.01
    let veinMapping = Double(techLevel[.veinMapping] ?? 0) * 0.01
    let gemBonus   = Double(gemsLifetime) * 0.005
    let raw = oreGrader + refiner + sharpTools + veinMapping + gemBonus
    return min(raw, 3.0)
}

/// Convenience: the final multiplier itself.
var bonusMultiplier: Double { 1.0 + bonusSum }
```

(Note: this references `.sharpTools` and `.veinMapping`, which Task 16 introduces. Until then, comment-out those two lines OR define stubs that return 0. Recommended: do this:)

```swift
let sharpTools  = 0.0  // wired in Task 16
let veinMapping = 0.0  // wired in Task 16
```

…and replace them in Task 16.

- [ ] **Step 3: Update every callsite**

Every spot that previously multiplied by `(1 + goldBonusSum)` must now multiply by `bonusMultiplier`. Every spot that previously multiplied by `(1 + damageBonusSum)` likewise.

Key sites (file:line approximate):
- `Store.swift:101-106` (tapDamage): change `… * (1 + damageBonusSum)` → `… * bonusMultiplier`.
- `Store.swift:127-136` (autoDPS): same.
- `Store.swift:148-151` (autoTapDPS): same.
- `Store.swift:174-178` (oreUnitValue): same — `* (1 + goldBonusSum)` → `* bonusMultiplier`.
- `Store.swift:266-272` (barUnitValue): same.
- `Store.swift:474` (boss/treasure bonus gold), `Store.swift:505` (milestone reward), `Store.swift:987` (rubble apply): same.

- [ ] **Step 4: Add a runtime invariant**

At the bottom of `bonusSum`’s body (just before `return`), add `precondition(raw >= 0)` and `precondition(min(raw, 3.0) <= 3.0)`. These will fire if any future code accidentally introduces a negative or unbounded term.

- [ ] **Step 5: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual debug check**

In `MoreView.swift` (or wherever the Debug section is), add one debug `Text("bonusSum: \(bonusSum, specifier: "%.2f") / 3.00")` so the engineer can eyeball the cap during smoke tests. Mark with `#if DEBUG`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "unify bonusSum (single cap +300%), drop dual buckets

Replaces goldBonusSum + damageBonusSum with one bonusSum,
capped at 3.0 (final mult x4.0). Applied uniformly to tap,
auto, ore, bar, boss, treasure, milestone. Sharp Tools and
Vein Mapping contributions stubbed to 0 until Task 16.
Debug HUD line added. Spec §2.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase C — Upgrade catalog, globals shop, gems formula

### Task 12: Rewrite gold-bought upgrade catalog (8 upgrades, ×1.15 cost)

**Files:**
- Modify: `Tycoon Deep Mine/Store.swift` (`baseCost(for:)`, `costGrowth(for:)`, effect-per-level lookups for upgrades)

- [ ] **Step 1: Rewrite `baseCost(for:)` to spec values**

Find the function returning base cost per upgrade kind. Replace its body with exactly:

```swift
func baseCost(for kind: UpgradeKind) -> Double {
    switch kind {
    case .pickaxe:    return 10
    case .drillCount: return 50
    case .drillSpeed: return 250    // Drill Tuning
    case .cart:       return 150
    case .oreValue:   return 500    // Ore Grader
    case .refiner:    return 2_500
    case .autoTapper: return 5_000  // Auto Pick
    case .multiTap:   return 100_000
    }
}
```

- [ ] **Step 2: Rewrite `costGrowth(for:)`**

```swift
func costGrowth(for kind: UpgradeKind) -> Double {
    return 1.15  // Spec §2: uniform ladder, no exception.
}
```

- [ ] **Step 3: Rewrite `maxLevel(for:)`**

```swift
func maxLevel(for kind: UpgradeKind) -> Int {
    switch kind {
    case .multiTap: return 5
    default: return 9_999
    }
}
```

- [ ] **Step 4: Rewrite effect math**

In `tapDamage` (Store.swift:101–106):

```swift
var tapDamage: Double {
    let pickaxe = Double(upgradeLevel[.pickaxe] ?? 0)
    let baseTap = 1.0 + pickaxe * 1.0   // +1 dmg per level
    return baseTap * bonusMultiplier
}
```

In `autoDPS` (Store.swift:127–136):

```swift
var autoDPS: Double {
    let count   = Double(upgradeLevel[.drillCount] ?? 0)
                + Double(globalLevel[.autoStart] ?? 0) * 2.0  // perm shop adds free drills (Task 14)
    let perDrill = 0.5 + Double(upgradeLevel[.drillSpeed] ?? 0) * 0.2
    return count * perDrill * bonusMultiplier
}
```

In `autoTapDPS` (Store.swift:148–151):

```swift
var autoTapDPS: Double {
    let rate = Double(upgradeLevel[.autoTapper] ?? 0) * 0.2
    return rate * tapDamage   // tapDamage already includes bonusMultiplier
}
```

In `cartRate` (Store.swift:305–311):

```swift
var cartRate: Double {
    let level = Double(upgradeLevel[.cart] ?? 0)
                + Double(globalLevel[.widePan] ?? 0) * 1.0
    let techBonus = Double(techLevel[.cartLogistics] ?? 0) * 0.1   // Task 16
    return level * 0.5 + techBonus
}

var cartCapacity: Int {
    return 20 + 5 * (Int(upgradeLevel[.cart] ?? 0) + Int(globalLevel[.widePan] ?? 0))
}
```

Multi-strike wiring in `tapDig()` (Store.swift:378–408):

```swift
func tapDig() {
    let strikes = 1 + Int(upgradeLevel[.multiTap] ?? 0)  // L0 = 1 strike, L5 = 6
    let damagePerStrike = tapDamage
    for _ in 0..<strikes {
        applyDamageToCurrentBlock(damagePerStrike)
    }
}
```

(Adjust the `applyDamageToCurrentBlock` call to match the existing helper name.)

- [ ] **Step 5: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "rewrite gold-bought upgrade catalog (8 entries, x1.15)

Pickaxe (10/+1 tap), Drill Rig (50/+1 drill), Drill Tuning
(250/+0.2 base per drill), Mine Cart (150/+0.5 ore/s +5 cap),
Ore Grader (500/+5% bonusSum), Refiner (2500/+3% bonusSum),
Auto Pick (5000/+0.2 tap/s), Multi-Strike (100k/+1 strike, cap 5).
Spec §5.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 13: Rename / relabel surviving upgrades in the UI

**Files:**
- Modify: `Tycoon Deep Mine/UpgradesView.swift`
- Modify: `Tycoon Deep Mine/Store.swift` (display names if held there)

- [ ] **Step 1: Update title and description strings**

For every surviving upgrade, set display name + one-line description to spec §5 wording. Specifically:

| kind | title | description |
|---|---|---|
| .pickaxe | "Pickaxe Power" | "+1 tap damage" |
| .drillCount | "Drill Rig" | "+1 drill" |
| .drillSpeed | "Drill Tuning" | "+0.2 base DPS per drill" |
| .cart | "Mine Cart" | "+0.5 ore/s, +5 cart capacity" |
| .oreValue | "Ore Grader" | "+5% bonus (capped at +300%)" |
| .refiner | "Refiner" | "+3% bonus (capped at +300%)" |
| .autoTapper | "Auto Pick" | "+0.2 auto-taps/sec" |
| .multiTap | "Multi-Strike" | "+1 strike per tap (max 6 total)" |

- [ ] **Step 2: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "update upgrade display strings to v15 spec (§5)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 14: Rewrite globals into permanent gem shop (linear costs)

**Files:**
- Modify: `Tycoon Deep Mine/GameModel.swift` (globals enum 317–329)
- Modify: `Tycoon Deep Mine/Store.swift` (`globalBaseCost(for:)`, `globalCost(for:level:)`, `globalMaxLevel(for:)`, application sites)
- Modify: `Tycoon Deep Mine/CollapseView.swift` (display)

- [ ] **Step 1: Confirm globals enum cases**

After Task 7, the globals enum should contain exactly: `.startDepth, .offlineCap, .autoStart, .startGold, .widePan`. Add `.widePan` if not yet present.

- [ ] **Step 2: Replace cost / max-level functions**

```swift
func globalBaseCost(for kind: GlobalKind) -> Int {
    switch kind {
    case .startDepth: return 30
    case .autoStart:  return 60
    case .widePan:    return 100
    case .offlineCap: return 50
    case .startGold:  return 40
    }
}

/// Spec §7: linear cost ladder. cost(level) = baseCost * (level + 1)
func globalCost(for kind: GlobalKind, atLevel level: Int) -> Int {
    return globalBaseCost(for: kind) * (level + 1)
}

func globalMaxLevel(for kind: GlobalKind) -> Int {
    switch kind {
    case .startDepth: return 10
    case .autoStart:  return 10
    case .widePan:    return 5
    case .offlineCap: return 8
    case .startGold:  return 10
    }
}
```

- [ ] **Step 3: Replace application sites**

For each global, find where it influences gameplay and replace with spec §7:

- `.startDepth`: on run start, `currentDepth = max(currentDepth, 20 * Int(globalLevel[.startDepth] ?? 0))`.
- `.autoStart`: already wired in Task 12’s `autoDPS` (`+ globalLevel[.autoStart] * 2`).
- `.widePan`: already wired in Task 12’s `cartRate` and `cartCapacity`.
- `.offlineCap`: in offline credit code, `maxHours = 2 + 2 * Int(globalLevel[.offlineCap] ?? 0)` (cap 18 = 2 + 16).
- `.startGold`: on run start, `gold += 500 * Int(globalLevel[.startGold] ?? 0)`.

- [ ] **Step 4: Update display strings in CollapseView**

Set the per-perk label / cost-line strings per spec §7 table. Show current level / max as `(L 3 / 10)`.

- [ ] **Step 5: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "rewrite gem permanent shop (5 perks, linear cost)

Shaft Head Start (+20 depth, cap 10), Standing Drill (+1 drill,
cap 10), Wide Pan (+1 cart, cap 5), Night Shift (+2h offline,
cap 8), Seed Vault (+500 gold start, cap 10). Linear cost
ladder per spec §7.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 15: Rewrite gem-award formula and collapse trigger

**Files:**
- Modify: `Tycoon Deep Mine/Store.swift` (pendingGems 755–761, collapse trigger)

- [ ] **Step 1: Replace `pendingGems`**

```swift
/// Spec §7: sub-linear so long runs cannot farm explosively.
var pendingGems: Int {
    let m = max(0, runMaxDepth)
    guard m >= 100 else { return 0 }   // can only collapse after Z1 boss
    let raw = pow(Double(m) / 100.0, 0.7)
    return Int(floor(raw))
}
```

- [ ] **Step 2: Update collapse availability**

Wherever the “Collapse” button enables (likely in `CollapseView`), gate it on `pendingGems >= 1`.

- [ ] **Step 3: Rewrite the collapse routine**

In `collapse()` (the function previously around 789–820), the behavior must match spec §7:

```swift
func collapse() {
    gemsLifetime += pendingGems
    runMaxDepth = 0
    // Reset run-scoped state:
    gold = 0
    currentDepth = 0
    currentOre.removeAll()
    currentBars.removeAll()
    upgradeLevel.removeAll()
    smelterLevel.removeAll()
    techLevel.removeAll()
    // Apply permanent shop on restart:
    applyPermanentPerksOnRunStart()
    persist()
}

private func applyPermanentPerksOnRunStart() {
    currentDepth = 20 * (globalLevel[.startDepth] ?? 0)
    gold = Double(500 * (globalLevel[.startGold] ?? 0))
}
```

Note: tech levels are wiped per spec §7 (research persists across collapse? — spec §8 explicitly says it **persists**). Correction: do NOT wipe `techLevel`. Remove `techLevel.removeAll()`.

- [ ] **Step 4: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Verify the formula by hand**

The plan engineer should hand-check the formula in a Swift REPL or inline `print`:

```swift
print(Int(floor(pow(100.0 / 100.0, 0.7))))  // expect 1
print(Int(floor(pow(500.0 / 100.0, 0.7))))  // expect 3
print(Int(floor(pow(1000.0 / 100.0, 0.7)))) // expect 5
print(Int(floor(pow(5000.0 / 100.0, 0.7)))) // expect 16
print(Int(floor(pow(20000.0 / 100.0, 0.7))))// expect 44
```

If any value disagrees with spec §7, stop and reconcile.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "single-prestige gem formula + collapse routine

gems = floor((maxDepth/100)^0.7), gated on depth>=100.
Collapse resets run + upgrades + smelter, keeps research +
permanent perks + lifetime gems. Spec §7.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase D — Research + Smelter simplification

### Task 16: Rewrite Research (4 techs, persists across collapse)

**Files:**
- Modify: `Tycoon Deep Mine/Systems.swift` (DDMTechKind enum 77–85)
- Modify: `Tycoon Deep Mine/Store.swift` (RP accrual, tech cost/effect lookups, bonusSum stubs)
- Modify: `Tycoon Deep Mine/ResearchView.swift` (display)

- [ ] **Step 1: Rewrite the tech enum**

Replace `DDMTechKind` in `Systems.swift` lines 77–85 with exactly:

```swift
enum DDMTechKind: String, CaseIterable, Codable, Hashable {
    case sharpTools     // +1% bonusSum / level
    case veinMapping    // +1% bonusSum / level
    case cartLogistics  // +0.1 ore/s / level (direct, not via bonusSum)
    case smeltScience   // +0.2 ore/s / level inside smelter (direct)
}
```

(Removes turboDrills, assayers, deepScan, efficiency, smelting, oreRichness, logistics.)

- [ ] **Step 2: Rewrite tech cost / max-level**

```swift
func techBaseCost(for kind: DDMTechKind) -> Double {
    switch kind {
    case .sharpTools:    return 10
    case .veinMapping:   return 12
    case .cartLogistics: return 15
    case .smeltScience:  return 20
    }
}
func techCostGrowth(for kind: DDMTechKind) -> Double { 1.20 }
func techMaxLevel(for kind: DDMTechKind) -> Int { 30 }
```

- [ ] **Step 3: Wire `.sharpTools` and `.veinMapping` into `bonusSum`**

Open `Store.swift` and find the `bonusSum` we wrote in Task 11. Replace the two stub lines:

```swift
let sharpTools  = 0.0
let veinMapping = 0.0
```

with:

```swift
let sharpTools  = Double(techLevel[.sharpTools] ?? 0)  * 0.01
let veinMapping = Double(techLevel[.veinMapping] ?? 0) * 0.01
```

- [ ] **Step 4: Wire `.cartLogistics` into `cartRate`**

Already done in Task 12 — confirm the `cartLogistics` term is present and uses 0.1 per level.

- [ ] **Step 5: Replace RP accrual formula**

Find the RP earn site (current formula `depth^1.25 * 0.5 * researchRateMultiplier`). Replace with:

```swift
// Spec §8: slow linear trickle.
let rpPerSecond = Double(currentDepth) / 50.0
researchPoints += rpPerSecond * delta
```

- [ ] **Step 6: Verify research is NOT wiped on collapse**

Re-open the `collapse()` function from Task 15. Confirm `techLevel.removeAll()` is **absent**. `researchPoints` should NOT be reset either. Spec §8 is explicit.

- [ ] **Step 7: Update ResearchView strings**

Set titles/descriptions for the 4 techs per spec §8.

- [ ] **Step 8: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "rewrite research: 4 techs, persists across collapse

Sharpened Tools / Vein Mapping (each +1% bonusSum), Cart
Logistics (+0.1 ore/s direct), Smelt Science (+0.2 ore/s
in smelter direct). RP rate = depth/50 per second. Cost
x1.20, cap level 30 each. Spec §8.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 17: Simplify Smelter to one upgrade + flat bar value

**Files:**
- Modify: `Tycoon Deep Mine/Systems.swift` (SmelterKind enum 142–145, catalog 162–170)
- Modify: `Tycoon Deep Mine/Store.swift` (smelter rate 249–255, bar value 266–272)
- Modify: `Tycoon Deep Mine/SmelterView.swift` (display)

- [ ] **Step 1: Collapse the SmelterKind enum to a single case**

In `Systems.swift` lines 142–145:

```swift
enum SmelterKind: String, CaseIterable, Codable, Hashable {
    case furnace    // +0.5 ore/s, base 8000 gold, x1.15
}
```

(Drop `.barValue` and `.batch`.)

- [ ] **Step 2: Rewrite smelter rate**

In `Store.swift` lines 249–255:

```swift
var smelterRate: Double {
    let base = 0.5
    let furnace = Double(smelterLevel[.furnace] ?? 0) * 0.5
    let science = Double(techLevel[.smeltScience] ?? 0) * 0.2
    return base + furnace + science
}
```

- [ ] **Step 3: Rewrite bar value**

In `Store.swift` lines 266–272:

```swift
/// Spec §9: flat 2x ore base value. No purity / smelterCore chain.
func barUnitValue(for ore: OreTier) -> Double {
    return ore.baseValue * 2.0 * bonusMultiplier
}
```

- [ ] **Step 4: Rewrite smelter upgrade cost**

```swift
func smelterBaseCost(for kind: SmelterKind) -> Double {
    return 8_000   // furnace only
}
func smelterCostGrowth(for kind: SmelterKind) -> Double { 1.15 }
func smelterMaxLevel(for kind: SmelterKind) -> Int { 9_999 }
```

- [ ] **Step 5: Update SmelterView strings**

One upgrade row labelled "Furnace — +0.5 ore/s". Remove rows for Purity / Batch.

- [ ] **Step 6: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "smelter: one upgrade (Furnace), bar value flat x2

barValue = ore.baseValue * 2.0 * bonusMultiplier — no purity,
no batch, no smelterCore. Rate = 0.5 + furnace*0.5 +
smeltScience*0.2. Spec §9.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase E — Migration + HUD + achievements

### Task 18: Bump save version to 15 + write v14→v15 migration

**Files:**
- Modify: `Tycoon Deep Mine/Store.swift` (saveKey/saveVersion 31, load func 1197–1211)

- [ ] **Step 1: Bump the version constant**

In `Store.swift` line 31, change the version constant to `15` and update the persistence key if it’s version-suffixed (e.g. `"tdm_save_v15"`).

- [ ] **Step 2: Write a clean-slate migration**

In the load function (lines 1197–1211), replace the body with this exact shape:

```swift
func load() {
    guard let raw = UserDefaults.standard.data(forKey: persistenceKey),
          let decoded = try? JSONDecoder().decode(SaveBlob.self, from: raw) else {
        installFreshSave()
        return
    }
    if decoded.version < 15 {
        applyMigrationV14toV15(decoded)
        return
    }
    // current version
    applySave(decoded)
}

private func applyMigrationV14toV15(_ old: SaveBlob) {
    // Spec §11. Keep stats; wipe gameplay state; gift gems.
    let lifetime = old.lifetimeGoldEarned   // stat-only
    let achievements = old.achievementsClaimed
    installFreshSave()
    lifetimeGoldEarned = lifetime
    achievementsClaimed = achievements
    // One-time gift, spec §11.
    let giftRaw = floor(log10(max(1, lifetime)) * 5.0)
    let gift = Int(min(50.0, giftRaw))
    gemsLifetime += gift
    persistedMigrationGiftApplied = true
    persist()
}

private func installFreshSave() {
    gold = 0
    currentDepth = 0
    runMaxDepth = 0
    gemsLifetime = 0
    upgradeLevel.removeAll()
    globalLevel.removeAll()
    techLevel.removeAll()
    smelterLevel.removeAll()
    researchPoints = 0
}
```

(`SaveBlob` is whatever the existing Codable wrapper struct is — keep that type, just delete the now-removed fields from it.)

- [ ] **Step 3: Delete dead fields from `SaveBlob`**

Open the `SaveBlob` (or equivalent codable) struct. Remove every field listed in spec §11 step 3: `cores`, `coresLifetime`, `metaTree`, `gemsClaimedForCores`, `collapsesClaimedForCores`, `oreMastery`, `oreAmountMultiplier`, every removed upgrade level array key, smelter purity / batch level, `tapCritLevel`, `critPowerLevel`, all dropped globals.

If `SaveBlob` uses key-based decoding (CodingKeys), make sure missing keys decode as defaults (`init(from:)` with `decodeIfPresent`). This lets the migration path read a v14 blob without throwing.

- [ ] **Step 4: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual migration smoke test**

Steps:
1. Install previous build (build 20) on the simulator, play to first prestige, gather some gold.
2. Replace with build 21 (this build), launch.
3. Verify launch shows fresh run state plus a gem balance ≥ 1 (the migration gift).
4. Verify the Cores tab and Mastery tab no longer appear.

(This is a manual check — record findings in the commit message.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "save v14 -> v15 migration: wipe + gift gems

Migrates old saves to v15 by wiping gameplay state, keeping
lifetimeGoldEarned and achievementsClaimed only, and crediting
min(50, floor(log10(lifetime) * 5)) gems as a one-time gift.
Spec §11.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 19: HUD bonusSum bar + view strings

**Files:**
- Modify: `Tycoon Deep Mine/MineView.swift` (HUD)
- Modify: `Tycoon Deep Mine/UpgradesView.swift` (Ore Grader / Refiner row hint)
- Modify: `Tycoon Deep Mine/CollapseView.swift` (gem accrual display)
- Modify: `Tycoon Deep Mine/HowToPlayView.swift` (rewrite copy)
- Modify: `Tycoon Deep Mine/MoreView.swift` (debug section)

- [ ] **Step 1: Add a bonus cap bar to the HUD**

In `MineView.swift`’s HUD overlay, add (style to match existing rows):

```swift
HStack(spacing: 6) {
    Text("BONUS")
        .font(.caption2).bold()
        .foregroundColor(.secondary)
    ProgressView(value: min(store.bonusSum, 3.0), total: 3.0)
        .progressViewStyle(.linear)
    Text("\(Int(store.bonusSum * 100))% / 300%")
        .font(.caption2.monospacedDigit())
        .foregroundColor(.secondary)
}
.padding(.horizontal, 12)
```

Place it just below the gold counter line.

- [ ] **Step 2: Update HowToPlayView copy**

Rewrite the body to describe v15 mechanics in 3 short sections: Mining (linear HP, 10 zones, 10 ore tiers), Upgrades (+5% / +3% cap), Prestige (gems gate at +0.5 % each, cap +300 %; gems also buy permanent perks). Keep it under 15 lines.

- [ ] **Step 3: Update CollapseView preview number**

Show:

```swift
Text("+\(store.pendingGems) gems on collapse")
Text("Max depth this run: \(store.runMaxDepth) m")
```

- [ ] **Step 4: Make sure UpgradesView shows the cap on Ore Grader / Refiner rows**

Add a small caption under each affecting row: `"(contributes to +300% cap)"`.

- [ ] **Step 5: Remove the debug `Text` placeholder from Task 11 (optional)**

If the inline `#if DEBUG Text("bonusSum: …")` was added in Task 11, keep it for the smoke test phase; delete after Task 21 if not needed.

- [ ] **Step 6: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "HUD bonus bar + v15 view strings

Adds a 0/3.00 progress bar to the mine HUD, rewrites
HowToPlay copy for v15, surfaces pendingGems on Collapse,
notes +300% cap on Ore Grader / Refiner.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 20: Achievements pass

**Files:**
- Modify: `Tycoon Deep Mine/Achievements.swift`
- Modify: `Tycoon Deep Mine/AwardsView.swift` (if references removed achievements directly)

- [ ] **Step 1: Identify achievements that depend on removed mechanics**

Open `Achievements.swift`. Mark each achievement that references: cores, mastery, crit, depth-scaling, dynamite, treasure-luck, ore-magnet, second-prestige.

- [ ] **Step 2: Either remap or remove**

For each marked achievement:
- If it has a clean v15 equivalent (e.g. "Earn 1000 gold" still works), keep as-is.
- If its trigger no longer exists (e.g. "Reach Cores level 5"), delete the achievement entry entirely.
- If its trigger still exists in spirit, retarget (e.g. "Get +200 % bonus" instead of "+5 from Gold Vein").

- [ ] **Step 3: Update AwardsView**

If `AwardsView.swift` lists achievement keys explicitly, drop the deleted ones.

- [ ] **Step 4: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "achievements: retire / remap entries tied to removed systems

Drops achievements that referenced cores, mastery, crit,
ore-magnet, depth scaling, treasure luck. Re-targets the
salvageable ones to v15 equivalents.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 21: Smoke playtest + pacing verification

**Files:** none (verification only).

- [ ] **Step 1: Clean install on simulator**

```bash
xcrun simctl uninstall booted com.example.TycoonDeepMine 2>/dev/null
xcodebuild -project "Tycoon Deep Mine.xcodeproj" \
  -scheme "Tycoon Deep Mine" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug build install 2>&1 | tail -10
```

Adjust simulator name to whatever is booted. If bundle id differs, use the real one.

- [ ] **Step 2: 15-minute pacing check (Zone 1)**

Launch the app. Tap at a steady ~2 taps/sec for the first minute, then continue tapping intermittently while letting drills do work. Buy upgrades as you can afford them, prioritising Pickaxe (1) and Drill Rig (2).

Record at each minute:
- depth reached
- bonusSum (read from HUD)
- gold accumulated
- gold/sec at depth (eyeball)

Acceptance per spec §13:
- At minute 15 ± 3, you must have reached Zone 1 boss (depth ≥ 99) and defeated it.
- `bonusSum` ≤ 0.20 (we’re still early).

If Zone 1 boss takes < 12 min: increase `HP slope` from 2.0 → 2.5 in Task 10’s formula and rerun.
If Zone 1 boss takes > 18 min: decrease `HP slope` from 2.0 → 1.6 and rerun.

- [ ] **Step 3: First-prestige pacing (skip-ahead simulation)**

If the engineer cannot afford 3 hours of manual play, use the in-app Debug section (or add one) to fast-forward `delta` by 100×. Record when `pendingGems` first equals 5 (= ~depth 1000). Spec target: 2.5–4 h of real-time play.

- [ ] **Step 4: Bonus cap sanity**

Buy Ore Grader and Refiner to absurd levels (≥ 100 each). Confirm the HUD bar saturates at 300 % and never exceeds it. Verify the `precondition` in Task 11 does NOT fire (which would mean a code error).

- [ ] **Step 5: Migration test**

If a v14 save exists on the device, install build 21 over it. Confirm: 
- launches without crash
- gem balance includes the migration gift
- no Cores / Mastery tab present
- gameplay state is fresh (gold 0, depth 0)

- [ ] **Step 6: Final commit**

Record findings in a final summary commit (no code changes, just notes):

```bash
git commit --allow-empty -m "v15 economy rewrite complete — pacing verified

- Zone 1 boss: <X> min (target 15 ± 3)
- First prestige (5 gems): <X> h (target 2.5–4)
- bonusSum saturates at 300% cap, no overflow
- v14 -> v15 migration smoke OK, gift gems credited

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 7: Hand off**

The branch `economy-rewrite-v15` is ready for `finishing-a-development-branch` skill to decide merge / PR / build bump.

---

## Self-Review (run after writing the plan)

This is a quick checklist the plan author runs once with fresh eyes:

**1. Spec coverage** — every spec section maps to at least one task:

| Spec § | Implemented by task |
|---|---|
| 2 Invariants | 8, 9, 10, 11, 12 |
| 3 Systems kept/removed | 4, 5, 6, 7, 14, 16, 17 |
| 4 Base rates | 10, 11, 12 |
| 5 Upgrade catalog | 12, 13 |
| 6 Zones | 9, 10 |
| 7 Gems prestige | 14, 15 |
| 8 Research | 16 |
| 9 Smelter | 17 |
| 10 Removed mechanics | 5, 6, 7 |
| 11 Save migration | 18 |
| 12 Files expected to change | covered transitively |
| 13 Acceptance criteria | 21 |
| 14 Risks | 18, 21 |
| 15 Out of scope | n/a |

No spec section is unaddressed.

**2. Placeholder scan** — every code block in the plan above is concrete Swift, every `grep` command is runnable, every commit message is filled in. No `TBD`, no "add appropriate error handling".

**3. Type consistency** — names used across tasks:
- `bonusSum`, `bonusMultiplier` — introduced Task 11, used Tasks 12, 16, 17, 19 consistently.
- `globalLevel[.widePan]` — added in Task 7, used in Task 12 / 14.
- `techLevel[.sharpTools]` / `.veinMapping` — referenced (stubbed) Task 11, defined Task 16.
- `gemsLifetime` — used in Tasks 11, 15, 18 consistently.
- `applyDamageToCurrentBlock` (Task 12) — engineer must adjust to existing helper name; flagged in step.
- `SaveBlob` (Task 18) — engineer must use the project's actual Codable wrapper; flagged in step.

**4. Order safety** — every task ends with a build verification + commit, so any error is localized to the most recent task.
