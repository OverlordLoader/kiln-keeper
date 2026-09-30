import SwiftUI
import SpriteKit

// MARK: - Piece shape

enum PieceShape: String, CaseIterable, Codable, Identifiable {
    case vase, orb, teardrop, twist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vase: return "Vase"
        case .orb: return "Orb"
        case .teardrop: return "Teardrop"
        case .twist: return "Twist"
        }
    }
}

// MARK: - Piece color + rarity

/// Glass colors in five rarity tiers. Tiers 1-4 unlock through the
/// "Rarer glass" upgrade track; rarer colors sell for more.
enum PieceColor: String, CaseIterable, Codable, Identifiable {
    // Tier 0 — always available
    case ember, ocean, forest
    // Tier 1 — Uncommon
    case violet, rose
    // Tier 2 — Rare
    case frost, aurora
    // Tier 3 — Epic
    case magma, solar
    // Tier 4 — Legendary
    case abyss, void

    var id: String { rawValue }

    var rarityTier: Int {
        switch self {
        case .ember, .ocean, .forest: return 0
        case .violet, .rose: return 1
        case .frost, .aurora: return 2
        case .magma, .solar: return 3
        case .abyss, .void: return 4
        }
    }

    var rarityName: String {
        ["Common", "Uncommon", "Rare", "Epic", "Legendary"][rarityTier]
    }

    /// Candy accent used for rarity badges in SwiftUI.
    var rarityAccent: Color {
        switch rarityTier {
        case 0: return Color(hex: 0x9AA5B1)
        case 1: return Color(hex: 0x7ED957)
        case 2: return Color(hex: 0x3AB6FF)
        case 3: return Color(hex: 0xA259FF)
        default: return Color(hex: 0xFFD60A)
        }
    }

    /// Coins earned when this color sells. Tuned so the first session
    /// feels generous: ~3-4 min of firing buys the 4th shelf slot.
    var sellValue: Int {
        switch rarityTier {
        case 0: return 10
        case 1: return 25
        case 2: return 60
        case 3: return 140
        default: return 320
        }
    }

    static func colors(upto tier: Int) -> [PieceColor] {
        allCases.filter { $0.rarityTier <= tier }
    }

    /// Weighted random: common colors fire most often, legendaries rarely.
    static func random(upto tier: Int) -> PieceColor {
        let pool = colors(upto: tier)
        let weights = [50, 28, 14, 6, 2]
        let total = pool.reduce(0) { $0 + weights[$1.rarityTier] }
        var roll = Int.random(in: 0..<total)
        for color in pool {
            roll -= weights[color.rarityTier]
            if roll < 0 { return color }
        }
        return .ember
    }

    var displayName: String {
        switch self {
        case .ember: return "Ember"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .violet: return "Violet"
        case .rose: return "Rose"
        case .frost: return "Frost"
        case .aurora: return "Aurora"
        case .magma: return "Magma"
        case .solar: return "Solar"
        case .abyss: return "Abyss"
        case .void: return "Void"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .ember: return Color(red: 1.0, green: 0.36, blue: 0.12)
        case .ocean: return Color(red: 0.10, green: 0.55, blue: 0.78)
        case .forest: return Color(red: 0.20, green: 0.62, blue: 0.28)
        case .violet: return Color(red: 0.55, green: 0.30, blue: 0.85)
        case .rose: return Color(red: 0.95, green: 0.35, blue: 0.55)
        case .frost: return Color(red: 0.65, green: 0.85, blue: 0.95)
        case .aurora: return Color(red: 0.20, green: 0.90, blue: 0.70)
        case .magma: return Color(red: 0.75, green: 0.12, blue: 0.08)
        case .solar: return Color(red: 1.0, green: 0.80, blue: 0.20)
        case .abyss: return Color(red: 0.08, green: 0.15, blue: 0.35)
        case .void: return Color(red: 0.15, green: 0.08, blue: 0.22)
        }
    }

