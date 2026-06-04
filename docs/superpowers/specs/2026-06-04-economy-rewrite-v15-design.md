# Economy Rewrite v15 — Cookie Clicker Shape

**Date:** 2026-06-04
**Status:** Approved (brainstorm phase complete)
**Save version:** v15 (bump from v14)
**Build target:** Build 21

---

## 1. Why a rewrite

After 20 builds of tuning, the economy still snowballs: a few well-chosen upgrade purchases multiply gold-per-second beyond intent. Root causes identified in v14 source:

1. **`goldBonusSum` is a shared additive bucket** fed by 7 lines (oreValue, refiner, goldFind, yieldBoost, goldVein, assayers, gems) and applied once to every gold stream (rubble, ore, bar, boss, treasure, milestone). Players easily push it past +200 %.
2. **`damageBonusSum`** has the same shape on the damage side, plus `depthScaling` makes it grow with depth.
3. **Ore tier value `×1.4^tier`** (Aetherium = 159 × Coal) compounds with `goldBonusSum`.
4. **Bar value chain** `ore × 3.5 × (1 + purity×0.12) × (1 + smelterCore×0.12)` multiplies the above again.
5. **Two prestige layers (Gems → Cores)** with `gemResonance` close a feedback loop: more gems → more bonus → deeper next run → more gems.

The user’s instruction is explicit: rebuild for a **Cookie Clicker shape** — predictable, additive, single prestige.

## 2. Invariants (these forbid the snowball)

Every later number choice must obey these six rules. They are non-negotiable.

| # | Rule | Why |
|---|---|---|
| 1 | One global `bonusSum`, **hard cap +300 %** (× 4.0 max). | Without a cap, any additive bucket eventually breaks. |
| 2 | Ore tier value is **linear**: tier *N* worth *N* gold. (10 tiers → ×10 max from tier alone, vs ×159 today.) | Removes the dominant exponential. |
| 3 | Block HP is **linear** in depth: `HP = 20 + 2 × depth`. | DPS purchases stay proportional to HP. |
| 4 | All upgrade prices grow **×1.15 per level**, no exception. | Uniform price ladder → predictable affordability. |
| 5 | No depth-scaling upgrade or perk. | Anything proportional to depth re-creates a snowball. |
| 6 | No `A × B × C` multiplier chains anywhere. The only allowed product is `value × (1 + bonusSum)`. | Chains are the structural source of the bug. |

## 3. Systems kept, removed, simplified

| System | Verdict | Notes |
|---|---|---|
| Tap / Drill / Cart | Kept | Rebalanced to linear baselines. |
| Mine zones (10) | Kept | Pure progression markers, **no per-zone multipliers**. |
| Smelter | Simplified | Single upgrade. Bars sell at `ore.value × 2.0` flat. No purity / batch / smelterCore. |
| Research | Kept, simplified | 4 techs, two feed `bonusSum`, two are direct rate adders. Persists across collapse. |
| Gems prestige | Kept | Single prestige layer. Gems feed shared `bonusSum` and unlock permanent perks. |
| Cores (2nd prestige) | **Removed** | Source of the gem-resonance loop. |
| Per-ore Mastery | **Removed** | Quietly multiplied ore value. |
| `damageBonusSum` | **Removed** | Merged into the single `bonusSum`. |
| Ore-amount multipliers | **Removed** | Ore drop = 30 % flat, 1 unit, no perks. |
| Crit on tap | **Removed** | Source of × 30 spikes. |
| Globals tab | Removed | Replaced by per-collapse gem-permanent shop (see § 7). |

## 4. Base rates

Pacing target (Classic): Zone 1 boss ≈ 15 min, first collapse ≈ 3 h, all ten ore tiers ≈ 30 h.

| Quantity | Formula | Spot values |
|---|---|---|
| Tap damage | `1.0 + pickaxe × 1.0` | L0 = 1, L10 = 11, L50 = 51 |
| Drill count | `drillRig × 1` | L10 = 10 drills |
| Drill base DPS / drill | `0.5 + drillTuning × 0.2` | tuning L5 = 1.5 / drill |
| Auto-tap rate | `autoPick × 0.2` taps/s, each does `tap damage` | L5 = 1 / s |
| Cart rate | `cart × 0.5` ore/s (L0 = inactive, L1 = 1.0) | L4 = 2.0 |
| Cart capacity | `20 + cart × 5` | L4 = 40 |
| Block HP | `20 + 2 × depth` | d80 = 180, d1000 = 2020 |
| Boss HP multiplier | × 4 on the last block of each zone | d99 = 720 boss |
| Rubble gold | `1 + 1 × depth` | d80 = 81, d1000 = 1001 |
| Ore drop chance | 30 % flat | — |
| Ore drop amount | 1 unit flat | — |
| Final gold multiplier | `1 + min(bonusSum, 3.0)` | cap × 4.0 |

`bonusSum` is the **only** gold-side multiplier. Tap damage and drill DPS are added directly into their respective totals; they do **not** pass through `bonusSum`.

## 5. Upgrade catalog (gold-bought, run-scoped)

