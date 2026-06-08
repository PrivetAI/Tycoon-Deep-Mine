import SwiftUI

// MARK: - Ore types

enum DDMOre: Int, CaseIterable, Codable {
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

    var name: String {
        switch self {
        case .coal: return "Coal"
        case .copper: return "Copper"
        case .tin: return "Tin"
        case .iron: return "Iron"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .ruby: return "Ruby"
        case .emerald: return "Emerald"
        case .sapphire: return "Sapphire"
        case .diamond: return "Diamond"
        }
    }

    // Base sell value per unit of ore. v15.2: flat ~11%-per-tier ladder 1.0..2.0 (tier 10 = 2.0× tier 1).
    var baseValue: Double {
        switch self {
        case .coal:     return 1.0
        case .copper:   return 1.111
        case .tin:      return 1.222
        case .iron:     return 1.333
        case .silver:   return 1.444
        case .gold:     return 1.555
        case .ruby:     return 1.666
        case .emerald:  return 1.777
        case .sapphire: return 1.888
        case .diamond:  return 2.0
        }
    }

    // Depth (meters) at which this ore begins to appear. v15: aligned to zone boundaries (spec §6).
    var unlockDepth: Int {
        switch self {
        case .coal: return 0
        case .copper: return 100
        case .tin: return 220
        case .iron: return 400
        case .silver: return 650
        case .gold: return 1_000
        case .ruby: return 1_500
        case .emerald: return 2_200
        case .sapphire: return 3_100
        case .diamond: return 4_200
        }
    }

    var color: Color {
        switch self {
        case .coal: return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .copper: return Color(red: 0.78, green: 0.45, blue: 0.27)
        case .tin: return Color(red: 0.66, green: 0.68, blue: 0.72)
        case .iron: return Color(red: 0.52, green: 0.54, blue: 0.58)
        case .silver: return Color(red: 0.84, green: 0.86, blue: 0.90)
        case .gold: return DDMPalette.gold
        case .ruby: return Color(red: 0.84, green: 0.18, blue: 0.30)
        case .emerald: return Color(red: 0.20, green: 0.72, blue: 0.46)
        case .sapphire: return Color(red: 0.24, green: 0.42, blue: 0.86)
        case .diamond: return Color(red: 0.70, green: 0.90, blue: 0.96)
        }
    }
}

// MARK: - Zones / strata

// A depth band with its own name, palette and economy modifiers.
// Zone is derived purely from depth — no save migration needed.
struct DDMZone: Identifiable {
    let index: Int
    let name: String
    let startDepth: Int       // inclusive
    let endDepth: Int         // exclusive (Int.max for the last zone)
    let hpMult: Double        // multiplies block HP within this zone
    let goldMult: Double      // multiplies rubble / sale gold within this zone
    let oreMult: Double       // multiplies ore drop amount within this zone
    // Palette for the strata background.
    let bandA: Color
    let bandB: Color
    let baseFill: Color
    let accent: Color

    var id: Int { index }

    var spanText: String {
        if endDepth == Int.max { return "\(startDepth) m +" }
        return "\(startDepth)–\(endDepth) m"
    }