    var skColor: SKColor {
        switch self {
        case .ember: return SKColor(red: 1.0, green: 0.36, blue: 0.12, alpha: 1.0)
        case .ocean: return SKColor(red: 0.10, green: 0.55, blue: 0.78, alpha: 1.0)
        case .forest: return SKColor(red: 0.20, green: 0.62, blue: 0.28, alpha: 1.0)
        case .violet: return SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1.0)
        case .rose: return SKColor(red: 0.95, green: 0.35, blue: 0.55, alpha: 1.0)
        case .frost: return SKColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 1.0)
        case .aurora: return SKColor(red: 0.20, green: 0.90, blue: 0.70, alpha: 1.0)
        case .magma: return SKColor(red: 0.75, green: 0.12, blue: 0.08, alpha: 1.0)
        case .solar: return SKColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1.0)
        case .abyss: return SKColor(red: 0.08, green: 0.15, blue: 0.35, alpha: 1.0)
        case .void: return SKColor(red: 0.15, green: 0.08, blue: 0.22, alpha: 1.0)
        }
    }

    var glowColor: SKColor {
        switch self {
        case .ember: return SKColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0)
        case .ocean: return SKColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0)
        case .forest: return SKColor(red: 0.45, green: 0.90, blue: 0.50, alpha: 1.0)
        case .violet: return SKColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 1.0)
        case .rose: return SKColor(red: 1.0, green: 0.60, blue: 0.75, alpha: 1.0)
        case .frost: return SKColor(red: 0.90, green: 0.97, blue: 1.0, alpha: 1.0)
        case .aurora: return SKColor(red: 0.45, green: 1.0, blue: 0.85, alpha: 1.0)
        case .magma: return SKColor(red: 1.0, green: 0.35, blue: 0.15, alpha: 1.0)
        case .solar: return SKColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1.0)
        case .abyss: return SKColor(red: 0.25, green: 0.40, blue: 0.75, alpha: 1.0)
        case .void: return SKColor(red: 0.35, green: 0.20, blue: 0.50, alpha: 1.0)
        }
    }
}

// MARK: - Kiln skin

/// Cosmetic kiln skins. Classic is free; the other two are one-time
/// non-consumable IAPs that visibly re-theme the kiln art.
enum KilnSkin: String, CaseIterable, Codable, Identifiable {
    case classic, emberforge, tideglass

    var id: String { rawValue }

    /// Must match the product created in App Store Connect exactly.
    var productID: String? {
        switch self {
        case .classic: return nil
        case .emberforge: return "app.kilnkeeper.game.skin.emberforge"
        case .tideglass: return "app.kilnkeeper.game.skin.tideglass"
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Classic Kiln"
        case .emberforge: return "Emberforge Kiln"
        case .tideglass: return "Tideglass Kiln"
        }
    }

    var tagline: String {
        switch self {
        case .classic: return "Warm brick, the way kilns have always looked"
        case .emberforge: return "Dark volcanic stone with magma fire"
        case .tideglass: return "Ocean-teal stone with cool blue fire"
        }
    }

    /// Fallback price shown if the App Store product hasn't loaded yet.
    var fallbackPrice: String { "$1.99" }

    /// Brick body color of the kiln arch.
    var brickColor: SKColor {
        switch self {
        case .classic: return SKColor(red: 0.42, green: 0.20, blue: 0.12, alpha: 1.0)
        case .emberforge: return SKColor(red: 0.13, green: 0.11, blue: 0.13, alpha: 1.0)
        case .tideglass: return SKColor(red: 0.10, green: 0.25, blue: 0.28, alpha: 1.0)
        }
    }

    /// Mortar lines between bricks.
    var mortarColor: SKColor {
        switch self {
        case .classic: return SKColor(red: 0.24, green: 0.11, blue: 0.07, alpha: 1.0)
        case .emberforge: return SKColor(red: 0.30, green: 0.08, blue: 0.06, alpha: 1.0)
        case .tideglass: return SKColor(red: 0.05, green: 0.14, blue: 0.17, alpha: 1.0)
        }
    }