Eight upgrades. All cost ladder ×1.15. All effects flat-additive into a clearly named target.

| # | Name | Effect / level | Target | Base cost | Cap |
|---|---|---|---|---|---|
| 1 | Pickaxe Power | +1 tap damage | `tap` | 10 | none |
| 2 | Drill Rig | +1 drill | `drill count` | 50 | none |
| 3 | Drill Tuning | +0.2 base DPS per drill | `drill base` | 250 | none |
| 4 | Mine Cart | +0.5 ore/s, +5 capacity | `cart rate`, `cart cap` | 150 | none |
| 5 | Ore Grader | +0.05 in `bonusSum` (+5 %) | `bonusSum` | 500 | (soft, by cap) |
| 6 | Refiner | +0.03 in `bonusSum` (+3 %) | `bonusSum` | 2 500 | (soft, by cap) |
| 7 | Auto Pick | +0.2 auto-taps/s | `auto-tap rate` | 5 000 | none |
| 8 | Multi-Strike | +1 strike per tap | `strike count` | 100 000 | **5** (→ 6 strikes total) |

Removed from v14: Dynamite, Elevator, Gold Find, Depth Scaling.

## 6. Zones (10, pure progression markers)

No per-zone gold or HP multiplier — depth handles scaling. Each zone unlocks one ore tier. Boss block at the end of each zone has × 4 HP. Bosses do **not** drop gems directly — gems are awarded only on collapse, based on `runMaxDepth` (see § 7). The boss gates progress and pays out extra rubble gold = `2 × (1 + depth)`.

| # | Zone | Depth | Unlocks ore | Ore value |
|---|---|---|---|---|
| 1 | Surface | 0 – 100 | Coal | 1 |
| 2 | Stone Shelf | 100 – 220 | Copper | 2 |
| 3 | Crystal Caverns | 220 – 400 | Tin | 3 |
| 4 | Magma Veins | 400 – 650 | Iron | 4 |
| 5 | Abyss | 650 – 1000 | Silver | 5 |
| 6 | World’s Core | 1000 – 1500 | Gold | 6 |
| 7 | Mantle Forge | 1500 – 2200 | Ruby | 7 |
| 8 | Void Rift | 2200 – 3100 | Emerald | 8 |
| 9 | Stellar Vault | 3100 – 4200 | Sapphire | 9 |
| 10 | Aether Wellspring | 4200 + | Diamond | 10 |

Beyond Zone 10, depth keeps increasing for prestige farming, but no new ore tier appears.

## 7. Gems prestige (Collapse — single layer)

**Trigger:** allowed once the player has cleared depth ≥ 100 at least once.

**Gems awarded per collapse:**

```
gemsAwarded = floor( (runMaxDepth / 100) ^ 0.7 )
```

| `runMaxDepth` | gems |
|---|---|
| 100 (Z1 boss) | 1 |
| 500 | 3 |
| 1 000 | 5 |
| 5 000 | 16 |
| 20 000 | 44 |
| 100 000 | 158 |

Sub-linear exponent (0.7) prevents farming explosions.

**Gem application to `bonusSum`:** each lifetime gem contributes `+0.005` (= +0.5 %). At 600 gems, contribution = +300 %, which **alone hits the cap** — past that, gems are pure unlock currency for the permanent shop.

**Permanent shop (gems spent, survives collapse):**

| Perk | Effect / level | Cost ladder (linear) | Max level |
|---|---|---|---|
| Shaft Head Start | +20 starting depth | 30, 60, 90, … | 10 |
| Standing Drill | +1 free drill at run start | 60, 120, 180, … | 10 |
| Wide Pan | +1 cart level at run start | 100, 200, 300, … | 5 |
| Night Shift | +2 h offline cap | 50, 100, 150, … | 8 (→ 18 h total max) |
| Seed Vault | +500 starting gold | 40, 80, 120, … | 10 (→ +5 000 gold) |

Linear cost ladders — never exponential. The shop is intentionally finite.

**What collapse resets:** gold, depth, all 8 run upgrades, smelter Furnace level, research levels.
**What collapse keeps:** lifetime gems, permanent shop levels, achievements/awards, `lifetimeGoldEarned` (stat only).

## 8. Research (RP, persists across collapse)

RP earn rate: `depth / 50` per second (slow trickle). Persists across collapse — it is the long-haul progression layer.

| Tech | Effect / level | Target | Base cost | Cost growth | Max level |
|---|---|---|---|---|---|
| Sharpened Tools | +0.01 in `bonusSum` | `bonusSum` | 10 | ×1.20 | 30 |
| Vein Mapping | +0.01 in `bonusSum` | `bonusSum` | 12 | ×1.20 | 30 |
| Cart Logistics | +0.1 ore/s | `cart rate` | 15 | ×1.20 | 30 |
| Smelt Science | +0.2 ore/s | `smelter rate` | 20 | ×1.20 | 30 |

`bonusSum`-feeding techs maxed contribute +60 % each → +120 % total. Combined with Ore Grader/Refiner/gems, this fills the +300 % cap; that is intentional — the cap is the soft horizon, not unreachable.

## 9. Smelter (one upgrade)

