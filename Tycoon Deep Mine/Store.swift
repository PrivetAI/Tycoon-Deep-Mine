import SwiftUI
import Combine
import UIKit

final class DDMStore: ObservableObject {
    @Published var save = DDMSave()
    @Published var settings = DDMSettings()
    @Published var unlockedAchievements: Set<String> = []
    @Published var lastUnlocked: [String] = []

    // Transient UI state
    @Published var currentBlock: DDMBlock
    @Published var floatingHits: [DDMFloatingHit] = []
    @Published var offlineSummary: DDMOfflineSummary? = nil

    private var timer: Timer?
    private var lastTick: Date = Date()
    private var saveAccumulator: Double = 0

    // v15.5: full economy REWRITE FROM SCRATCH per user direction. 19 builds of tuning
    // converged on these structural rules — this is the canonical implementation:
    //   * HP curve LINEAR (`50 + d*10` * hpMult) — no `pow(1.020, d)` anywhere
    //   * Block rubble LINEAR (`1 + d*2`) — no zone goldMult cascade
    //   * Ore drop amount FIXED (always 1 per drop, 35% chance) — no depth slope
    //   * Ore tier ratio ×1.4 per tier (was ×3.5 → ×2.0 → ×1.5 → finally ×1.4)
    //   * Zone goldMult / oreMult ELIMINATED (zones are purely cosmetic + hpMult)
    //   * Cost growth UNIFORM 1.15 (Cookie Clicker)
    //   * Gem prestige SUB-LINEAR: floor((runMaxDepth/100)^0.55), gated at depth>=100 (spec §7)
    //   * Tap = (1 + L*0.5) * bonusMultiplier. Drill perDrill = 0.5 + speed/turbo addends.
    //   * bonusSum (capped +300%) is the ONLY composite multiplier anywhere (Spec §2).
    private static let saveKey = "ddm.save.v15"
    private static let saveKeyV14 = "ddm.save.v14"   // legacy – read-once for migration
    private static let achKey = "ddm.achievements.v1"
    private static let settingsKey = "ddm.settings.v1"

    init() {
        // temporary placeholder before load
        currentBlock = DDMWorld.block(at: 0)
        load()
        // (re)build current block
        rebuildCurrentBlock()
        creditOfflineEarnings()
        startTimer()
        observeLifecycle()
    }

    // MARK: - Derived stats

    func upgradeLevel(_ kind: DDMUpgradeKind) -> Int {
        save.upgrades[kind.rawValue] ?? 0
    }

    func globalLevel(_ kind: DDMGlobalKind) -> Int {
        save.globals[kind.rawValue] ?? 0
    }

    // --- v15: SINGLE UNIFIED BONUS SUM (Spec §2 invariant 1) ---
    // All amplifier upgrades feed one bonusSum. Final multiplier is (1 + bonusSum).
    // Hard-capped at +300% (raw ≤ 3.0, multiplier ≤ 4.0×). Linear in level count,
    // not exponential in product-of-multipliers. Gold AND damage share the same bucket.

    /// Spec §2 invariant 1: the ONLY multiplicative bucket on gold AND damage.
    /// Hard-capped at +100% (raw value <= 1.0, final multiplier <= 2.0x).
    var bonusSum: Double {
        let oreGrader   = Double(upgradeLevel(.oreValue)) * 0.005   // was 0.008
        let refiner     = Double(upgradeLevel(.refiner))  * 0.0025  // was 0.004
        let sharpTools  = Double(techLevel(.sharpTools))  * 0.001   // was 0.002
        let veinMapping = Double(techLevel(.veinMapping)) * 0.001   // was 0.002
        let gemBonus    = Double(max(0, save.gems)) * 0.0005        // was 0.0008
        let raw = oreGrader + refiner + sharpTools + veinMapping + gemBonus
        precondition(raw >= 0, "bonusSum components must be non-negative")
        return min(raw, 1.0)   // WAS 1.5 — now +100% cap (final mult x2.0)
    }

    /// Convenience: the final multiplier applied at every site.
    var bonusMultiplier: Double { 1.0 + bonusSum }

    // --- Compatibility shims for existing call sites ---
    // These properties used to be the multiplicative chains; now they return the
    // sum-based equivalent so HUD / preview code keeps compiling and showing a useful
    // number. Internal call sites have been updated to use bonusMultiplier directly.
    var gemMultiplier: Double { 1.0 + Double(max(0, save.gems)) * 0.005 }
    var yieldMultiplier: Double { bonusMultiplier }
    var damageMultiplier: Double { bonusMultiplier }

