import SwiftUI

// MARK: - Research tech tree
//
// Research Points accrue passively from the deepest depth reached (a banked basis, so
// re-reaching old depth pays nothing). Techs are bought with RP and give permanent
// multipliers / unlocks that persist through collapse (they're meta progress, reset only
// by a full reset). Costs scale steeply per level.

enum DDMTechKind: String, Codable, CaseIterable {
    case sharpTools    // +tap damage mult
    case turboDrills   // +auto damage mult
    case assayers      // +ore value mult
    case logistics     // +cart auto-sell rate
    case deepScan      // +treasure & gem chance
    case smelting      // +smelt rate
    case oreRichness   // +ore amount per block
    case efficiency    // -upgrade cost growth (cheaper upgrades)
}

struct DDMTechDef: Identifiable {
    let kind: DDMTechKind
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

    static let all: [DDMTechDef] = [
        DDMTechDef(kind: .sharpTools, title: "Sharpened Tools",
                   blurb: "+6% global mining damage per level.",
                   baseCost: 12, costGrowth: 1.6, maxLevel: 100),
        DDMTechDef(kind: .turboDrills, title: "Turbo Drilling",
                   blurb: "+8% auto mining output per level.",
                   baseCost: 18, costGrowth: 1.62, maxLevel: 100),
        DDMTechDef(kind: .assayers, title: "Assay Office",
                   blurb: "+6% ore & bar sell value per level.",
                   baseCost: 20, costGrowth: 1.62, maxLevel: 100),
        DDMTechDef(kind: .logistics, title: "Rail Logistics",
                   blurb: "+25% mine-cart auto-sell rate per level.",
                   baseCost: 30, costGrowth: 1.7, maxLevel: 40),
        DDMTechDef(kind: .deepScan, title: "Deep Scan",
                   blurb: "+12% geode & gem find per level.",
                   baseCost: 40, costGrowth: 1.7, maxLevel: 30),
        DDMTechDef(kind: .smelting, title: "Smelt Science",
                   blurb: "+20% smelting speed per level.",
                   baseCost: 35, costGrowth: 1.68, maxLevel: 40),
        DDMTechDef(kind: .oreRichness, title: "Vein Mapping",
                   blurb: "+10% ore mined per block per level.",
                   baseCost: 28, costGrowth: 1.66, maxLevel: 50),
        DDMTechDef(kind: .efficiency, title: "Lean Engineering",
                   blurb: "Upgrades cost up to 18% less (per level, diminishing).",
                   baseCost: 60, costGrowth: 1.85, maxLevel: 20)
    ]

    static func def(_ kind: DDMTechKind) -> DDMTechDef {
        all.first(where: { $0.kind == kind })!
    }
}

// MARK: - Smelter
//
// A processing step: raw ore can be smelted into BARS worth far more than the raw ore.
// Smelting takes time (smelt rate, in ore-units/sec). Bars sell for a tier-scaled
// multiple of the raw ore value. Upgrades (bought with GOLD) raise smelt rate and bar
// value. The forge runs in the background like the cart.

enum DDMSmelterKind: String, Codable, CaseIterable {
    case rate     // ore units smelted per second
    case barValue // bonus value on each bar
    case batch    // bars produced per ore unit (yield)
}

struct DDMSmelterDef: Identifiable {
    let kind: DDMSmelterKind
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

    static let all: [DDMSmelterDef] = [
        DDMSmelterDef(kind: .rate, title: "Furnace Intake",
                      blurb: "+1.5 ore/s fed into the furnace per level.",
                      baseCost: 8_000, costGrowth: 1.45, maxLevel: 9999),
        DDMSmelterDef(kind: .barValue, title: "Bar Purity",
                      blurb: "+12% value on every smelted bar per level.",
                      baseCost: 15_000, costGrowth: 1.46, maxLevel: 9999),
        DDMSmelterDef(kind: .batch, title: "Casting Molds",
                      blurb: "+8% bar yield per ore unit per level.",
                      baseCost: 25_000, costGrowth: 1.5, maxLevel: 60)
    ]

    static func def(_ kind: DDMSmelterKind) -> DDMSmelterDef {
        all.first(where: { $0.kind == kind })!
    }
}

// Per-ore mastery cost: scales with the ore's tier so deep ores cost vastly more to master.
enum DDMOreMastery {
    static func cost(_ ore: DDMOre, level: Int) -> Double {
        // base anchored to the ore's own value so mastery feels proportional, then steep growth.
        let base = max(50.0, ore.baseValue * 4.0)
        let c = base * pow(1.6, Double(level))
        return c.isFinite ? c.rounded() : Double.greatestFiniteMagnitude
    }
    static let maxLevel = 50
}
