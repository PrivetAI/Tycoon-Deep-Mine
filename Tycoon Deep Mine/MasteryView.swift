import SwiftUI

// Per-ore mastery: each ore has its own gold-bought value upgrade (+15% sell value/level).
// Costs scale with the ore's own tier so deep ores cost vastly more. Run-scoped (reset by
// Collapse, like the rest of the gold economy). Reached from Upgrades.
struct MasteryView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    ForEach(unlockedOres, id: \.rawValue) { ore in
                        MasteryRow(ore: ore)
                    }
                    if unlockedOres.isEmpty {
                        Text("Dig deeper to discover ore worth mastering.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(DDMPalette.textMuted)
                            .padding(.top, 20)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Ore Mastery", displayMode: .inline)
    }

    // Ores the player has actually mined this run-history (any lifetime amount).
    private var unlockedOres: [DDMOre] {
        DDMOre.allCases.filter { (store.save.oreMinedTotals[$0.rawValue] ?? 0) > 0 }
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text("Master each ore")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Text("Specialise in an ore type to raise its sell value by +15% per level. Deeper ores cost far more to master. Mastery resets on Collapse.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }
}

struct MasteryRow: View {
    @EnvironmentObject var store: DDMStore
    let ore: DDMOre

    var body: some View {
        let level = store.save.oreMastery[ore.rawValue] ?? 0
        let maxed = level >= DDMOreMastery.maxLevel
        let cost = store.oreMasteryCost(ore)
        let affordable = store.canBuyMastery(ore)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 46, height: 46)
                DDMOreChunk(color: ore.color, size: 30)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ore.name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                    Text("Lv \(level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DDMPalette.accentDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(DDMPalette.amber.opacity(0.18)))
                }
                Text("Sell value x\(String(format: "%.2f", store.oreMasteryMultiplier(ore))) · now \(DDMFormat.number(store.oreUnitValue(ore)))/unit")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
            }
            Spacer(minLength: 4)
            Button {
                store.buyMastery(ore)
            } label: {
                VStack(spacing: 1) {
                    if maxed {
                        Text("MAX")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    } else {
                        Text(DDMFormat.number(cost))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text("BUY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 78)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(maxed ? DDMPalette.success : (affordable ? DDMPalette.accent : DDMPalette.locked)))
            }
            .buttonStyle(.plain)
            .disabled(maxed || !affordable)
        }
        .padding(14)
        .ddmPanel()
    }
}
