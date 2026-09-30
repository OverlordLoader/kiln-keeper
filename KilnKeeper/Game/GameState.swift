import Foundation
import Combine

/// Summary of what finished while the app was closed, shown in the
/// "While you were away..." sheet on launch.
struct AwaySummary {
    var pieces: [KilnPiece] = []
    var capped: Bool = false

    var totalValue: Int { pieces.reduce(0) { $0 + $1.sellValue } }
    var isEmpty: Bool { pieces.isEmpty }
}

/// Owns the whole idle-game economy: coins, shelf slots, inventory,
/// upgrade tracks, the 2x-speed boost, and offline progress.
/// Persists to UserDefaults as JSON on every meaningful change and on
/// app backgrounding; on launch it simulates the kiln while away
/// (capped at `Balance.offlineCapHours`).
@MainActor
final class GameState: ObservableObject {
    static let shared = GameState()

    @Published private(set) var coins: Int = Balance.startingCoins
    @Published private(set) var slots: [ShelfSlot] = []
    @Published private(set) var inventory: [KilnPiece] = []
    @Published private(set) var speedLevel: Int = 0
    @Published private(set) var colorTier: Int = 0
    @Published private(set) var boostUntil: Date?
    @Published var equippedSkin: KilnSkin = .classic
    @Published private(set) var totalFired: Int = 0
    @Published private(set) var totalEarned: Int = 0
    /// Ticks once per second so progress bars and timers stay live.
    @Published private(set) var now: Date = Date()

    @Published var awaySummary: AwaySummary?

    var boostActive: Bool { (boostUntil ?? .distantPast) > Date() }
    var boostRemaining: TimeInterval { max(0, (boostUntil ?? .distantPast).timeIntervalSince(Date())) }
    var fireDuration: TimeInterval {
        Balance.fireDuration(speedLevel: speedLevel, boosted: boostActive)
    }

    private enum Keys {
        static let save = "kilnkeeper.save.v1"
        static let lastSeen = "kilnkeeper.lastSeen.v1"
    }

    private struct SaveData: Codable {
        var coins: Int
        var slots: [ShelfSlot]
        var inventory: [KilnPiece]
        var speedLevel: Int
        var colorTier: Int
        var boostUntil: Date?
        var equippedSkin: KilnSkin
        var totalFired: Int
        var totalEarned: Int
    }

    private var tickTimer: Timer?

    private init() {
        load()
        startTicking()
    }

