import SwiftUI

/// The three upgrade tracks: more shelf slots, faster firing, rarer glass.
/// Buying triggers a confetti-lite burst + success haptic.
struct UpgradeView: View {
    @StateObject private var game = GameState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confettiID = UUID()
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.05, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        slotCard
                        speedCard
                        colorCard
                    }
                    .padding()
                }
                if showConfetti {
                    ConfettiBurst(id: confettiID)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Upgrades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        SoundManager.shared.play(.click)
                        dismiss()
                    }
                    .foregroundColor(Color(hex: 0xFFD60A))
                }
            }
        }
        .tint(Color(hex: 0xFFD60A))
    }

    // MARK: - Cards

    private var slotCard: some View {
        upgradeCard(
            icon: "square.stack.3d.up.fill",
            accent: Color(hex: 0x3AB6FF),
            title: "Shelf Slots",
            subtitle: "\(game.slotCount) of \(Balance.maxSlots) shelves",
            detail: nextSlotDetail,
            cost: game.slotCount < Balance.maxSlots ? game.nextSlotCost : nil,
            canBuy: game.canBuySlot,
            action: { _ = game.buySlot() }
        )
    }

    private var nextSlotDetail: String {
        game.slotCount < Balance.maxSlots
            ? "Add one more shelf — it starts firing immediately."
            : "Every shelf is yours. The kiln is at full capacity!"
    }

    private var speedCard: some View {
        let secs = Int(game.fireDuration.rounded())
        return upgradeCard(
            icon: "flame.fill",
            accent: Color(hex: 0xFF8A00),
            title: "Faster Firing",
            subtitle: "Level \(game.speedLevel) of \(Balance.maxSpeedLevel) — \(secs)s per piece",
            detail: game.speedLevel < Balance.maxSpeedLevel
                ? "Each level fires pieces 12% faster, even ones already in the kiln."
                : "The kiln burns at maximum speed!",
            cost: game.speedLevel < Balance.maxSpeedLevel ? game.nextSpeedCost : nil,
            canBuy: game.canBuySpeed,
            action: { _ = game.buySpeed() }
        )
    }

    private var colorCard: some View {
        let tierName = game.colorTier < Balance.maxColorTier
            ? PieceColor.allCases.first(where: { $0.rarityTier == game.colorTier + 1 })?.rarityName ?? ""
            : ""
        return upgradeCard(
            icon: "sparkles",
            accent: Color(hex: 0xA259FF),
            title: "Rarer Glass",
            subtitle: game.colorTier < Balance.maxColorTier
                ? "Unlocks \(tierName) glass"
                : "All rarities unlocked — legendary glass awaits",
            detail: game.colorTier < Balance.maxColorTier
                ? "Rarer colors sell for much more."
                : "Your kiln fires every color in existence.",
            cost: game.colorTier < Balance.maxColorTier ? game.nextColorTierCost : nil,
            canBuy: game.canBuyColorTier,
            extra: game.colorTier < Balance.maxColorTier ? AnyView(unlockPreview) : nil,
            action: { _ = game.buyColorTier() }
        )
    }

    private var unlockPreview: some View {
        HStack(spacing: 8) {
            ForEach(game.nextColorTierColors) { color in
                VStack(spacing: 4) {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    Text("\(color.displayName)\n\(color.sellValue)¢")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Card builder

    private func upgradeCard(icon: String, accent: Color, title: String,
                             subtitle: String, detail: String,
                             cost: Int?, canBuy: Bool,
                             extra: AnyView? = nil,
                             action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accent)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
            if let extra { extra }
            Button {
                action()
                SoundManager.shared.play(.win)
                Haptics.success()
                confettiID = UUID()
                withAnimation { showConfetti = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showConfetti = false }
                }
            } label: {
                HStack {
                    Spacer()
                    if let cost {
                        Text(canBuy ? "Upgrade — \(cost)¢" : "Need \(cost)¢")
                            .font(.headline)
                    } else {
                        Text("Maxed out")
                            .font(.headline)
                    }
                    Spacer()
                }
                .foregroundColor(.black)
                .padding(.vertical, 12)
                .background(canBuy && cost != nil ? Color(hex: 0xFFD60A) : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!(canBuy && cost != nil))
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Confetti-lite

/// A one-shot burst of candy-colored dots that float up and fade.
/// Shown after an upgrade purchase; removes itself from the layout.
struct ConfettiBurst: View {
    let id: UUID
    private let dots: [(x: CGFloat, y: CGFloat, color: Color, delay: Double)] = {
        let palette: [UInt32] = [0xFF3B5C, 0xFF8A00, 0xFFD60A, 0x7ED957, 0x00C2A8,
                                 0x3AB6FF, 0x5B5FE9, 0xA259FF, 0xFF5FD2]
        return (0..<28).map { _ in
            (x: CGFloat.random(in: -90...90),
             y: CGFloat.random(in: -40...40),
             color: Color(hex: palette.randomElement()!),
             delay: Double.random(in: 0...0.25))
        }
    }()

    var body: some View {
        ZStack {
            ForEach(0..<dots.count, id: \.self) { i in
                let d = dots[i]
                Circle()
                    .fill(d.color)
                    .frame(width: 9, height: 9)
                    .offset(x: d.x, y: d.y)
                    .modifier(ConfettiFloat(delay: d.delay))
            }
        }
        .id(id)
    }
}

private struct ConfettiFloat: ViewModifier {
    let delay: Double
    @State private var go = false

    func body(content: Content) -> some View {
        content
            .offset(y: go ? -160 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(delay)) { go = true }
            }
    }
}
