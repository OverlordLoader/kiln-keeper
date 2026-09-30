import SwiftUI

@main
struct KilnKeeperApp: App {
    init() {
        // Warms the StoreKit product cache and current entitlements first,
        // so the ads manager starts in the correct state (Remove Ads
        // owners never load ads).
        _ = StoreManager.shared
        AdsManager.bumpSessionCount()
        // Google Mobile Ads (test IDs in DEBUG; real IDs are TODOs for release).
        // Safe to call before the UI appears; no-ops gracefully offline.
        AdsManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