    // Number of strikes a single tap delivers (Multi-Strike).
    var tapStrikes: Int {
        1 + upgradeLevel(.multiTap)
    }

    // Per-strike tap (pickaxe) damage. v15.5: base 0.5 + 0.005/L. L0=0.5, L10=0.55, L100=1.0. Spec §5.
    var tapDamage: Double {
        let lvl = upgradeLevel(.pickaxe)
        let base = 0.5 + Double(lvl) * 0.005
        let d = base * bonusMultiplier
        return d.isFinite ? max(0.1, d) : 0.1
    }

    // Full damage of one tap action (all strikes combined). Used for display only —
    // strikes are applied individually so HP/clears stay consistent.
    var tapDamageTotal: Double {
        let d = tapDamage * Double(tapStrikes)
        return d.isFinite ? max(1, d) : 1
    }

    // Auto drill damage per second. v15.5: count = drillCount + autoStart*1 free drills.
    // perDrill = 0.10 + drillSpeed*0.025. Total = count × perDrill × bonusMultiplier. Spec §5.
    // turboDrills tech contribution stubbed for Task 16.
    var autoDPS: Double {
        let countLvl = upgradeLevel(.drillCount)
        let count = Double(countLvl) + Double(globalLevel(.autoStart)) * 1.0
        if count <= 0 { return 0 }
        let perDrill = 0.10 + Double(upgradeLevel(.drillSpeed)) * 0.025
        let dps = count * perDrill * bonusMultiplier
        return dps.isFinite ? max(0, dps) : 0
    }

    // Auto-tapper: mechanical arm that delivers tap-strength hits automatically.
    // v15.5: +0.0002 auto-taps/sec per level (5x reduction from v15.4's 0.001).
    var autoTapRate: Double {
        let lvl = upgradeLevel(.autoTapper)
        let r = Double(lvl) * 0.0002
        return r.isFinite ? max(0, r) : 0
    }

    var autoTapDPS: Double {
        let d = autoTapRate * tapDamage
        return d.isFinite ? max(0, d) : 0
    }

    var oreValueMultiplier: Double { bonusMultiplier }
    // Per-unit ore value. Single bonusMultiplier applied here; no re-application downstream.
    func oreUnitValue(_ ore: DDMOre) -> Double {
        let v = ore.baseValue * bonusMultiplier
        return v.isFinite ? max(0, v) : 0
    }

    // MARK: - Research derived stats

    func techLevel(_ kind: DDMTechKind) -> Int {
        save.techs[kind.rawValue] ?? 0
    }

    // v15 Spec §8: sharpTools/veinMapping now feed bonusSum directly (see bonusSum above).
    // These shims return 1.0 so any residual call sites compile without change.
    var researchDamageMultiplier: Double { 1.0 }
    var researchGoldMultiplier: Double   { 1.0 }

    // v15 Spec §8: efficiency tech removed; upgrade costs use pure 1.15 growth, no discount.
    var upgradeCostMultiplier: Double { 1.0 }

    // MARK: - Smelter derived stats

    func smelterLevel(_ kind: DDMSmelterKind) -> Int {
        save.smelterUpgrades[kind.rawValue] ?? 0
    }

    // Is the smelter unlocked at all? (any furnace level)
    var hasSmelter: Bool { smelterLevel(.furnace) > 0 }

    // Ore units fed into the furnace per second. Spec §9.
    // v15.3: base 0.15 + furnace*0.08 + smeltScience*0.03 (was 0.04)
    var smeltRate: Double {
        let lvl = smelterLevel(.furnace)
        if lvl <= 0 { return 0 }
        let base    = 0.15
        let furnace = Double(lvl) * 0.08
        let science = Double(techLevel(.smeltScience)) * 0.03
        let r = base + furnace + science
        return r.isFinite ? max(0, r) : 0
    }

    /// Spec §9: bar value = ore.baseValue * 1.6, multiplied by the SAME bonusSum
    /// every other gold source uses. No purity / batch / smelterCore chain.
    /// v15.4: premium up from 1.2 → 1.6 to scale with ×5 ore tier values.
    func barUnitValue(_ ore: DDMOre) -> Double {
        let v = ore.baseValue * 1.6 * bonusMultiplier
        return v.isFinite ? max(0, v) : 0
    }