    // v15: zones are COSMETIC only — hpMult, goldMult, oreMult all 1.0 for every zone.
    // Depth alone drives HP (linear formula, Task 10) and income. Per-zone multipliers
    // are intentionally eliminated per Spec §6.
    static let all: [DDMZone] = [
        DDMZone(index: 0, name: "Surface", startDepth: 0, endDepth: 100,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.45, green: 0.32, blue: 0.21),
                bandB: Color(red: 0.33, green: 0.23, blue: 0.15),
                baseFill: Color(red: 0.30, green: 0.21, blue: 0.13),
                accent: Color(red: 0.57, green: 0.42, blue: 0.28)),
        DDMZone(index: 1, name: "Stone Shelf", startDepth: 100, endDepth: 220,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.40, green: 0.36, blue: 0.33),
                bandB: Color(red: 0.30, green: 0.27, blue: 0.24),
                baseFill: Color(red: 0.26, green: 0.24, blue: 0.22),
                accent: Color(red: 0.52, green: 0.47, blue: 0.43)),
        DDMZone(index: 2, name: "Crystal Caverns", startDepth: 220, endDepth: 400,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.26, green: 0.34, blue: 0.46),
                bandB: Color(red: 0.18, green: 0.25, blue: 0.36),
                baseFill: Color(red: 0.14, green: 0.20, blue: 0.30),
                accent: Color(red: 0.46, green: 0.74, blue: 0.86)),
        DDMZone(index: 3, name: "Magma Veins", startDepth: 400, endDepth: 650,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.46, green: 0.20, blue: 0.14),
                bandB: Color(red: 0.34, green: 0.13, blue: 0.09),
                baseFill: Color(red: 0.28, green: 0.10, blue: 0.07),
                accent: Color(red: 0.96, green: 0.52, blue: 0.20)),
        DDMZone(index: 4, name: "Abyss", startDepth: 650, endDepth: 1_000,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.22, green: 0.18, blue: 0.34),
                bandB: Color(red: 0.15, green: 0.12, blue: 0.26),
                baseFill: Color(red: 0.11, green: 0.09, blue: 0.20),
                accent: Color(red: 0.62, green: 0.52, blue: 0.92)),
        DDMZone(index: 5, name: "World's Core", startDepth: 1_000, endDepth: 1_500,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.40, green: 0.30, blue: 0.10),
                bandB: Color(red: 0.28, green: 0.20, blue: 0.06),
                baseFill: Color(red: 0.20, green: 0.14, blue: 0.04),
                accent: Color(red: 0.98, green: 0.78, blue: 0.30)),
        DDMZone(index: 6, name: "Mantle Forge", startDepth: 1_500, endDepth: 2_200,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.46, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.34, blue: 0.25),
                baseFill: Color(red: 0.08, green: 0.24, blue: 0.18),
                accent: Color(red: 0.42, green: 0.92, blue: 0.66)),
        DDMZone(index: 7, name: "Void Rift", startDepth: 2_200, endDepth: 3_100,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.12, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.07, blue: 0.24),
                baseFill: Color(red: 0.09, green: 0.05, blue: 0.18),
                accent: Color(red: 0.66, green: 0.40, blue: 0.96)),
        DDMZone(index: 8, name: "Stellar Vault", startDepth: 3_100, endDepth: 4_200,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.26, blue: 0.46),
                bandB: Color(red: 0.13, green: 0.18, blue: 0.36),
                baseFill: Color(red: 0.08, green: 0.12, blue: 0.28),
                accent: Color(red: 0.62, green: 0.74, blue: 0.98)),
        DDMZone(index: 9, name: "Aether Wellspring", startDepth: 4_200, endDepth: Int.max,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.44, green: 0.38, blue: 0.18),
                bandB: Color(red: 0.32, green: 0.27, blue: 0.10),
                baseFill: Color(red: 0.22, green: 0.18, blue: 0.06),
                accent: Color(red: 0.98, green: 0.90, blue: 0.56))
    ]

    static func zone(at depth: Int) -> DDMZone {
        let d = max(0, depth)
        for z in all where d >= z.startDepth && d < z.endDepth {
            return z
        }
        return all.last!
    }

    // The boss-gate depth at the END of this zone (the block that gates the next).
    var bossDepth: Int? {
        endDepth == Int.max ? nil : endDepth - 1
    }

    // Is this exact depth a boss/bedrock gate?
    static func isBossDepth(_ depth: Int) -> Bool {
        for z in all where z.endDepth != Int.max {
            if z.endDepth - 1 == depth { return true }
        }
        return false
    }

    var next: DDMZone? {
        DDMZone.all.first(where: { $0.index == index + 1 })
    }
}

// MARK: - Upgrade definitions

enum DDMUpgradeKind: String, Codable, CaseIterable {
    case pickaxe        // tap damage
    case drillCount     // number of drills (auto dps base)
    case drillSpeed     // multiplier on auto dps
    case oreValue       // ore sell value multiplier
    case cart           // auto-collect / auto-sell rate
    case refiner        // bonus gold per sale (refining)
    case multiTap       // each tap counts as N strikes
    case autoTapper     // automatic taps per second (uses tap damage)
}

struct DDMUpgradeDef: Identifiable {
    let kind: DDMUpgradeKind
    let title: String
    let blurb: String
    let baseCost: Double
    let costGrowth: Double
    let maxLevel: Int

    var id: String { kind.rawValue }

    func cost(at level: Int) -> Double {
        let c = baseCost * pow(costGrowth, Double(level))
        return c.isFinite ? c.rounded() : Double.greatestFiniteMagnitude
    }

