import SwiftUI
import SpriteKit

/// The main game screen: live kiln scene with a coin HUD, boost timer,
/// and buttons for Inventory / Upgrades / rewarded boosts / Settings.
struct KilnView: View {
    @StateObject private var game = GameState.shared
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var ads = AdsManager.shared

    @State private var scene: KilnScene?
    @State private var showInventory = false
    @State private var showUpgrades = false
    @State private var showSettings = false
    @State private var coinPop = false
    @State private var toast: String?
    @State private var boostBusy = false
    @State private var finishBusy = false

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
            } else {
                Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding()

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 120)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if scene == nil {
                let s = KilnScene()
                s.game = game
                s.onTapSlot = handleTapSlot
                scene = s
            }
        }
        .onChange(of: game.equippedSkin) { _, new in
            scene?.setSkin(new)
        }
        .sheet(isPresented: $showInventory, onDismiss: interstitialOnTransition) {
            InventoryView()
        }
        .sheet(isPresented: $showUpgrades, onDismiss: interstitialOnTransition) {
            UpgradeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // Coins
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(Color(hex: 0xFFD60A))
                Text("\(game.coins)")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .scaleEffect(coinPop ? 1.25 : 1.0)
            .onChange(of: game.coins) { _, _ in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    coinPop = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { coinPop = false }
                }
            }

            // Boost timer
            if game.boostActive {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color(hex: 0xFF8A00))
                    Text(boostLabel)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: 0xFF8A00).opacity(0.25), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xFF8A00).opacity(0.6), lineWidth: 1))
            }

            Spacer()

            Button {
                SoundManager.shared.play(.click)
                Haptics.selection()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var boostLabel: String {
        let s = Int(game.boostRemaining)
        return "2x \(s / 60):\(String(format: "%02d", s % 60))"
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Rewarded boosts (hidden for Remove-Ads owners — no ads, no buttons).
            if !store.removeAds {
                HStack(spacing: 10) {
                    boostButton
                    finishButton
                }
            }
            HStack(spacing: 12) {
                Button {
                    SoundManager.shared.play(.click)
                    Haptics.selection()
                    showInventory = true
                } label: {
                    Label("Pieces", systemImage: "archivebox.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0x5B5FE9), in: Capsule())
                        .overlay(alignment: .topTrailing) {
                            if !game.inventory.isEmpty {
                                Text("\(game.inventory.count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color(hex: 0xFF3B5C), in: Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                }
                Button {
                    SoundManager.shared.play(.click)
                    Haptics.selection()
                    showUpgrades = true
                } label: {
                    Label("Upgrades", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xFF8A00), in: Capsule())
                }
            }
        }
    }

    private var boostButton: some View {
        Button {
            watchAdForBoost()
        } label: {
            HStack(spacing: 6) {
                if boostBusy {
                    ProgressView().scaleEffect(0.8).tint(.white)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(game.boostActive ? "Boosted!" : "2x Speed")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: 0x00C2A8).opacity(game.boostActive ? 0.45 : 0.85), in: Capsule())
        }
        .disabled(boostBusy || game.boostActive || !ads.rewardedReady)
        .opacity(!ads.rewardedReady && !game.boostActive ? 0.55 : 1.0)
    }

    private var finishButton: some View {
        Button {
            watchAdForFinish()
        } label: {
            HStack(spacing: 6) {
                if finishBusy {
                    ProgressView().scaleEffect(0.8).tint(.white)
                } else {
                    Image(systemName: "forward.end.fill")
                }
                Text("Finish Now")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: 0xA259FF).opacity(0.85), in: Capsule())
        }
        .disabled(finishBusy || !game.anyFiring || !ads.rewardedReady)
        .opacity(!ads.rewardedReady || !game.anyFiring ? 0.55 : 1.0)
    }

    // MARK: - Actions

    private func handleTapSlot(_ index: Int) {
        guard game.slots.indices.contains(index) else { return }
        let slot = game.slots[index]
        if slot.isReady {
            if let piece = game.collect(slot: index) {
                SoundManager.shared.play(.pop)
                Haptics.success()
                scene?.playCollect(at: index, piece: piece)
            }
        } else if slot.isFiring {
            SoundManager.shared.play(.click)
            Haptics.light()
            showToast("Still firing — come back soon!")
        } else {
            game.startFiring(slot: index)
            SoundManager.shared.play(.pour)
            Haptics.medium()
        }
    }

    private func watchAdForBoost() {
        guard !boostBusy else { return }
        boostBusy = true
        SoundManager.shared.play(.click)
        AdsManager.shared.showRewarded { earned in
            Task { @MainActor in
                boostBusy = false
                if earned {
                    game.activateSpeedBoost()
                    SoundManager.shared.play(.win)
                    Haptics.success()
                    showToast("2x firing speed for 10 minutes!")
                } else {
                    showToast("No ad available right now.")
                }
            }
        }
    }

    private func watchAdForFinish() {
        guard !finishBusy else { return }
        finishBusy = true
        SoundManager.shared.play(.click)
        AdsManager.shared.showRewarded { earned in
            Task { @MainActor in
                finishBusy = false
                if earned, let (idx, piece) = game.instantFinishOneShelf() {
                    SoundManager.shared.play(.complete)
                    Haptics.success()
                    // The finished piece was auto-collected into inventory;
                    // celebrate on its shelf, which is already firing again.
                    scene?.playCollect(at: idx, piece: piece)
                    showToast("Finished: \(piece.title)!")
                } else if earned {
                    showToast("Nothing was firing.")
                } else {
                    showToast("No ad available right now.")
                }
            }
        }
    }

    private func interstitialOnTransition() {
        // Sparse interstitials live here: only on sheet dismissals
        // (a natural transition), never mid-tap or mid-collect.
        AdsManager.shared.showInterstitialIfDue {}
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }
}