- Auto-converts queued ore into bars at smelter rate.
- **Bar unit value = `ore.baseValue × 2.0`** (flat, **no** multiplier chain).
- Smelter rate = `0.5 + furnace × 0.5` ore/s (research adds +0.1 / Smelt-Science level on top, direct).
- Single upgrade `Furnace`: +0.5 ore/s, base **8 000 gold**, ×1.15 cost growth, no cap.

Removed: Bar Purity, Batch, smelterCore meta.

## 10. Crit, depth-scaling, ore-amount perks — removed

Listed for completeness so the implementer can search-delete:

- `tapCrit`, `critPower`, `dynamite`, `depthScaling`, `oreMagnet`, `oreRichness`, `treasureLuck`, `prospectorsEye`, `goldFind`, `elevator`.

## 11. Save migration (v14 → v15)

On first launch with build 21:

1. If `save.version <= 14` (or missing), perform clean migration.
2. **Keep:**  `lifetimeGoldEarned`, achievements/awards, save analytics counters.
3. **Wipe:** all Cores fields (`cores`, `coresLifetime`, `metaTree`, `gemsClaimedForCores`, `collapsesClaimedForCores`), `oreMastery`, all globals fields, `oreAmountMultiplier`, every removed upgrade level, smelter Purity / Batch levels.
4. Reset run state (gold, depth, ore, bars, current upgrade levels, research levels, smelter Furnace level).
5. **Migration gift** (one-time): credit `min(50, floor(log10(max(1, lifetimeGoldEarned)) × 5))` gems to compensate for the wipe.
6. Stamp `save.version = 15`.

This guarantees no v14 field can sneak a multiplier into v15.

## 12. Files expected to change

(For planning only — the implementation plan will refine.)

- `GameModel.swift` — drop `damageBonusSum`, depth scaling, ore-amount perks, crit; redefine `bonusSum`; rewrite zone table, ore tier values, HP / rubble formulas; rewrite tick gold/damage paths to one product; rewrite collapse path.
- `Store.swift` — rewrite upgrade catalog (8 entries); rewrite gems shop; rewrite research catalog (4 entries); rewrite smelter (1 upgrade, flat bar value); strip Cores / Mastery / depthScaling / crit code.
- `Systems.swift` — strip `metaTree` and per-ore mastery code; simplify Research; simplify Smelter.
- `CoresView.swift`, `MasteryView.swift` — delete entirely; remove tabs from `RootTabView.swift`.
- `UpgradesView.swift`, `ResearchView.swift`, `SmelterView.swift`, `CollapseView.swift`, `MineView.swift`, `AwardsView.swift` — purge references to removed fields; render `bonusSum` cap in HUD.
- `Deep_MineApp.swift` (or wherever load lives) — implement the v14 → v15 migration in § 11.
- `Achievements.swift` — review which achievements reference removed mechanics, retire or remap.
- `MoreView.swift`, `HowToPlayView.swift` — update copy.

## 13. Acceptance criteria

A build passes acceptance if all of the following hold:

1. Save version is 15. A v14 save loads cleanly, with the gift gems applied exactly once.
2. There is exactly **one** additive bucket named `bonusSum`. Grepping the project finds no other `*BonusSum` / `*Multiplier` chains in gold / damage paths.
3. `Cores`, `metaTree`, `oreMastery`, `depthScaling`, `tapCrit`, `critPower`, `oreMagnet`, `oreRichness`, `treasureLuck`, `goldFind`, `dynamite`, `elevator` symbols are removed.
4. Reaching Zone 1 boss from a fresh save with a representative play pattern (manual taps + reasonable upgrade buys) takes 12 – 18 minutes — verified by instrumentation log of one playtest.
5. First collapse from a fresh save takes 2.5 – 4 h of total play time (a manual smoke-test run or a sped-up sim).
6. After buying every gold-side upgrade to a high level, the HUD shows `bonusSum ≤ 3.00` and never overflows.
7. No tab in `RootTabView.swift` references Cores or Mastery.
8. The app boots, runs an idle minute, and accrues gold + ore + RP without NaN / inf.

## 14. Risks and mitigations

- **Risk: Existing players feel cheated by the wipe.** Mitigation: the migration gift in § 11 and a one-time onboarding sheet explaining the rework.
- **Risk: Pacing miscalibrated for Zone 1.** Mitigation: ship a debug switch (already present in Build 20) that lets the implementer run a sped-up smoke test and tune `HP slope = 2` up or down by ± 0.5.
- **Risk: Removing systems shrinks playtime late game.** Acceptable for this iteration: the game has been judged unplayable due to snowball; lean content is preferable to overpowered content. Future iteration may re-add complexity *on top of* the v15 invariants.
- **Risk: `bonusSum` cap of +300 % feels stingy late game.** Acceptable: the cap is the signature of the Cookie Clicker shape and the user explicitly chose it. UI must show the bar filling and label it clearly.

## 15. Out of scope

- Visual / theme changes.
- Achievements rework beyond removing dangling references.
- New ore tiers beyond 10.
- IAP / ad placement changes.
- Bringing back a second prestige layer.