    // MARK: - Tick

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = Date() }
        }
    }

    // MARK: - Persistence

    private func snapshot() -> SaveData {
        SaveData(coins: coins, slots: slots, inventory: inventory,
                 speedLevel: speedLevel, colorTier: colorTier,
                 boostUntil: boostUntil, equippedSkin: equippedSkin,
                 totalFired: totalFired, totalEarned: totalEarned)
    }

    func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(snapshot()) {
            d.set(data, forKey: Keys.save)
        }
        d.set(Date(), forKey: Keys.lastSeen)
    }

    private func load() {
        let d = UserDefaults.standard
        let lastSeen = d.object(forKey: Keys.lastSeen) as? Date
        if let data = d.data(forKey: Keys.save),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            coins = saved.coins
            slots = saved.slots
            inventory = saved.inventory
            speedLevel = saved.speedLevel
            colorTier = saved.colorTier
            boostUntil = saved.boostUntil
            equippedSkin = saved.equippedSkin
            totalFired = saved.totalFired
            totalEarned = saved.totalEarned
        } else {
            // Fresh install: 3 empty shelves.
            slots = (0..<Balance.startingSlots).map { _ in ShelfSlot() }
        }
        if let lastSeen {
            applyOfflineProgress(since: lastSeen)
        } else {
            // Brand-new player: start every shelf firing so the kiln
            // is alive on first sight.
            for i in slots.indices where slots[i].isEmpty {
                startFiring(slot: i)
            }
        }
        save()
    }

    // MARK: - Offline progress

    /// Simulates the kiln between `lastSeen` and now, capped at
    /// `Balance.offlineCapHours`. Each firing slot completes its piece and
    /// immediately starts another, until the cap is consumed. Completed
    /// pieces land in `awaySummary` for the welcome-back sheet.
    private func applyOfflineProgress(since lastSeen: Date) {
        let now = Date()
        let capEnd = lastSeen.addingTimeInterval(Balance.offlineCapHours * 3600)
        let simEnd = min(now, capEnd)
        guard simEnd > lastSeen else { return }

        var summary = AwaySummary()
        summary.capped = now > capEnd
        // Approximate with the fire duration as it was when the player left.
        let duration = fireDuration

        for i in slots.indices {
            guard var piece = slots[i].piece, var readyAt = slots[i].readyAt else { continue }
            if readyAt <= lastSeen {
                // Already ready when the player left — it simply stays
                // ready. No phantom cycles are credited for it.
                continue
            }
            // Catch up: every cycle that finished inside the capped window
            // counts, and the shelf immediately starts the next piece
            // (the kiln never idles, even while the app is closed).
            while readyAt <= simEnd {
                summary.pieces.append(piece)
                totalFired += 1
                piece = KilnPiece(color: PieceColor.random(upto: colorTier), firedAt: readyAt)
                readyAt = readyAt.addingTimeInterval(duration)
            }
            slots[i].piece = piece
            slots[i].readyAt = readyAt
        }

        if !summary.isEmpty {
            awaySummary = summary
        }
    }

    // MARK: - Shelves

    var slotCount: Int { slots.count }

    /// Starts firing a new random piece in an empty slot.
    func startFiring(slot index: Int) {
        guard slots.indices.contains(index), slots[index].isEmpty else { return }
        let piece = KilnPiece(color: PieceColor.random(upto: colorTier))
        slots[index].piece = piece
        slots[index].readyAt = Date().addingTimeInterval(fireDuration)
        totalFired += 1
        save()
    }

    /// Collects a ready piece into the inventory. Returns it for the
    /// collect animation, then the slot immediately starts a new firing
    /// so the kiln never sits idle.
    @discardableResult
    func collect(slot index: Int) -> KilnPiece? {
        guard slots.indices.contains(index), slots[index].isReady,
              let piece = slots[index].piece else { return nil }
        inventory.append(piece)
        // Auto-refire: the shelf goes straight back to work.
        let next = KilnPiece(color: PieceColor.random(upto: colorTier))
        slots[index].piece = next
        slots[index].readyAt = Date().addingTimeInterval(fireDuration)
        totalFired += 1
        save()
        return piece
    }

    /// Instantly finishes one firing shelf (rewarded-ad reward).
    /// Picks the shelf with the most time remaining. Returns the slot
    /// index and the piece it completed, or nil when nothing is firing.
    @discardableResult
    func instantFinishOneShelf() -> (Int, KilnPiece)? {
        let now = Date()
        let firing = slots.indices.filter { slots[$0].isFiring }
        guard let best = firing.max(by: {
            (slots[$0].readyAt ?? now) < (slots[$1].readyAt ?? now)
        }) else { return nil }
        slots[best].readyAt = now
        guard let piece = collect(slot: best) else { return nil }
        return (best, piece)
    }

    var anyFiring: Bool { slots.contains { $0.isFiring } }

    // MARK: - Coins & inventory

    func addCoins(_ amount: Int) {
        coins += amount
        totalEarned += amount
        save()
    }

    @discardableResult
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        save()
        return true
    }

    /// Sells one inventory piece. Returns the coins earned.
    @discardableResult
    func sell(pieceID: UUID) -> Int {
        guard let i = inventory.firstIndex(where: { $0.id == pieceID }) else { return 0 }
        let value = inventory[i].sellValue
        inventory.remove(at: i)
        addCoins(value)
        return value
    }

    /// Sells the whole inventory. Returns (count, coins earned).
    @discardableResult
    func sellAll() -> (Int, Int) {
        let value = inventory.reduce(0) { $0 + $1.sellValue }
        let count = inventory.count
        inventory.removeAll()
        addCoins(value)
        return (count, value)
    }

    var inventoryValue: Int { inventory.reduce(0) { $0 + $1.sellValue } }

    // MARK: - Upgrades

    var nextSlotCost: Int { Balance.slotCost(forSlotCount: slotCount) }
    var canBuySlot: Bool { slotCount < Balance.maxSlots && coins >= nextSlotCost }

    @discardableResult
    func buySlot() -> Bool {
        guard canBuySlot, spendCoins(nextSlotCost) else { return false }
        slots.append(ShelfSlot())
        startFiring(slot: slots.count - 1)
        return true
    }

    var nextSpeedCost: Int { Balance.speedCost(forLevel: speedLevel) }
    var canBuySpeed: Bool { speedLevel < Balance.maxSpeedLevel && coins >= nextSpeedCost }

    /// Faster firing applies to shelves already in progress too:
    /// remaining time is rescaled to the new duration.
    @discardableResult
    func buySpeed() -> Bool {
        guard canBuySpeed, spendCoins(nextSpeedCost) else { return false }
        let old = fireDuration
        speedLevel += 1
        let new = fireDuration
        let now = Date()
        for i in slots.indices where slots[i].isFiring {
            if let readyAt = slots[i].readyAt {
                let remaining = max(0, readyAt.timeIntervalSince(now))
                let scaled = remaining * (new / max(old, 0.001))
                slots[i].readyAt = now.addingTimeInterval(scaled)
            }
        }
        save()
        return true
    }

    var nextColorTierCost: Int { Balance.colorTierCost(forTier: colorTier + 1) }
    var canBuyColorTier: Bool { colorTier < Balance.maxColorTier && coins >= nextColorTierCost }
    var nextColorTierColors: [PieceColor] {
        PieceColor.allCases.filter { $0.rarityTier == colorTier + 1 }
    }

    @discardableResult
    func buyColorTier() -> Bool {
        guard canBuyColorTier, spendCoins(nextColorTierCost) else { return false }
        colorTier += 1
        save()
        return true
    }

    // MARK: - Boost (rewarded ad)

    /// Starts the 2x firing-speed boost for `Balance.boostDuration`.
    func activateSpeedBoost() {
        let wasActive = boostActive
        let from = max(Date(), boostUntil ?? .distantPast)
        boostUntil = from.addingTimeInterval(Balance.boostDuration)
        guard !wasActive else { return } // already halved; just extended
        // Rescale in-progress shelves to the boosted duration.
        let now = Date()
        for i in slots.indices where slots[i].isFiring {
            if let readyAt = slots[i].readyAt {
                let remaining = max(0, readyAt.timeIntervalSince(now))
                slots[i].readyAt = now.addingTimeInterval(remaining / 2)
            }
        }
        save()
    }

    // MARK: - Away sheet

    func dismissAwaySummary() {
        awaySummary = nil
    }
}
