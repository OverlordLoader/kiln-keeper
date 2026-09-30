import SwiftUI

/// Store screen: Remove Ads, kiln skins (previews + equip), Restore
/// Purchases, and sound/haptics toggles. Every row does something real —
/// no dead UI (Apple review rule).
struct SettingsView: View {
    @StateObject private var game = GameState.shared
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var soundOn = SoundManager.shared.enabled
    @State private var hapticsOn = Haptics.enabled

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.05, blue: 0.10).ignoresSafeArea()
                List {
                    Section {
                        removeAdsRow
                    } header: {
                        Text("Kiln Keeper Plus").foregroundColor(.white.opacity(0.6))
                    }
                    Section {
                        ForEach(KilnSkin.allCases) { skin in
                            skinRow(skin)
                        }
                    } header: {
                        Text("Kiln Skins").foregroundColor(.white.opacity(0.6))
                    } footer: {
                        Text("Skins re-theme your kiln's bricks and fire. Yours forever.")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Section {
                        restoreRow
                    }
                    Section {
                        Toggle("Sound effects", isOn: $soundOn)
                        Toggle("Haptics", isOn: $hapticsOn)
                    } header: {
                        Text("Feedback").foregroundColor(.white.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
                if store.purchaseInProgress {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Settings")
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
            .task { await store.requestProducts() }
            .onChange(of: soundOn) { _, v in SoundManager.shared.enabled = v }
            .onChange(of: hapticsOn) { _, v in Haptics.enabled = v }
            .alert("Store", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.lastError ?? "")
            }
        }
        .tint(Color(hex: 0xFFD60A))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )
    }

    // MARK: - Remove Ads

    private var removeAdsRow: some View {
        Button {
            guard !store.removeAds,
                  let product = store.removeAdsProduct else { return }
            SoundManager.shared.play(.click)
            Haptics.selection()
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Image(systemName: "nosign")
                    .font(.title2)
                    .foregroundColor(Color(hex: 0xFFD60A))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Ads").font(.headline)
                    Text("No more ads, ever. One-time purchase.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if store.removeAds {
                    Text("Owned")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                } else if let product = store.removeAdsProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0xFF8A00))
                } else {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(store.removeAds)
    }

    // MARK: - Skins

    private func skinRow(_ skin: KilnSkin) -> some View {
        let owned = store.ownsSkin(skin)
        let equipped = game.equippedSkin == skin
        return Button {
            skinTapped(skin)
        } label: {
            HStack(spacing: 12) {
                KilnSwatch(skin: skin)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.displayName).font(.headline)
                    Text(skin.tagline)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if equipped {
                    Text("Equipped")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                } else if owned {
                    Text("Equip")
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0x3AB6FF))
                } else if let product = store.skinProduct(for: skin) {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0xFF8A00))
                } else {
                    Text(skin.fallbackPrice)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: 0xFF8A00))
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(equipped)
    }

    private func skinTapped(_ skin: KilnSkin) {
        SoundManager.shared.play(.click)
        Haptics.selection()
        if store.ownsSkin(skin) {
            game.equippedSkin = skin
            game.save()
            Haptics.success()
        } else if let product = store.skinProduct(for: skin) {
            Task {
                await store.purchase(product)
                // Auto-equip on successful purchase.
                await MainActor.run {
                    if store.ownsSkin(skin) {
                        game.equippedSkin = skin
                        game.save()
                    }
                }
            }
        } else {
            // Products haven't loaded (offline): refresh so the row
            // shows a live price instead of doing nothing.
            Task { await store.requestProducts() }
        }
    }

    // MARK: - Restore

    private var restoreRow: some View {
        Button {
            SoundManager.shared.play(.click)
            Haptics.selection()
            Task { await store.restorePurchases() }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Purchases").font(.headline)
                    Text("Bought Remove Ads or a skin on another device? Tap to restore.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Kiln preview swatch

/// A tiny SwiftUI kiln glyph tinted by the skin's brick + fire colors,
/// so players can see the theme before buying.
struct KilnSwatch: View {
    let skin: KilnSkin

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(skin.brickColor))
            // Arch highlight.
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(colors: [.white.opacity(0.14), .clear],
                                   startPoint: .top, endPoint: .center)
                )
            // Fire mouth.
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(colors: [.white, Color(skin.fireColor), Color(skin.fireColor).opacity(0.1)],
                                   center: .center, startRadius: 1, endRadius: 20)
                )
                .frame(width: 30, height: 20)
                .offset(y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}
