import SwiftUI

// Smelter: raw ore -> bars (worth ~3.5x+). Gold-purchased upgrades. Sits as a section
// reachable from the Upgrades tab via NavigationLink.
struct SmelterView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    if store.hasSmelter {
                        barInventory
                        sellBarsButton
                    }
                    Text("FORGE UPGRADES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(DDMPalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    ForEach(DDMSmelterDef.all) { def in
                        SmelterRow(def: def)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Smelter", displayMode: .inline)
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            DDMBarShape()
                .fill(LinearGradient(colors: [DDMPalette.amberGlow, DDMPalette.amberDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 60, height: 40)
            Text("Smelt ore into bars")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Text("The furnace converts raw ore into refined bars worth far more than the ore. Buy Furnace Intake to switch it on; the cart auto-sells finished bars.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 0) {
                infoCol("Smelt /s", store.hasSmelter ? DDMFormat.number(store.smeltRate) : "Off")
                divider
                infoCol("Bar Yield", String(format: "x%.2f", store.barYieldPerOre))
                divider
                infoCol("Held Bars", DDMFormat.number(store.totalHeldBars))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }

    private var barInventory: some View {
        let held = DDMOre.allCases.filter { (store.save.bars[$0.rawValue] ?? 0) > 0 }
        return Group {
            if !held.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(held, id: \.rawValue) { ore in
                            VStack(spacing: 3) {
                                DDMBarShape()
                                    .fill(ore.color)
                                    .frame(width: 36, height: 22)
                                Text(DDMFormat.number(store.save.bars[ore.rawValue] ?? 0))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(DDMPalette.textPrimary)
                                Text(ore.name)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(DDMPalette.textMuted)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DDMPalette.panelRaised))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var sellBarsButton: some View {
        Button {
            store.sellAllBars()
        } label: {
            HStack {
                DDMCoinShape(size: 20)
                Text("Sell All Bars")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text(store.totalHeldBars > 0 ? "+\(DDMFormat.number(store.heldBarsValue))" : "—")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(store.totalHeldBars > 0 ? DDMPalette.accent : DDMPalette.locked))
        }
        .buttonStyle(.plain)
        .disabled(store.totalHeldBars <= 0)
    }

    private func infoCol(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(DDMPalette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(DDMPalette.panelDeep).frame(width: 1, height: 28)
    }
}

struct SmelterRow: View {
    @EnvironmentObject var store: DDMStore
    let def: DDMSmelterDef

    var body: some View {
        let level = store.smelterLevel(def.kind)
        let cost = store.smelterCost(def.kind)
        let affordable = store.canBuySmelter(def.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 46, height: 46)
                DDMBarShape()
                    .fill(DDMPalette.amberDeep)
                    .frame(width: 28, height: 18)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                    Text("Lv \(level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DDMPalette.accentDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(DDMPalette.amber.opacity(0.18)))
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                store.buySmelter(def.kind)
            } label: {
                VStack(spacing: 1) {
                    Text(DDMFormat.number(cost))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("BUY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(width: 78)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(affordable ? DDMPalette.accent : DDMPalette.locked))
            }
            .buttonStyle(.plain)
            .disabled(!affordable)
        }
        .padding(14)
        .ddmPanel()
    }
}

// Simple ingot/bar shape (trapezoid).
struct DDMBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.14, y: 0))
        p.addLine(to: CGPoint(x: w * 0.86, y: 0))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}
