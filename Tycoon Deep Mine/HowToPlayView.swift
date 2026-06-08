import SwiftUI

struct HowToPlayView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            DDMBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        step(icon: AnyView(DDMPickaxeShape(color: DDMPalette.accentDeep, handle: DDMPalette.dirt, size: 30)),
                             title: "Mining",
                             body: "Tap or let drills mine blocks. HP grows linearly with depth — 60 + 6 × depth. Bosses (last block of each zone) have ×8 HP and ×3 gold. 10 zones, each unlocking a new ore tier (Coal → Diamond, value 1.0 → 2.0).")
                        step(icon: AnyView(DDMTabUpgradeIcon(color: DDMPalette.gemDeep, size: 28)),
                             title: "Upgrades",
                             body: "Every upgrade costs ×1.25 more per level. Ore Grader (+0.5%/level) and Refiner (+0.25%/level) add to a shared bonus, capped at +100 %. Gold and damage share the same multiplier. Max 2 strikes with Multi-Strike.")
                        step(icon: AnyView(DDMGemBadge(size: 28)),
                             title: "Prestige",
                             body: "Reach deeper to collapse. Gems = floor((max depth / 100)^0.40). Each gem permanently gives +0.05 % bonus (shared cap). Spend gems on Shaft Head Start, Standing Drill, Wide Pan, Night Shift, and Seed Vault.")
                        Color.clear.frame(height: 20)
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("How to Play")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textOnDark)
            Spacer()
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DDMPalette.amber)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func step(icon: AnyView, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 50, height: 50)
                icon
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }
}
