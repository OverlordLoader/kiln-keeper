import SpriteKit
import UIKit

/// The live kiln: studio backdrop, skin-themed kiln arch with flickering
/// fire, and one tappable shelf slot per kiln shelf. The scene renders
/// `GameState` every frame (progress rings, cooling colors, ready pulses)
/// and reports taps back to SwiftUI via `onTapSlot`.
@MainActor
final class KilnScene: SKScene {
    var game: GameState!
    var onTapSlot: ((Int) -> Void)?

    private var kilnRoot: SKNode?
    private var slotNodes: [SKNode] = []
    private var shelfBoards: [SKNode] = []
    private var fireHalo: SKNode?
    private var fireMouth: SKNode?
    private var lastSignature = ""
    private var elapsed: TimeInterval = 0

    override convenience init() {
        self.init(size: CGSize(width: 390, height: 700))
        scaleMode = .resizeFill
        backgroundColor = SKColor(white: 0.03, alpha: 1.0)
    }

    override func didMove(to view: SKView) {
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    // MARK: - Layout

    private func layout() {
        // SpriteKit may notify a size change during initialization, before
        // KilnView injects game. didMove performs the first bound layout.
        guard game != nil else { return }
        removeAllChildren()
        slotNodes = []
        shelfBoards = []
        lastSignature = ""

        let W = size.width, H = size.height
        let center = CGPoint(x: W / 2, y: H / 2)

        let bg = GlassRenderer.studioBackground(size: size, emberColor: game.equippedSkin.emberColor)
        bg.position = center
        addChild(bg)

        buildKiln()
        buildShelves()
        syncSlots(force: true)
    }

    private func buildKiln() {
        let W = size.width, H = size.height
        let kw = min(W * 0.88, 360)
        let kh = kw * 1.02
        let kiln = GlassRenderer.kilnNode(width: kw, height: kh, skin: game.equippedSkin)
        kiln.position = CGPoint(x: W / 2, y: H * 0.62)
        addChild(kiln)
        kilnRoot = kiln
        fireHalo = kiln.childNode(withName: "fireHalo")
        fireMouth = kiln.childNode(withName: "fireMouth")

        // Embers rising from the kiln mouth.
        let embers = GlassRenderer.emberEmitter(color: game.equippedSkin.emberColor)
        embers.position = CGPoint(x: W / 2, y: H * 0.62 - kh * 0.18)
        embers.zPosition = 3
        addChild(embers)

        // Start the fire flicker.
        fireHalo?.run(.repeatForever(.sequence([
            SKAction.fadeAlpha(to: 0.85, duration: 0.28),
            SKAction.fadeAlpha(to: 0.55, duration: 0.34),
        ])))
    }

    /// Re-themes the kiln when the player equips a different skin.
    func setSkin(_ skin: KilnSkin) {
        game.equippedSkin = skin
        layout()
    }

    private func slotGridPositions(count: Int) -> [CGPoint] {
        let W = size.width, H = size.height
        let cols = 4
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        let sx = min(86, (W - 48) / CGFloat(cols))
        let sy: CGFloat = 104
        let gridH = CGFloat(rows - 1) * sy
        let cy = H * 0.30 + gridH / 2
        var pts: [CGPoint] = []
        for i in 0..<count {
            let r = i / cols, c = i % cols
            // Center the last row if it isn't full.
            let rowCount = min(cols, count - r * cols)
            let rowW = CGFloat(rowCount - 1) * sx
            let x = W / 2 - rowW / 2 + CGFloat(c) * sx
            let y = cy - CGFloat(r) * sy
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }

    private func buildShelves() {
        let positions = slotGridPositions(count: game.slotCount)
        let cols = 4
        let rows = max(1, Int(ceil(Double(game.slotCount) / Double(cols))))
        let sx = min(86, (size.width - 48) / CGFloat(cols))
        for r in 0..<rows {
            let rowCount = min(cols, game.slotCount - r * cols)
            guard rowCount > 0 else { continue }
            let rowW = CGFloat(rowCount - 1) * sx + 96
            let board = SKSpriteNode(color: SKColor(red: 0.23, green: 0.14, blue: 0.09, alpha: 1),
                                     size: CGSize(width: rowW, height: 10))
            let y = positions[r * cols].y - 40
            board.position = CGPoint(x: size.width / 2, y: y)
            board.zPosition = -1
            // Board highlight line.
            let edge = SKSpriteNode(color: SKColor(red: 0.35, green: 0.22, blue: 0.14, alpha: 1),
                                    size: CGSize(width: rowW, height: 2))
            edge.position = CGPoint(x: 0, y: 5)
            board.addChild(edge)
            addChild(board)
            shelfBoards.append(board)
        }
        for (i, pt) in positions.enumerated() {
            let holder = SKNode()
            holder.name = "slot_\(i)"
            holder.position = pt
            holder.zPosition = 5
            addChild(holder)
            slotNodes.append(holder)
        }
    }

    // MARK: - Per-frame sync

    override func update(_ currentTime: TimeInterval) {
        elapsed = currentTime
        syncSlots(force: false)
    }

    private func signature() -> String {
        var parts: [String] = []
        let now = Date()
        for s in game.slots {
            if s.isEmpty { parts.append("E") }
            else if s.isReady { parts.append("R\(s.piece?.id.uuidString ?? "?")") }
            else {
                let bucket = Int(s.progress(now: now, fireDuration: game.fireDuration) * 8)
                parts.append("F\(s.piece?.id.uuidString ?? "?"):\(bucket)")
            }
        }
        parts.append(game.equippedSkin.rawValue)
        return parts.joined(separator: "|")
    }

    private func syncSlots(force: Bool) {
        // Slot count changed (upgrade bought) → rebuild the whole shelf grid.
        if slotNodes.count != game.slotCount {
            for n in slotNodes { n.removeFromParent() }
            for b in shelfBoards { b.removeFromParent() }
            slotNodes = []
            shelfBoards = []
            buildShelves()
            lastSignature = ""
        }
        let sig = signature()
        guard force || sig != lastSignature else { return }
        lastSignature = sig
        for (i, holder) in slotNodes.enumerated() {
            guard game.slots.indices.contains(i) else { continue }
            rebuildSlot(holder, slot: game.slots[i], index: i)
        }
    }

    private func rebuildSlot(_ holder: SKNode, slot: ShelfSlot, index: Int) {
        holder.removeAllChildren()
        if slot.isEmpty {
            let ring = SKShapeNode(circleOfRadius: 24)
            ring.strokeColor = SKColor(white: 1, alpha: 0.22)
            ring.lineWidth = 2
            ring.fillColor = .clear
            holder.addChild(ring)
        } else if let piece = slot.piece, slot.isReady {
            let node = GlassRenderer.finishedPieceNode(shape: piece.shape, color: piece.color, size: 54)
            holder.addChild(node)
            // Pulsing "ready" ring.
            let pulse = SKShapeNode(circleOfRadius: 34)
            pulse.strokeColor = SKColor(red: 1, green: 0.84, blue: 0.2, alpha: 0.9)
            pulse.lineWidth = 3
            pulse.fillColor = .clear
            holder.addChild(pulse)
            pulse.run(.repeatForever(.sequence([
                SKAction.scale(to: 1.12, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5),
            ])))
            pulse.run(.repeatForever(.sequence([
                SKAction.fadeAlpha(to: 0.45, duration: 0.5),
                SKAction.fadeAlpha(to: 0.9, duration: 0.5),
            ])))
            // Gentle bob so ready pieces beg to be tapped.
            node.run(.repeatForever(.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.6),
                SKAction.moveBy(x: 0, y: -5, duration: 0.6),
            ])))
        } else if let piece = slot.piece {
            let progress = slot.progress(fireDuration: game.fireDuration)
            let heat = 1.0 - progress
            let blob = GlassRenderer.firingPieceNode(radius: 26, color: piece.color, heat: heat)
            holder.addChild(blob)
            // Progress ring.
            let ring = SKShapeNode(circleOfRadius: 34)
            ring.strokeColor = SKColor(white: 1, alpha: 0.18)
            ring.lineWidth = 4
            ring.fillColor = .clear
            holder.addChild(ring)
            let arc = SKShapeNode()
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 34,
                        startAngle: .pi / 2, endAngle: .pi / 2 + CGFloat(progress) * 2 * .pi,
                        clockwise: false)
            arc.path = path
            arc.strokeColor = piece.color.glowColor
            arc.lineWidth = 4
            arc.fillColor = .clear
            arc.lineCap = .round
            holder.addChild(arc)
        }
    }

    // MARK: - Taps

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        for node in nodes(at: pt) {
            var n: SKNode? = node
            while let cur = n {
                if let name = cur.name, name.hasPrefix("slot_"),
                   let idx = Int(name.dropFirst(5)) {
                    Haptics.selection()
                    onTapSlot?(idx)
                    return
                }
                n = cur.parent
            }
        }
    }

    // MARK: - Collect juice

    /// Celebration burst + a quick pop on the collected shelf.
    func playCollect(at index: Int, piece: KilnPiece) {
        guard slotNodes.indices.contains(index) else { return }
        let holder = slotNodes[index]
        addChild(GlassRenderer.burst(at: holder.position, color: piece.color.glowColor))
        holder.run(.sequence([
            SKAction.scale(to: 1.25, duration: 0.10),
            SKAction.scale(to: 1.0, duration: 0.14),
        ]))
        lastSignature = "" // force a re-sync so the new firing piece appears
    }
}