    // v15.3 permafrost ladder. Click growth crushed, upgrade growth trimmed.
    static let all: [DDMUpgradeDef] = [
        DDMUpgradeDef(kind: .pickaxe, title: "Pickaxe Power",
                      blurb: "+0.08 tap damage",
                      baseCost: 150, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillCount, title: "Drill Rig",
                      blurb: "+1 drill",
                      baseCost: 1_500, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillSpeed, title: "Drill Tuning",
                      blurb: "+0.015 base DPS per drill",
                      baseCost: 12_000, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .cart, title: "Mine Cart",
                      blurb: "+0.06 ore/s, +1 cart capacity",
                      baseCost: 4_500, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .oreValue, title: "Ore Grader",
                      blurb: "+0.5% bonus (capped at +100%)",
                      baseCost: 20_000, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .refiner, title: "Refiner",
                      blurb: "+0.25% bonus (capped at +100%)",
                      baseCost: 150_000, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .autoTapper, title: "Auto Pick",
                      blurb: "+0.005 auto-taps/sec",
                      baseCost: 400_000, costGrowth: 1.25, maxLevel: 9999),
        DDMUpgradeDef(kind: .multiTap, title: "Multi-Strike",
                      blurb: "+1 strike per tap (max 2 total)",
                      baseCost: 30_000_000, costGrowth: 1.25, maxLevel: 1)
    ]

    static func def(_ kind: DDMUpgradeKind) -> DDMUpgradeDef {
        all.first(where: { $0.kind == kind })!
    }
}

// MARK: - Global (prestige) upgrades — bought with Gems

enum DDMGlobalKind: String, Codable, CaseIterable {
    case startDepth      // start depth after collapse
    case offlineCap      // raise offline earnings cap (hours)
    case autoStart       // free starting drills after collapse
    case startGold       // start each collapse with a gold stake
    case widePan         // +1 cart level at run start
}

struct DDMGlobalDef: Identifiable {
    let kind: DDMGlobalKind
    let title: String
    let blurb: String
    let baseCost: Int
    let maxLevel: Int

    var id: String { kind.rawValue }

    /// Spec §7: linear cost ladder. cost(level) = baseCost * (level + 1)
    func cost(at level: Int) -> Int {
        return baseCost * (level + 1)
    }

    static let all: [DDMGlobalDef] = [
        DDMGlobalDef(kind: .startDepth, title: "Shaft Head Start",
                     blurb: "+5 starting depth on each run per level.",
                     baseCost: 150, maxLevel: 10),
        DDMGlobalDef(kind: .autoStart, title: "Standing Drill",
                     blurb: "+1 free drill at run start per level.",
                     baseCost: 300, maxLevel: 10),
        DDMGlobalDef(kind: .widePan, title: "Wide Pan",
                     blurb: "+1 cart level at run start per level.",
                     baseCost: 500, maxLevel: 5),
        DDMGlobalDef(kind: .offlineCap, title: "Night Shift",
                     blurb: "+2 h offline earnings cap per level.",
                     baseCost: 250, maxLevel: 8),
        DDMGlobalDef(kind: .startGold, title: "Seed Vault",
                     blurb: "+100 starting gold on each run per level.",
                     baseCost: 200, maxLevel: 10)
    ]

    static func def(_ kind: DDMGlobalKind) -> DDMGlobalDef {
        all.first(where: { $0.kind == kind })!
    }
}

// MARK: - Settings

struct DDMSettings: Codable {
    var soundOn: Bool = true
    var hapticsOn: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? true
    }
}

// MARK: - Save data

struct DDMSave: Codable {
    var gold: Double = 0
    var depth: Int = 0                 // current depth (meters)
    var maxDepth: Int = 0              // max reached this run-history (lifetime)
    var runMaxDepth: Int = 0           // max reached this collapse run
    var currentBlockHP: Double = -1    // -1 means "regenerate from depth"
    var oreCounts: [Int: Double] = [:] // ore raw -> count held (not yet sold)
    var upgrades: [String: Int] = [:]  // upgrade kind raw -> level
    var globals: [String: Int] = [:]   // global kind raw -> level
    var gems: Int = 0
    var lifetimeOreSold: Double = 0
    var lifetimeGoldEarned: Double = 0
    var oreMinedTotals: [Int: Double] = [:] // lifetime mined per ore
    var lastActive: Double = 0          // timeIntervalSince1970
    var totalTaps: Int = 0
    var totalCollapses: Int = 0

    // --- additive fields (decoded with decodeIfPresent ?? default) ---
    var oreSoldClaimed: Double = 0      // lifetimeOreSold accounted for at last collapse
    var claimedMilestones: [Int] = []   // depth-milestone thresholds already rewarded
    var bossesDefeated: Int = 0         // lifetime bedrock bosses cleared
    var treasuresFound: Int = 0         // lifetime treasure/geode blocks cleared

