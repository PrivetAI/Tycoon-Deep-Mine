import SwiftUI

// MARK: - Research tech tree
//
// Research Points accrue passively from the deepest depth reached (a banked basis, so
// re-reaching old depth pays nothing). Techs are bought with RP and give permanent
// multipliers / unlocks that persist through collapse (they're meta progress, reset only
// by a full reset). Costs scale steeply per level.

enum DDMTechKind: String, Codable, CaseIterable, Hashable {
    case sharpTools      // +1% bonusSum / level
    case veinMapping     // +1% bonusSum / level
    case cartLogistics   // +0.1 ore/s / level (direct, NOT via bonusSum)
    case smeltScience    // +0.2 ore/s / level inside smelter (direct, Task 17 uses this)
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

    // v15.1: tripled base costs, growth 1.25, effects halved.
    static let all: [DDMTechDef] = [
        DDMTechDef(kind: .sharpTools, title: "Sharpened Tools",
                   blurb: "+0.5% to global bonus multiplier per level.",
                   baseCost: 30, costGrowth: 1.25, maxLevel: 30),
        DDMTechDef(kind: .veinMapping, title: "Vein Mapping",
                   blurb: "+0.5% to global bonus multiplier per level.",
                   baseCost: 40, costGrowth: 1.25, maxLevel: 30),
        DDMTechDef(kind: .cartLogistics, title: "Cart Logistics",
                   blurb: "+0.05 ore/s cart rate per level (direct).",
                   baseCost: 60, costGrowth: 1.25, maxLevel: 30),
        DDMTechDef(kind: .smeltScience, title: "Smelt Science",
                   blurb: "+0.1 ore/s smelter throughput per level (direct).",
                   baseCost: 80, costGrowth: 1.25, maxLevel: 30)
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

enum DDMSmelterKind: String, CaseIterable, Codable, Hashable {
    case furnace
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
        DDMSmelterDef(kind: .furnace, title: "Furnace",
                      blurb: "+0.2 ore/s fed into the furnace per level.",
                      baseCost: 25_000, costGrowth: 1.20, maxLevel: 9_999)
    ]

    static func def(_ kind: DDMSmelterKind) -> DDMSmelterDef {
        all.first(where: { $0.kind == kind })!
    }
}


