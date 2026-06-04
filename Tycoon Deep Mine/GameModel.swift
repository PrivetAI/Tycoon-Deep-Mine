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
    case mithril    // exotic
    case obsidian   // exotic
    case adamantite // deep exotic
    case voidstone  // deep exotic
    case starmetal  // deep exotic
    case aetherium  // deepest exotic

    var name: String {
        switch self {
        case .coal: return "Coal"
        case .copper: return "Copper"
        case .tin: return "Tin"
        case .iron: return "Iron"
        case .silver: return "Silver"
        case .gold: return "Gold Ore"
        case .ruby: return "Ruby"
        case .emerald: return "Emerald"
        case .sapphire: return "Sapphire"
        case .diamond: return "Diamond"
        case .mithril: return "Mithril"
        case .obsidian: return "Obsidian"
        case .adamantite: return "Adamantite"
        case .voidstone: return "Voidstone"
        case .starmetal: return "Starmetal"
        case .aetherium: return "Aetherium"
        }
    }

    // Base sell value per unit of ore. v14: ratio compressed to ×1.4 per tier.
    // Total span coal=1 → aetherium=159 — gentle climb, gold growth instead comes from
    // additive level counts across multiple bonus lines.
    var baseValue: Double {
        switch self {
        case .coal: return 1
        case .copper: return 1.4
        case .tin: return 2
        case .iron: return 2.8
        case .silver: return 3.9
        case .gold: return 5.5
        case .ruby: return 7.7
        case .emerald: return 10.8
        case .sapphire: return 15.1
        case .diamond: return 21.2
        case .mithril: return 29.7
        case .obsidian: return 41.5
        case .adamantite: return 58
        case .voidstone: return 81
        case .starmetal: return 114
        case .aetherium: return 159
        }
    }

    // Depth (meters) at which this ore begins to appear.
    var unlockDepth: Int {
        switch self {
        case .coal: return 0
        case .copper: return 15
        case .tin: return 40
        case .iron: return 80
        case .silver: return 140
        case .gold: return 230
        case .ruby: return 360
        case .emerald: return 540
        case .sapphire: return 780
        case .diamond: return 1_100
        case .mithril: return 1_500
        case .obsidian: return 2_000
        case .adamantite: return 2_700
        case .voidstone: return 3_600
        case .starmetal: return 4_800
        case .aetherium: return 6_400
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
        case .mithril: return Color(red: 0.60, green: 0.80, blue: 0.78)
        case .obsidian: return Color(red: 0.32, green: 0.18, blue: 0.40)
        case .adamantite: return Color(red: 0.48, green: 0.84, blue: 0.62)
        case .voidstone: return Color(red: 0.30, green: 0.16, blue: 0.46)
        case .starmetal: return Color(red: 0.62, green: 0.70, blue: 0.96)
        case .aetherium: return Color(red: 0.96, green: 0.86, blue: 0.56)
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

    // v14: zones are now COSMETIC (theme/palette) + a soft hpMult gate. goldMult and
    // oreMult ALL set to 1.0 — depth alone drives income via the linear rubble/ore
    // formulas in block(at:). This eliminates the per-zone income surge that survived
    // all the structural fixes through build 19.
    static let all: [DDMZone] = [
        DDMZone(index: 0, name: "Topsoil", startDepth: 0, endDepth: 80,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.45, green: 0.32, blue: 0.21),
                bandB: Color(red: 0.33, green: 0.23, blue: 0.15),
                baseFill: Color(red: 0.30, green: 0.21, blue: 0.13),
                accent: Color(red: 0.57, green: 0.42, blue: 0.28)),
        DDMZone(index: 1, name: "Stone Shelf", startDepth: 80, endDepth: 230,
                hpMult: 1.2, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.40, green: 0.36, blue: 0.33),
                bandB: Color(red: 0.30, green: 0.27, blue: 0.24),
                baseFill: Color(red: 0.26, green: 0.24, blue: 0.22),
                accent: Color(red: 0.52, green: 0.47, blue: 0.43)),
        DDMZone(index: 2, name: "Crystal Caverns", startDepth: 230, endDepth: 540,
                hpMult: 1.5, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.26, green: 0.34, blue: 0.46),
                bandB: Color(red: 0.18, green: 0.25, blue: 0.36),
                baseFill: Color(red: 0.14, green: 0.20, blue: 0.30),
                accent: Color(red: 0.46, green: 0.74, blue: 0.86)),
        DDMZone(index: 3, name: "Magma Veins", startDepth: 540, endDepth: 1_100,
                hpMult: 1.8, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.46, green: 0.20, blue: 0.14),
                bandB: Color(red: 0.34, green: 0.13, blue: 0.09),
                baseFill: Color(red: 0.28, green: 0.10, blue: 0.07),
                accent: Color(red: 0.96, green: 0.52, blue: 0.20)),
        DDMZone(index: 4, name: "The Abyss", startDepth: 1_100, endDepth: 2_000,
                hpMult: 2.2, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.22, green: 0.18, blue: 0.34),
                bandB: Color(red: 0.15, green: 0.12, blue: 0.26),
                baseFill: Color(red: 0.11, green: 0.09, blue: 0.20),
                accent: Color(red: 0.62, green: 0.52, blue: 0.92)),
        DDMZone(index: 5, name: "World's Core", startDepth: 2_000, endDepth: 2_700,
                hpMult: 2.6, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.40, green: 0.30, blue: 0.10),
                bandB: Color(red: 0.28, green: 0.20, blue: 0.06),
                baseFill: Color(red: 0.20, green: 0.14, blue: 0.04),
                accent: Color(red: 0.98, green: 0.78, blue: 0.30)),
        DDMZone(index: 6, name: "Mantle Forge", startDepth: 2_700, endDepth: 3_600,
                hpMult: 3.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.46, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.34, blue: 0.25),
                baseFill: Color(red: 0.08, green: 0.24, blue: 0.18),
                accent: Color(red: 0.42, green: 0.92, blue: 0.66)),
        DDMZone(index: 7, name: "The Void Rift", startDepth: 3_600, endDepth: 4_800,
                hpMult: 3.4, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.12, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.07, blue: 0.24),
                baseFill: Color(red: 0.09, green: 0.05, blue: 0.18),
                accent: Color(red: 0.66, green: 0.40, blue: 0.96)),
        DDMZone(index: 8, name: "Stellar Vault", startDepth: 4_800, endDepth: 6_400,
                hpMult: 3.8, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.20, green: 0.26, blue: 0.46),
                bandB: Color(red: 0.13, green: 0.18, blue: 0.36),
                baseFill: Color(red: 0.08, green: 0.12, blue: 0.28),
                accent: Color(red: 0.62, green: 0.74, blue: 0.98)),
        DDMZone(index: 9, name: "Aether Wellspring", startDepth: 6_400, endDepth: Int.max,
                hpMult: 4.2, goldMult: 1.0, oreMult: 1.0,
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

    // v15 ladder. Cost growth UNIFORM 1.15 — Cookie Clicker territory.
    static let all: [DDMUpgradeDef] = [
        DDMUpgradeDef(kind: .pickaxe, title: "Pickaxe Power",
                      blurb: "+0.5 tap damage per level.",
                      baseCost: 5, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .cart, title: "Mine Cart",
                      blurb: "Auto-collects and auto-sells mined ore.",
                      baseCost: 30, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillCount, title: "Drill Rig",
                      blurb: "Adds an auto-drill (+0.5 base DPS each).",
                      baseCost: 100, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillSpeed, title: "Drill Tuning",
                      blurb: "+0.10 DPS per drill per level.",
                      baseCost: 500, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .oreValue, title: "Ore Grader",
                      blurb: "+10% ore sell value per level.",
                      baseCost: 200, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .refiner, title: "Refiner",
                      blurb: "+5% sale gold per level.",
                      baseCost: 800, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .multiTap, title: "Multi-Strike",
                      blurb: "Each tap lands +1 extra strike per level.",
                      baseCost: 20_000, costGrowth: 1.15, maxLevel: 10),
        DDMUpgradeDef(kind: .autoTapper, title: "Auto Pick",
                      blurb: "A mechanical arm auto-taps for you (+0.2/sec per level).",
                      baseCost: 50_000, costGrowth: 1.15, maxLevel: 200)
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
    let costGrowth: Double
    let maxLevel: Int

    var id: String { kind.rawValue }

    func cost(at level: Int) -> Int {
        let c = Double(baseCost) * pow(costGrowth, Double(level))
        if !c.isFinite { return Int.max }
        return Int(c.rounded())
    }

    static let all: [DDMGlobalDef] = [
        DDMGlobalDef(kind: .startDepth, title: "Shaft Head Start",
                     blurb: "Begin each collapse 15 m deeper per level.",
                     baseCost: 4, costGrowth: 1.6, maxLevel: 200),
        DDMGlobalDef(kind: .offlineCap, title: "Night Shift",
                     blurb: "+2 h offline earnings cap per level.",
                     baseCost: 4, costGrowth: 1.6, maxLevel: 60),
        DDMGlobalDef(kind: .autoStart, title: "Standing Rig",
                     blurb: "Keep 2 extra drills after collapse per level.",
                     baseCost: 5, costGrowth: 1.6, maxLevel: 60),
        DDMGlobalDef(kind: .startGold, title: "Seed Vault",
                     blurb: "Begin each collapse with a larger gold stake.",
                     baseCost: 6, costGrowth: 1.6, maxLevel: 50),
        DDMGlobalDef(kind: .widePan, title: "Wide Pan",
                     blurb: "+1 cart level at the start of each run.",
                     baseCost: 5, costGrowth: 1.6, maxLevel: 10)
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

    // HP of a block at a given depth. v14: PURE LINEAR — `50 + d * 10`, no exponential.
    // The exponential coefficient (1.020^d) doubled HP every 35 m and created an
    // impassable wall in late game and a flat early game. Linear means each depth costs
    // 10 more HP than the previous, predictable forever. Zone hpMult adds a soft step.
    static func blockHP(depth: Int) -> Double {
        let d = Double(max(0, depth))
        let zone = DDMZone.zone(at: depth)
        let base = 50.0 + d * 10.0
        var hp = base * zone.hpMult
        if DDMZone.isBossDepth(depth) {
            hp *= 5.0  // boss is 5× harder
        }
        return hp.isFinite ? max(50.0, hp) : 50.0
    }

    // Generate a block deterministically from depth.
    static func block(at depth: Int) -> DDMBlock {
        var rng = DDMRandom(seed: ddmSeed(depth, 0xDEEB))
        let hp = blockHP(depth: depth)
        let zone = DDMZone.zone(at: depth)

        // determine the richest ore unlocked by this depth, then pick from a band.
        let unlocked = DDMOre.allCases.filter { $0.unlockDepth <= depth }
        let topIndex = (unlocked.last?.rawValue ?? 0)

        // v14: fixed 35% ore chance, FIXED 1 unit drop amount (no depth slope). Ore
        // VALUE scales via the ×1.4 tier ladder + goldBonusSum. Predictable.
        let oreChance = 0.35
        var oreType: DDMOre? = nil
        var oreAmount: Double = 0

        if rng.chance(oreChance) && !unlocked.isEmpty {
            let lowest = max(0, topIndex - 2)
            let pick = rng.nextInt(lowest, topIndex)
            oreType = DDMOre(rawValue: pick)
            oreAmount = 1.0
        }

        // v14: rubble is purely LINEAR in depth — `1 + d * 2`. Zone goldMult is now 1.0
        // so this is the canonical per-block gold income. d=10 → 21, d=100 → 201,
        // d=1000 → 2001. Sustainable forever.
        let rubble = (1.0 + Double(depth) * 2.0).rounded()

        // Boss gate. v14: rubble × 3 + d × 10 — linear, predictable jackpot. Gem reward
        // is a small constant flow toward prestige.
        if DDMZone.isBossDepth(depth) {
            let bossGold = (rubble * 3.0 + Double(depth) * 10.0).rounded()
            let bossGems = max(1, depth / 500)
            let richOre = unlocked.last ?? .coal
            let bossOreAmt = Double(rng.nextInt(5, 10))
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .boss,
                            bonusGold: bossGold, gemReward: bossGems,
                            bonusOre: richOre, bonusOreAmount: bossOreAmt)
        }

        // Treasure / geode? deterministic, seeded from depth.
        let treasureRoll = rng.nextDouble()
        if depth > 5 && treasureRoll < 0.035 {
            // v14: treasure is rubble × 2 + d × 3 — gentle one-time bonus.
            let tGold = (rubble * 2.0 + Double(depth) * 3.0).rounded()
            let tGem = rng.chance(0.10) ? 1 : 0
            let richOre = unlocked.last ?? .coal
            let tOreAmt = Double(rng.nextInt(3, 6))
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .treasure,
                            bonusGold: tGold, gemReward: tGem,
                            bonusOre: richOre, bonusOreAmount: tOreAmt)
        }

        return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                        oreType: oreType, oreAmount: oreAmount,
                        rubbleGold: max(1, rubble), kind: .normal,
                        bonusGold: 0, gemReward: 0,
                        bonusOre: nil, bonusOreAmount: 0)
    }
}