    // --- Research ---
    var research: Double = 0            // spendable research points
    var lifetimeResearch: Double = 0
    var researchClaimedDepth: Int = 0   // maxDepth basis already paid out as research
    var techs: [String: Int] = [:]      // tech kind raw -> level

    // --- Smelter ---
    var bars: [Int: Double] = [:]       // ore raw -> refined bar count held
    var smelterUpgrades: [String: Int] = [:] // smelter upgrade kind raw -> level
    var lifetimeBarsValue: Double = 0

    // --- Save version / migration ---
    var version: Int = 15
    var migrationGiftApplied: Bool = false  // true once the v14→v15 gem gift has been credited

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gold = try c.decodeIfPresent(Double.self, forKey: .gold) ?? 0
        depth = try c.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        maxDepth = try c.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 0
        runMaxDepth = try c.decodeIfPresent(Int.self, forKey: .runMaxDepth) ?? 0
        currentBlockHP = try c.decodeIfPresent(Double.self, forKey: .currentBlockHP) ?? -1
        oreCounts = try c.decodeIfPresent([Int: Double].self, forKey: .oreCounts) ?? [:]
        upgrades = try c.decodeIfPresent([String: Int].self, forKey: .upgrades) ?? [:]
        globals = try c.decodeIfPresent([String: Int].self, forKey: .globals) ?? [:]
        gems = try c.decodeIfPresent(Int.self, forKey: .gems) ?? 0
        lifetimeOreSold = try c.decodeIfPresent(Double.self, forKey: .lifetimeOreSold) ?? 0
        lifetimeGoldEarned = try c.decodeIfPresent(Double.self, forKey: .lifetimeGoldEarned) ?? 0
        oreMinedTotals = try c.decodeIfPresent([Int: Double].self, forKey: .oreMinedTotals) ?? [:]
        lastActive = try c.decodeIfPresent(Double.self, forKey: .lastActive) ?? 0
        totalTaps = try c.decodeIfPresent(Int.self, forKey: .totalTaps) ?? 0
        totalCollapses = try c.decodeIfPresent(Int.self, forKey: .totalCollapses) ?? 0
        oreSoldClaimed = try c.decodeIfPresent(Double.self, forKey: .oreSoldClaimed) ?? 0
        claimedMilestones = try c.decodeIfPresent([Int].self, forKey: .claimedMilestones) ?? []
        bossesDefeated = try c.decodeIfPresent(Int.self, forKey: .bossesDefeated) ?? 0
        treasuresFound = try c.decodeIfPresent(Int.self, forKey: .treasuresFound) ?? 0
        // additive — Research
        research = try c.decodeIfPresent(Double.self, forKey: .research) ?? 0
        lifetimeResearch = try c.decodeIfPresent(Double.self, forKey: .lifetimeResearch) ?? 0
        researchClaimedDepth = try c.decodeIfPresent(Int.self, forKey: .researchClaimedDepth) ?? 0
        techs = try c.decodeIfPresent([String: Int].self, forKey: .techs) ?? [:]
        // additive — Smelter
        bars = try c.decodeIfPresent([Int: Double].self, forKey: .bars) ?? [:]
        smelterUpgrades = try c.decodeIfPresent([String: Int].self, forKey: .smelterUpgrades) ?? [:]
        lifetimeBarsValue = try c.decodeIfPresent(Double.self, forKey: .lifetimeBarsValue) ?? 0
        // Save version / migration
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 14
        migrationGiftApplied = try c.decodeIfPresent(Bool.self, forKey: .migrationGiftApplied) ?? false
    }
}

// MARK: - Block model (current dig face)

enum DDMBlockKind: Equatable {
    case normal
    case treasure   // geode — bonus gold / gem find / rare ore burst
    case boss       // bedrock gate at a zone boundary
}

struct DDMBlock {
    let depth: Int
    let maxHP: Double
    var hp: Double
    let oreType: DDMOre?     // ore vein in this block (nil = plain rubble)
    let oreAmount: Double    // ore units dropped when cleared
    let rubbleGold: Double   // small base gold from rubble
    let kind: DDMBlockKind   // normal / treasure / boss
    // Treasure / boss reward seeds (resolved at clear time via store stats).
    let bonusGold: Double    // extra gold awarded on clear (treasure/boss)
    let gemReward: Int       // gems awarded on clear (treasure/boss)
    let bonusOre: DDMOre?    // burst of rare ore on clear
    let bonusOreAmount: Double

