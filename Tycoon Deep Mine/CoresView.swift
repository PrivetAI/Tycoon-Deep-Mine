import SwiftUI

// Second prestige layer: Tectonic Shift -> Cores -> meta-tree of permanent perks that
// persist through Collapse. Hosted as its own tab.
struct CoresView: View {
    @EnvironmentObject var store: DDMStore
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    shiftCard
                    Text("META PERKS  ·  PERMANENT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(DDMPalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    ForEach(DDMMetaDef.all) { def in
                        MetaRow(def: def)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Tectonic", displayMode: .inline)
        .alert(isPresented: $showConfirm) {
            Alert(
                title: Text("Trigger a Tectonic Shift?"),
                message: Text("Convert your prestige progress into \(store.pendingCores) Core\(store.pendingCores == 1 ? "" : "s"). This RESETS gems, permanent (gem) upgrades and the current run — but keeps Cores, meta perks, research and achievements."),
                primaryButton: .destructive(Text("Shift")) {
                    store.tectonicShift()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var shiftCard: some View {
        VStack(spacing: 14) {
            DDMCoreShape()
                .fill(LinearGradient(colors: [DDMPalette.amberGlow, DDMPalette.accent, DDMPalette.accentDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 58, height: 58)
            Text("\(store.save.cores) Cores")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Text("A Tectonic Shift collapses everything into Cores. Spend them on meta perks that survive every Collapse — permanently accelerating the whole loop.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 0) {
                infoCol("Gold Mult", String(format: "x%.2f", store.metaGoldMultiplier))
                divider
                infoCol("Dmg Mult", String(format: "x%.2f", store.metaDamageMultiplier))
                divider
                infoCol("Shifts", "\(store.save.totalShifts)")
                divider
                infoCol("New Gems", "\(max(0, store.save.gems - store.save.gemsClaimedForCores))")
            }
            .padding(.vertical, 4)

            VStack(spacing: 4) {
                Text("Shift now to gain")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(DDMPalette.textMuted)
                HStack(spacing: 6) {
                    DDMCoreShape()
                        .fill(DDMPalette.accent)
                        .frame(width: 22, height: 22)
                    Text("\(store.pendingCores)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.accentDeep)
                }
            }

            Button {
                showConfirm = true
            } label: {
                Text(store.canShift ? "Tectonic Shift" : "Earn 60+ gems to Shift")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(store.canShift ? DDMPalette.accent : DDMPalette.locked))
            }
            .buttonStyle(.plain)
            .disabled(!store.canShift)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ddmPanel()
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

struct MetaRow: View {
    @EnvironmentObject var store: DDMStore
    let def: DDMMetaDef

    var body: some View {
        let level = store.metaLevel(def.kind)
        let maxed = level >= def.maxLevel
        let cost = store.metaCost(def.kind)
        let affordable = store.canBuyMeta(def.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 46, height: 46)
                DDMCoreShape()
                    .fill(DDMPalette.accent)
                    .frame(width: 28, height: 28)
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
                        .background(Capsule().fill(DDMPalette.accent.opacity(0.2)))
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                store.buyMeta(def.kind)
            } label: {
                VStack(spacing: 1) {
                    if maxed {
                        Text("MAX")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    } else {
                        HStack(spacing: 3) {
                            DDMCoreShape()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                            Text("\(cost)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        Text("CORES")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 76)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(maxed ? DDMPalette.success : (affordable ? DDMPalette.accentDeep : DDMPalette.locked)))
            }
            .buttonStyle(.plain)
            .disabled(maxed || !affordable)
        }
        .padding(14)
        .ddmPanel()
    }
}

// Faceted hexagonal "core" gem shape for the Cores currency.
struct DDMCoreShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = (Double(i) * 60.0 - 90.0) * .pi / 180.0
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r,
                             y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