    var totalHeldBars: Double {
        save.bars.values.reduce(0, +)
    }

    var heldBarsValue: Double {
        var v: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                v += count * barUnitValue(ore)
            }
        }
        return v
    }

    // Cart auto-collect & auto-sell rate (ore units / second processed). 0 = manual only.
    // v15.4: (cartLevel + widePan) * 0.08. cartLogistics tech +0.02 ore/s / level.
    // Spec §5.
    var cartRate: Double {
        let lvl = upgradeLevel(.cart) + globalLevel(.widePan)
        if lvl <= 0 { return 0 }
        let techBonus = Double(techLevel(.cartLogistics)) * 0.02  // +0.02 ore/s / level
        let r = Double(lvl) * 0.08 + techBonus
        return r.isFinite ? r : 0
    }

    // Cart capacity: 10 base + 2 per cart/widePan level. v15.4: boosted to carry 2× ore throughput. Spec §5.
    var cartCapacity: Int {
        return 10 + 2 * (upgradeLevel(.cart) + globalLevel(.widePan))
    }

    var hasAutoSell: Bool { cartRate > 0 }

    var offlineCapSeconds: Double {
        let baseHours = 2.0 + Double(globalLevel(.offlineCap)) * 2.0
        return baseHours * 3600.0
    }

    // Estimated gold/sec from auto systems (for display + offline remainder estimate).
    // v13: now also INCLUDES the cart auto-sell rate of any existing ore stash, so the
    // HUD's "Gold/s" value matches the actual gold counter motion. Before this fix the
    // HUD showed 0 while cart was draining 23K of held ore at 50 g/sec — gold appeared
    // to materialise on every tap, which the user read as "tap mints gold".
    var goldPerSecond: Double {
        guard hasAutoSell else { return 0 }
        let hp = max(1.0, currentBlock.maxHP)
        let blocksPerSec = (autoDPS + autoTapDPS) / hp
        var perBlockGold = estimatedBlockGold(currentBlock)
        if hasSmelter { perBlockGold *= 1.8 }
        var g = blocksPerSec * perBlockGold
        // Cart selling existing ore stash also contributes a steady gold rate.
        let totalOre = totalHeldOre
        if totalOre > 0 {
            let avgValue = heldOreValue / totalOre
            g += min(cartRate, totalOre) * avgValue
        }
        return g.isFinite ? max(0, g) : 0
    }

    private func estimatedBlockGold(_ b: DDMBlock) -> Double {
        let bonus = bonusMultiplier
        var g = b.rubbleGold * bonus
        if let ore = b.oreType {
            g += b.oreAmount * oreUnitValue(ore)
        }
        return g
    }

    // MARK: - Block lifecycle

    func rebuildCurrentBlock() {
        var b = DDMWorld.block(at: save.depth)
        if save.currentBlockHP >= 0 && save.currentBlockHP <= b.maxHP {
            b.hp = save.currentBlockHP
        }
        currentBlock = b
        save.currentBlockHP = b.hp
    }

    // MARK: - Tapping

    func tapDig() {
        save.totalTaps += 1
        let strikes = tapStrikes
        let perStrike = tapDamage
        // Show the combined hit, but apply each strike individually so a multi-strike tap
        // can roll over into the next block cleanly.
        let total = perStrike * Double(max(1, strikes))
        addFloatingHit(amount: total)
        for _ in 0..<max(1, strikes) {
            applyDamage(perStrike, manual: false)
        }
        if settings.hapticsOn {
            DDMHaptics.tap()
        }
        checkAchievements()
        throttledSaveTick(force: false)
    }

    private func addFloatingHit(amount: Double) {
        // Damage numbers — prefixed with "-" so they unambiguously read as HP subtracted,
        // not gold added. Combined with the white/red colors in MineView, this rules out
        // the perceptual "tap = gold" coupling that drove 18 rounds of misread feedback.
        let text = "-\(DDMFormat.number(amount))"
        let hit = DDMFloatingHit(id: UUID(), text: text, crit: false)
        floatingHits.append(hit)
        if floatingHits.count > 6 { floatingHits.removeFirst(floatingHits.count - 6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.floatingHits.removeAll { $0.id == hit.id }
        }
    }

    private func applyDamage(_ amount: Double, manual: Bool) {
        guard amount > 0 else { return }
        var block = currentBlock
        block.hp -= amount
        if block.hp <= 0 {
            clearBlock(block)
        } else {
            currentBlock = block
            save.currentBlockHP = block.hp
        }
    }

    private func clearBlock(_ block: DDMBlock) {
        awardBlockContents(block)
        // Advance depth, but never leap over a boss-gate depth.
        save.depth = nextDepth(from: save.depth, desiredAdvance: 1)
        if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
        if save.depth > save.maxDepth { save.maxDepth = save.depth }
        checkMilestones()
        rebuildCurrentBlock()
    }

    // Return the depth we should land on after clearing a block at `from`.
    // If the intended advance would jump over one or more boss-gate depths, stop at
    // the first one so the gate is always encountered and must be defeated.
    private func nextDepth(from current: Int, desiredAdvance: Int) -> Int {
        let target = current + desiredAdvance
        // Find the nearest boss depth in the open-closed interval (current, target].
        for z in DDMZone.all where z.endDepth != Int.max {
            let bd = z.endDepth - 1   // boss-gate depth for this zone
            if bd > current && bd <= target {
                return bd  // land exactly on the gate
            }
        }
        return target
    }

    private func mineOre(_ ore: DDMOre, amount: Double) {
        let cur = save.oreCounts[ore.rawValue] ?? 0
        save.oreCounts[ore.rawValue] = cur + amount
        let mined = save.oreMinedTotals[ore.rawValue] ?? 0
        save.oreMinedTotals[ore.rawValue] = mined + amount
    }

    // Award a treasure/boss block's bonus contents.
    private func awardBonus(_ block: DDMBlock) {
        guard block.kind != .normal else { return }
        if block.bonusGold > 0 {
            addGold(block.bonusGold * bonusMultiplier)
        }
        let gems = block.gemReward
        if gems > 0 {
            save.gems += gems
        }
        if let bo = block.bonusOre, block.bonusOreAmount > 0 {
            mineOre(bo, amount: block.bonusOreAmount)
        }
        if block.isBoss {
            save.bossesDefeated += 1
        } else if block.isTreasure {
            save.treasuresFound += 1
        }
    }

    // One-time depth milestone rewards (gold + gems).
    private func checkMilestones() {
        for m in DDMWorld.milestones where save.maxDepth >= m {
            if save.claimedMilestones.contains(m) { continue }
            save.claimedMilestones.append(m)
            let r = DDMWorld.milestoneReward(m)
            addGold(r.gold * bonusMultiplier)
            save.gems += r.gems
        }
    }

    // Spec §8: RP accrues as a slow linear trickle based on current depth.
    // v15.2: rate further reduced to depth/500.
    // Called from autoStep every timer tick.
    private func accrueResearch(delta: Double) {
        guard delta > 0 else { return }
        let rpPerSecond = Double(save.depth) / 500.0
        let gained = rpPerSecond * delta
        guard gained > 0 else { return }
        var r = save.research + gained
        if !r.isFinite || r > 1e300 { r = 1e300 }
        save.research = r
        var lr = save.lifetimeResearch + gained
        if !lr.isFinite || lr > 1e300 { lr = 1e300 }
        save.lifetimeResearch = lr
    }

    // MARK: - Selling

    func sellAll() {
        var earned: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * oreUnitValue(ore)
            }
        }
        save.oreCounts = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            if settings.hapticsOn { DDMHaptics.success() }
        }
        checkAchievements()
        throttledSaveTick(force: true)
    }

    func sell(_ ore: DDMOre) {
        let count = save.oreCounts[ore.rawValue] ?? 0
        guard count > 0 else { return }
        let earned = count * oreUnitValue(ore)
        save.oreCounts[ore.rawValue] = 0
        addGold(earned)
        save.lifetimeOreSold += earned
        checkAchievements()
        throttledSaveTick(force: true)
    }

    var heldOreValue: Double {
        var v: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                v += count * oreUnitValue(ore)
            }
        }
        return v
    }

    var totalHeldOre: Double {
        save.oreCounts.values.reduce(0, +)
    }

    private func addGold(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        var g = save.gold + amount
        if !g.isFinite || g > 1e300 { g = 1e300 }
        save.gold = g
        var life = save.lifetimeGoldEarned + amount
        if !life.isFinite || life > 1e300 { life = 1e300 }
        save.lifetimeGoldEarned = life
    }

    // MARK: - Purchases

    func canBuy(_ kind: DDMUpgradeKind) -> Bool {
        let def = DDMUpgradeDef.def(kind)
        let lvl = upgradeLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gold >= cost(kind)
    }

    // Gold-upgrade cost with the Lean Engineering research discount applied.
    func cost(_ kind: DDMUpgradeKind) -> Double {
        let raw = DDMUpgradeDef.def(kind).cost(at: upgradeLevel(kind))
        let c = (raw * upgradeCostMultiplier).rounded()
        return c.isFinite ? max(1, c) : raw
    }

    func buy(_ kind: DDMUpgradeKind) {
        guard canBuy(kind) else { return }
        let c = cost(kind)
        save.gold -= c
        save.upgrades[kind.rawValue] = upgradeLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    func canBuyGlobal(_ kind: DDMGlobalKind) -> Bool {
        let def = DDMGlobalDef.def(kind)
        let lvl = globalLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gems >= def.cost(at: lvl)
    }

    func globalCost(_ kind: DDMGlobalKind) -> Int {
        DDMGlobalDef.def(kind).cost(at: globalLevel(kind))
    }

    func buyGlobal(_ kind: DDMGlobalKind) {
        guard canBuyGlobal(kind) else { return }
        let c = globalCost(kind)
        save.gems -= c
        save.globals[kind.rawValue] = globalLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.success() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // --- Research techs (bought with Research Points) ---

    func techCost(_ kind: DDMTechKind) -> Double {
        DDMTechDef.def(kind).cost(at: techLevel(kind))
    }

    func canBuyTech(_ kind: DDMTechKind) -> Bool {
        let def = DDMTechDef.def(kind)
        let lvl = techLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.research >= techCost(kind)
    }

    func buyTech(_ kind: DDMTechKind) {
        guard canBuyTech(kind) else { return }
        save.research -= techCost(kind)
        if save.research < 0 { save.research = 0 }
        save.techs[kind.rawValue] = techLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // --- Smelter upgrades (bought with Gold) ---

    func smelterCost(_ kind: DDMSmelterKind) -> Double {
        DDMSmelterDef.def(kind).cost(at: smelterLevel(kind))
    }

    func canBuySmelter(_ kind: DDMSmelterKind) -> Bool {
        let def = DDMSmelterDef.def(kind)
        let lvl = smelterLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gold >= smelterCost(kind)
    }

    func buySmelter(_ kind: DDMSmelterKind) {
        guard canBuySmelter(kind) else { return }
        save.gold -= smelterCost(kind)
        if save.gold < 0 { save.gold = 0 }
        save.smelterUpgrades[kind.rawValue] = smelterLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // Sell all smelted bars for gold.
    func sellAllBars() {
        var earned: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * barUnitValue(ore)
            }
        }
        save.bars = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
            if settings.hapticsOn { DDMHaptics.success() }
        }
        checkAchievements()
        throttledSaveTick(force: true)
    }

    // MARK: - Prestige (Collapse)

    /// Spec §7: sub-linear so long runs cannot farm explosively.
    /// v15.2 exponent 0.40 (very flat). d=100 → 1, d=1000 → 2, d=5000 → 4.
    var pendingGems: Int {
        let m = max(0, save.runMaxDepth)
        guard m >= 100 else { return 0 }
        let raw = pow(Double(m) / 100.0, 0.4)
        return Int(floor(raw))
    }

    var canCollapse: Bool { pendingGems >= 1 }

    // The starting depth for a fresh run, including Shaft Head Start (gems). Clamped to keep it finite.
    // v15.2: +5 per level.
    var runStartDepth: Int {
        let d = globalLevel(.startDepth) * 5
        return max(0, min(50_000, d))
    }

    // Apply run-start bonuses (Seed Vault global perk).
    private func applyRunHeadStart() {
        // Seed Vault: +100 starting gold per level (v15.2). Spec §7.
        let seedLevels = globalLevel(.startGold)
        if seedLevels > 0 {
            let stake = 100.0 * Double(seedLevels)
            addGold(stake)
        }
    }

    func collapse() {
        let gained = pendingGems
        guard gained > 0 else { return }
        // §7 step 1: bank gems.
        save.gems += gained
        save.totalCollapses += 1
        resetRun()
        if settings.hapticsOn { DDMHaptics.heavy() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // Reset run-scoped state per spec §7.
    // RESETS: gold, currentDepth (→ runStartDepth), runMaxDepth (→ 0 then set to startDepth),
    //         in-flight ore + bars, run upgrades (save.upgrades), smelter upgrades (save.smelterUpgrades).
    // PRESERVES: save.gems, save.globals (permanent gem shop), save.techs (research),
    //            lifetime stats, achievements.
    private func resetRun() {
        // §7 step 2: run-scoped state
        save.gold = 0
        save.oreCounts = [:]
        save.bars = [:]
        save.currentBlockHP = -1
        save.runMaxDepth = 0
        // §7 step 3: run-scoped upgrades (the 8 gold-bought upgrades)
        save.upgrades = [:]
        // §7 step 4: smelter run-state
        save.smelterUpgrades = [:]
        // §7 step 6: apply permanent perks at run start
        let startDepth = runStartDepth
        save.depth = startDepth
        save.runMaxDepth = startDepth
        if startDepth > save.maxDepth { save.maxDepth = startDepth }
        applyRunHeadStart()
        rebuildCurrentBlock()
    }

    // MARK: - Timer / auto loop

    private func startTimer() {
        lastTick = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        var dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if dt < 0 { dt = 0 }
        if dt > 1.0 { dt = 1.0 } // clamp huge jumps within foreground
        autoStep(dt)
        saveAccumulator += dt
        if saveAccumulator >= 5.0 {
            saveAccumulator = 0
            persist()
        }
    }

    // Advance auto-dig, auto-tap, smelting and auto-sell by dt seconds.
    private func autoStep(_ dt: Double) {
        guard dt > 0 else { return }
        // Auto-dig (drills) + auto-tap arm both feed the damage budget.
        let dps = autoDPS + autoTapDPS
        if dps > 0 {
            var remaining = dps * dt
            // Cap auto-clears per tick. Paces descent (no instant deep-dive into
            // high-value ore -> no "billions in a minute") AND prevents the old
            // 5000-clears/tick CPU lag. Overflow DPS beyond the cap is dropped this tick.
            var guardCount = 0
            while remaining > 0 && guardCount < 4 {
                guardCount += 1
                var block = currentBlock
                if remaining >= block.hp {
                    remaining -= block.hp
                    // clear silently (no floating hit)
                    awardBlockContents(block)
                    save.depth = nextDepth(from: save.depth, desiredAdvance: 1)
                    if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
                    if save.depth > save.maxDepth { save.maxDepth = save.depth }
                    checkMilestones()
                    rebuildCurrentBlock()
                } else {
                    block.hp -= remaining
                    remaining = 0
                    currentBlock = block
                    save.currentBlockHP = block.hp
                }
            }
        }

        // Smelter: convert raw ore → bars (consumes ore the cart would otherwise sell raw).
        if hasSmelter && totalHeldOre > 0 {
            smeltStep(dt)
        }

        // Cart auto-sell (ore + bars)
        if hasAutoSell {
            if totalHeldOre > 0 { autoSellStep(dt) }
            if totalHeldBars > 0 { autoSellBarsStep(dt) }
        }

        // Spec §8: RP slow linear trickle — depth/50 per second.
        accrueResearch(delta: dt)
    }

    // Feed raw ore into the furnace, producing bars. Smelts richest ore first so the
    // valuable tiers get the premium. Bounded by smeltRate * dt.
    private func smeltStep(_ dt: Double) {
        let capacity = smeltRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        let yield: Double = 1.0  // spec §9: 1 ore → 1 bar; batch upgrade removed
        for raw in save.oreCounts.keys.sorted(by: >) {
            let count = save.oreCounts[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            save.oreCounts[raw] = count - take
            let produced = take * yield
            save.bars[raw] = (save.bars[raw] ?? 0) + produced
            remaining -= take
            if remaining <= 0 { break }
        }
    }

    private func autoSellBarsStep(_ dt: Double) {
        // Bars sell at the same cart throughput as ore.
        let capacity = cartRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        var earned: Double = 0
        for raw in save.bars.keys.sorted() {
            let count = save.bars[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            if let ore = DDMOre(rawValue: raw) {
                earned += take * barUnitValue(ore)
            }
            save.bars[raw] = count - take
            remaining -= take
            if remaining <= 0 { break }
        }
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
        }
    }

    private func awardBlockContents(_ block: DDMBlock) {
        addGold(block.rubbleGold * bonusMultiplier)
        if let ore = block.oreType, block.oreAmount > 0 {
            mineOre(ore, amount: block.oreAmount)
        }
        awardBonus(block)
    }

    private func autoSellStep(_ dt: Double) {
        let capacity = cartRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        var earned: Double = 0
        // sell from cheapest first to keep valuable ore visible? sell proportionally.
        for raw in save.oreCounts.keys.sorted() {
            let count = save.oreCounts[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            if let ore = DDMOre(rawValue: raw) {
                earned += take * oreUnitValue(ore)
            }
            save.oreCounts[raw] = count - take
            remaining -= take
            if remaining <= 0 { break }
        }
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
        }
    }

    // MARK: - Offline earnings

    private func creditOfflineEarnings() {
        let last = save.lastActive
        guard last > 0 else {
            save.lastActive = Date().timeIntervalSince1970
            return
        }
        let now = Date().timeIntervalSince1970
        var elapsed = now - last
        if elapsed < 30 { // ignore tiny gaps
            save.lastActive = now
            return
        }
        let capped = min(elapsed, offlineCapSeconds)
        elapsed = capped

        // Drills + the permanent auto-tap arm both progress offline.
        let dps = autoDPS + autoTapDPS
        guard dps > 0 else {
            save.lastActive = now
            return
        }

        // Simulate at coarse granularity, but cap iterations.
        let goldBefore = save.gold
        let oreBefore = save.oreMinedTotals
        let depthBefore = save.depth

        // Bounded offline simulation. Clear blocks until the time budget is spent OR a
        // hard work cap is hit, then credit any remaining time as a closed-form gold
        // estimate. This guarantees init NEVER freezes, no matter how high DPS is — the
        // old per-step loop could grind millions of clears (weak blocks x multiplicative
        // DPS) on the main thread at launch and trip the watchdog (black-screen launch).
        var timeLeft = capped
        var clears = 0
        let maxClears = 20_000
        while timeLeft > 0 && clears < maxClears {
            let hp = max(1.0, currentBlock.hp)
            let timeToClear = hp / dps
            if !timeToClear.isFinite || timeToClear > timeLeft {
                var b = currentBlock
                b.hp = max(0, b.hp - dps * timeLeft)
                currentBlock = b
                save.currentBlockHP = b.hp
                break
            }
            timeLeft -= timeToClear
            awardBlockContents(currentBlock)
            save.depth = nextDepth(from: save.depth, desiredAdvance: 1)
            if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
            if save.depth > save.maxDepth { save.maxDepth = save.depth }
            checkMilestones()
            rebuildCurrentBlock()
            clears += 1
        }
        // Hit the work cap with time to spare → credit the remainder as a flat estimate.
        if timeLeft > 0 && clears >= maxClears && hasAutoSell {
            let est = goldPerSecond * timeLeft
            if est.isFinite && est > 0 { addGold(est) }
        }
        // Auto-sell remaining if cart present (so offline gold reflects sales).
        if hasAutoSell {
            // If a smelter is running, convert held ore to bars first (single O(ore-types)
            // pass — bounded), then flush both ore and bars into gold.
            if hasSmelter { smeltAllSilent() }
            sellAllSilent()
            sellBarsSilent()
        }

        let goldGained = max(0, save.gold - goldBefore)
        var oreGained: Double = 0
        for (k, v) in save.oreMinedTotals {
            oreGained += v - (oreBefore[k] ?? 0)
        }
        let depthGained = save.depth - depthBefore
        save.lastActive = now

        if goldGained > 0 || oreGained > 0 || depthGained > 0 {
            offlineSummary = DDMOfflineSummary(seconds: capped,
                                               gold: goldGained,
                                               ore: oreGained,
                                               depth: depthGained,
                                               capped: (now - last) > offlineCapSeconds)
        }
    }

    private func sellAllSilent() {
        var earned: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * oreUnitValue(ore)
            }
        }
        save.oreCounts = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
        }
    }

    // Convert ALL held ore to bars in one bounded pass (offline flush only).
    private func smeltAllSilent() {
        let yield: Double = 1.0  // spec §9: 1 ore → 1 bar; batch upgrade removed
        for (raw, count) in save.oreCounts where count > 0 {
            save.bars[raw] = (save.bars[raw] ?? 0) + count * yield
        }
        save.oreCounts = [:]
    }

    private func sellBarsSilent() {
        var earned: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * barUnitValue(ore)
            }
        }
        save.bars = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
        }
    }

    func dismissOfflineSummary() {
        offlineSummary = nil
    }

    // MARK: - Achievements

    func checkAchievements() {
        var newly: [String] = []
        for ach in DDMAchievement.all {
            if unlockedAchievements.contains(ach.id) { continue }
            if ach.evaluate(self).done {
                unlockedAchievements.insert(ach.id)
                newly.append(ach.id)
            }
        }
        if !newly.isEmpty {
            lastUnlocked = newly
            persistAchievements()
        }
    }

    var unlockedCount: Int { unlockedAchievements.count }

    // MARK: - Persistence

    private func throttledSaveTick(force: Bool) {
        if force {
            persist()
        }
    }

    func persist() {
        save.lastActive = Date().timeIntervalSince1970
        save.currentBlockHP = currentBlock.hp
        let enc = JSONEncoder()
        if let data = try? enc.encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    func persistAchievements() {
        let arr = Array(unlockedAchievements)
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: Self.achKey)
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func load() {
        let d = UserDefaults.standard
        // Try the new v15 key first.
        if let data = d.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode(DDMSave.self, from: data) {
            save = decoded
            if !save.migrationGiftApplied { applyMigrationGiftIfNeeded() }
        } else if let oldData = d.data(forKey: Self.saveKeyV14),
                  let oldDecoded = try? JSONDecoder().decode(DDMSave.self, from: oldData) {
            // No v15 save yet — migrate from v14.
            // decodeIfPresent already handles unknown/extra keys in the old blob.
            migrateV14ToV15(from: oldDecoded)
        } else {
            // Brand-new install.
            save = DDMSave()
            save.version = 15
            persist()
        }
        if let data = d.data(forKey: Self.achKey),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            unlockedAchievements = Set(arr)
        }
        if let data = d.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(DDMSettings.self, from: data) {
            settings = decoded
        }
    }

    /// Spec §11: wipe gameplay state, keep lifetime stats, credit one-time gem gift.
    private func migrateV14ToV15(from old: DDMSave) {
        let lifetime = old.lifetimeGoldEarned
        save = DDMSave()           // fresh state
        save.version = 15
        // Keep lifetime stats.
        save.lifetimeGoldEarned = lifetime
        save.lifetimeOreSold = old.lifetimeOreSold
        save.oreMinedTotals = old.oreMinedTotals
        save.totalTaps = old.totalTaps
        save.totalCollapses = old.totalCollapses
        save.lifetimeBarsValue = old.lifetimeBarsValue
        save.lifetimeResearch = old.lifetimeResearch
        save.bossesDefeated = old.bossesDefeated
        save.treasuresFound = old.treasuresFound
        // Gift gems: min(50, floor(log10(max(1, lifetimeGoldEarned)) * 5))
        let giftRaw = Foundation.log10(Swift.max(1.0, lifetime)) * 5.0
        let gift = Int(Swift.min(50.0, Foundation.floor(giftRaw)))
        save.gems = gift
        save.migrationGiftApplied = true
        persist()
        // Achievements are stored under their own key (achKey) and survive unchanged.
    }

    private func applyMigrationGiftIfNeeded() {
        guard !save.migrationGiftApplied else { return }
        let lifetime = save.lifetimeGoldEarned
        let giftRaw = Foundation.log10(Swift.max(1.0, lifetime)) * 5.0
        let gift = Int(Swift.min(50.0, Foundation.floor(giftRaw)))
        save.gems += gift
        save.migrationGiftApplied = true
        persist()
    }

    func resetProgress() {
        save = DDMSave()
        unlockedAchievements = []
        lastUnlocked = []
        offlineSummary = nil
        save.lastActive = Date().timeIntervalSince1970
        rebuildCurrentBlock()
        persist()
        persistAchievements()
        objectWillChange.send()
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(self, selector: #selector(onBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func onBackground() {
        persist()
    }

    @objc private func onForeground() {
        // re-credit offline progress on resume
        lastTick = Date()
        creditOfflineEarnings()
        // Immediately persist the updated lastActive so a subsequent crash or kill
        // cannot re-grant the same offline window on the next launch.
        persist()
    }
}

// MARK: - Helpers

struct DDMFloatingHit: Identifiable {
    let id: UUID
    let text: String
    let crit: Bool
}

struct DDMOfflineSummary {
    let seconds: Double
    let gold: Double
    let ore: Double
    let depth: Int
    let capped: Bool
}

enum DDMHaptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
}