    /// Fire glow tint inside the kiln mouth.
    var fireColor: SKColor {
        switch self {
        case .classic: return SKColor(red: 1.0, green: 0.50, blue: 0.15, alpha: 1.0)
        case .emberforge: return SKColor(red: 1.0, green: 0.22, blue: 0.08, alpha: 1.0)
        case .tideglass: return SKColor(red: 0.25, green: 0.85, blue: 0.95, alpha: 1.0)
        }
    }

    var emberColor: SKColor {
        switch self {
        case .classic: return SKColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1.0)
        case .emberforge: return SKColor(red: 1.0, green: 0.30, blue: 0.10, alpha: 1.0)
        case .tideglass: return SKColor(red: 0.40, green: 0.90, blue: 1.0, alpha: 1.0)
        }
    }
}

// MARK: - Fired piece

struct KilnPiece: Identifiable, Codable {
    let id: UUID
    var shape: PieceShape
    var color: PieceColor
    var firedAt: Date

    init(shape: PieceShape = PieceShape.allCases.randomElement()!,
         color: PieceColor, firedAt: Date = Date()) {
        self.id = UUID()
        self.shape = shape
        self.color = color
        self.firedAt = firedAt
    }

    var title: String { "\(color.displayName) \(shape.displayName)" }
    var sellValue: Int { color.sellValue }
}

// MARK: - Shelf slot

/// One kiln shelf slot. `readyAt == nil` means the slot is empty;
/// a future date means firing; a past date means ready to collect.
struct ShelfSlot: Identifiable, Codable {
    let id: UUID
    var piece: KilnPiece?
    var readyAt: Date?

    init() {
        self.id = UUID()
        self.piece = nil
        self.readyAt = nil
    }

    var isEmpty: Bool { piece == nil }
    var isReady: Bool { piece != nil && (readyAt ?? .distantFuture) <= Date() }
    var isFiring: Bool { piece != nil && (readyAt ?? .distantPast) > Date() }

    func progress(now: Date = Date(), fireDuration: TimeInterval) -> Double {
        guard let piece, let readyAt else { return 0 }
        let start = readyAt.addingTimeInterval(-fireDuration)
        guard fireDuration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / fireDuration))
    }
}

// MARK: - Balance

/// All tuning lives here so the economy can be rebalanced in one place.
enum Balance {
    static let baseFireTime: TimeInterval = 60
    static let startingCoins = 50
    static let startingSlots = 3
    static let maxSlots = 8
    /// Each speed level multiplies fire time by this (12% faster per level).
    static let speedFactorPerLevel = 0.88
    static let maxSpeedLevel = 10
    static let maxColorTier = 4
    /// 2x speed boost from a rewarded ad lasts this long.
    static let boostDuration: TimeInterval = 10 * 60
    /// Offline progress is capped at this many hours (fairness cap).
    static let offlineCapHours = 8.0

    /// Cost of the (slotCount+1)-th shelf slot.
    static func slotCost(forSlotCount count: Int) -> Int {
        // count = current slots; buying slot #4 costs 100, #5 250, ...
        let table = [100, 250, 500, 1000, 2000]
        let index = count - startingSlots
        guard index >= 0, index < table.count else { return Int.max }
        return table[index]
    }

    /// Cost of the next speed level (level = current level, 0-based).
    static func speedCost(forLevel level: Int) -> Int {
        Int(80 * pow(2.0, Double(level)))
    }

    /// Cost to unlock color tier (tier = tier being unlocked, 1-based).
    static func colorTierCost(forTier tier: Int) -> Int {
        let table = [0, 150, 400, 1000, 2500]
        guard tier >= 1, tier < table.count else { return Int.max }
        return table[tier]
    }

    static func fireDuration(speedLevel: Int, boosted: Bool) -> TimeInterval {
        let base = baseFireTime * pow(speedFactorPerLevel, Double(speedLevel))
        return boosted ? base / 2 : base
    }
}
