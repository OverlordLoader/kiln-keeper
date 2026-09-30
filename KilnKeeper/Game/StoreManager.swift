import Foundation
import Combine
import StoreKit

/// StoreKit 2 purchases. Everything goes through Apple — no external
/// billing, no web links. Owned entitlements are persisted locally so the
/// game works offline; purchases themselves need a network connection
/// to Apple.
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // Product IDs — these MUST match the products created in App Store Connect.
    static let removeAdsID = "app.kilnkeeper.game.removeads"            // non-consumable, $4.99
    static let emberforgeSkinID = "app.kilnkeeper.game.skin.emberforge" // non-consumable, $1.99
    static let tideglassSkinID = "app.kilnkeeper.game.skin.tideglass"   // non-consumable, $1.99

    static let skinIDs = [emberforgeSkinID, tideglassSkinID]
    static let allProductIDs = [removeAdsID] + skinIDs

    @Published private(set) var removeAds = false
    @Published private(set) var ownedSkins: Set<String> = []
    @Published private(set) var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var lastError: String?

    private var updateListener: Task<Void, Error>?

    private enum Keys {
        static let removeAds = "kilnkeeper.store.removeAds"
        static let ownedSkins = "kilnkeeper.store.ownedSkins"
    }

    private init() {
        let d = UserDefaults.standard
        removeAds = d.bool(forKey: Keys.removeAds)
        ownedSkins = Set(d.stringArray(forKey: Keys.ownedSkins) ?? [])
        // Listen for transactions that complete outside the app
        // (e.g. approved on another device, Ask to Buy, refunds).
        updateListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdate(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: - Products

    @MainActor
    func requestProducts() async {
        do {
            products = try await Product.products(for: Self.allProductIDs)
        } catch {
            lastError = "Couldn't load store products. Check your connection and try again."
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    var removeAdsProduct: Product? { product(for: Self.removeAdsID) }

    func skinProduct(for skin: KilnSkin) -> Product? {
        guard let id = skin.productID else { return nil }
        return product(for: id)
    }

    func ownsSkin(_ skin: KilnSkin) -> Bool {
        skin == .classic || ownedSkins.contains(skin.productID ?? "")
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                try await handleVerified(verification)
                lastError = nil
            case .userCancelled, .pending:
                break // no error to show; pending resolves via Transaction.updates
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. Please try again."
        }
    }

    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    // MARK: - Verification & entitlements

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            try await handleVerified(result)
        } catch {
            // Unverified transactions are ignored — never grant on them.
        }
    }

    private func handleVerified(_ verification: VerificationResult<Transaction>) async throws {
        switch verification {
        case .verified(let transaction):
            await MainActor.run { self.apply(transaction) }
            await transaction.finish()
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    @MainActor
    private func apply(_ transaction: Transaction) {
        let d = UserDefaults.standard
        switch transaction.productID {
        case Self.removeAdsID:
            removeAds = true
            d.set(true, forKey: Keys.removeAds)
        case Self.emberforgeSkinID, Self.tideglassSkinID:
            ownedSkins.insert(transaction.productID)
            d.set(Array(ownedSkins), forKey: Keys.ownedSkins)
        default:
            break
        }
    }

    /// Re-reads current entitlements (covers restores and refunds).
    /// A revoked Remove Ads (refund) clears the flag so ads return;
    /// a revoked skin is un-owned (and unequipped if it was equipped).
    func refreshEntitlements() async {
        var entitledRemoveAds = false
        var entitledSkins = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                switch transaction.productID {
                case Self.removeAdsID:
                    entitledRemoveAds = true
                case Self.emberforgeSkinID, Self.tideglassSkinID:
                    entitledSkins.insert(transaction.productID)
                default:
                    break
                }
            }
        }
        await MainActor.run {
            let d = UserDefaults.standard
            self.removeAds = entitledRemoveAds
            d.set(entitledRemoveAds, forKey: Keys.removeAds)
            self.ownedSkins = entitledSkins
            d.set(Array(entitledSkins), forKey: Keys.ownedSkins)
            // Unequip a skin that is no longer owned.
            let game = GameState.shared
            if let equipped = game.equippedSkin.productID,
               !entitledSkins.contains(equipped) {
                game.equippedSkin = .classic
                game.save()
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