    var isBoss: Bool { kind == .boss }
    var isTreasure: Bool { kind == .treasure }
}

// MARK: - Block / depth math (deterministic)

enum DDMWorld {
    // Depth milestone thresholds that grant a one-time gold+gem reward.
    static let milestones: [Int] = [50, 120, 250, 450, 700, 1_000, 1_400, 2_000, 2_800, 4_000, 6_000,
                                    7_500, 9_000, 11_000, 14_000]

    static func milestoneReward(_ m: Int) -> (gold: Double, gems: Int) {
        // v14: pure LINEAR — gold = 5 × m. d=50 → 250, d=500 → 2500, d=5000 → 25000.
        // Recognition pickup, not income source. No exponent, no surprises.
        let gold = 5.0 * Double(m)
        let gems = max(1, m / 500)
        return (gold.rounded(), gems)
    }

    // HP of a block at a given depth. v15.2: PURE LINEAR — `60 + 6*depth`, boss block × 8.
    // depth=0 → 60, depth=80 → 540, depth=99 (boss) → 654×8=5232. Predictable forever.
    // Zone hpMult is 1.0 for all zones (cosmetic only) — depth alone drives difficulty.
    static func blockHP(depth: Int) -> Double {
        precondition(depth >= 0, "blockHP: depth must be non-negative, got \(depth)")
        let base = 60.0 + 6.0 * Double(depth)
        let mult = DDMZone.isBossDepth(depth) ? 8.0 : 1.0
        let hp = base * mult
        return hp.isFinite ? max(1.0, hp) : 1.0
    }

    // Generate a block deterministically from depth.
    static func block(at depth: Int) -> DDMBlock {
        var rng = DDMRandom(seed: ddmSeed(depth, 0xDEEB))
        let hp = blockHP(depth: depth)
        let zone = DDMZone.zone(at: depth)

        // determine the richest ore unlocked by this depth, then pick from a band.
        let unlocked = DDMOre.allCases.filter { $0.unlockDepth <= depth }
        let topIndex = (unlocked.last?.rawValue ?? 0)

        // v15.2: 15% ore chance, FIXED 1 unit drop amount (no depth slope). Ore
        // VALUE scales via the flat tier gradient + bonusMultiplier.
        let oreChance = 0.15
        var oreType: DDMOre? = nil
        var oreAmount: Double = 0

        if rng.chance(oreChance) && !unlocked.isEmpty {
            let lowest = max(0, topIndex - 2)
            let pick = rng.nextInt(lowest, topIndex)
            oreType = DDMOre(rawValue: pick)
            oreAmount = 1.0
        }

        // v15.2: rubble is purely LINEAR in depth — `0.2 + 0.2*depth`. Zone goldMult is 1.0
        // so this is the canonical per-block gold income. d=0 → 0.2→1, d=80 → 16.2, d=99 → 20.
        // Boss block gets ×3 rubble. No extra boss gold formula.
        let rubble = (0.2 + 0.2 * Double(depth)).rounded()

        // Boss gate. v15: rubble × 3 (inline — no separate add). Gems awarded at collapse only.
        if DDMZone.isBossDepth(depth) {
            let bossGold = (rubble * 3.0).rounded()
            let richOre = unlocked.last ?? .coal
            let bossOreAmt = Double(rng.nextInt(5, 10))
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .boss,
                            bonusGold: bossGold, gemReward: 0,
                            bonusOre: richOre, bonusOreAmount: bossOreAmt)
        }

        // Treasure / geode? deterministic, seeded from depth.
        let treasureRoll = rng.nextDouble()
        if depth > 5 && treasureRoll < 0.035 {
            // v15: treasure is rubble × 2 + d × 3 — gentle gold bonus only. NO gem award
            // (gems are awarded at collapse only — spec §6).
            let tGold = (rubble * 2.0 + Double(depth) * 3.0).rounded()
            let richOre = unlocked.last ?? .coal
            let tOreAmt = Double(rng.nextInt(3, 6))
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .treasure,
                            bonusGold: tGold, gemReward: 0,
                            bonusOre: richOre, bonusOreAmount: tOreAmt)
        }

        return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                        oreType: oreType, oreAmount: oreAmount,
                        rubbleGold: max(1, rubble), kind: .normal,
                        bonusGold: 0, gemReward: 0,
                        bonusOre: nil, bonusOreAmount: 0)
    }
}
