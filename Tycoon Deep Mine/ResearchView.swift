import SwiftUI

// Research tech tree. Research Points accrue passively from the deepest depth reached
// (banked basis, no re-earning). Techs persist through Collapse. Reached from Upgrades.
struct ResearchView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    Text("TECH TREE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(DDMPalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    ForEach(DDMTechDef.all) { def in
                        TechRow(def: def)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Research", displayMode: .inline)
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            DDMFlaskShape()
                .fill(LinearGradient(colors: [DDMPalette.gemLight, DDMPalette.gemDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 40, height: 48)
            Text("\(DDMFormat.number(store.save.research)) RP")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Text("Research Points are earned as you reach new depths. Techs are permanent and survive Collapse. Reach deeper to fund the tree.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 0) {
                infoCol("RP / depth", "depth^1.25")
                divider
                infoCol("Lifetime RP", DDMFormat.number(store.save.lifetimeResearch))
                divider
                infoCol("RP Rate", String(format: "x%.2f", store.researchRateMultiplier))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }

    private func infoCol(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.55)
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

struct TechRow: View {
    @EnvironmentObject var store: DDMStore
    let def: DDMTechDef

    var body: some View {
        let level = store.techLevel(def.kind)
        let maxed = level >= def.maxLevel
        let cost = store.techCost(def.kind)
        let affordable = store.canBuyTech(def.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 46, height: 46)
                DDMFlaskShape()
                    .fill(DDMPalette.gemDeep)
                    .frame(width: 22, height: 28)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                    Text("Lv \(level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DDMPalette.gemDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(DDMPalette.gem.opacity(0.2)))
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                store.buyTech(def.kind)
            } label: {
                VStack(spacing: 1) {
                    if maxed {
                        Text("MAX")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    } else {
                        Text(DDMFormat.number(cost))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                        Text("RP")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 76)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(maxed ? DDMPalette.success : (affordable ? DDMPalette.gemDeep : DDMPalette.locked)))
            }
            .buttonStyle(.plain)
            .disabled(maxed || !affordable)
        }
        .padding(14)
        .ddmPanel()
    }
}

// Erlenmeyer-flask shape for research iconography.
struct DDMFlaskShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.38, y: h * 0.06))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.06))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.94))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.94))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.40))
        p.closeSubpath()
        return p
    }
}
