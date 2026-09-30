import SpriteKit
import UIKit

/// Procedural visual core for Kiln Keeper: studio backdrop, the kiln itself
/// (re-themed per KilnSkin), firing/cooling glass pieces, embers, particles.
/// Everything is generated in code via UIGraphicsImageRenderer -> SKTexture.
/// No image assets. Adapted from Molten's GlassRenderer.
enum GlassRenderer {

    // MARK: - Texture helpers

    /// Cached soft round particle dot (white core fading to transparent).
    private static let softDotTexture: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.4).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0, 0.4, 1])!
            c.drawRadialGradient(gradient,
                                 startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                 endCenter: CGPoint(x: 16, y: 16), endRadius: 16,
                                 options: [])
        }
        return SKTexture(image: image)
    }()

    static func radialTexture(size: CGSize,
                              stops: [(CGFloat, UIColor)],
                              radius: CGFloat? = nil) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = radius ?? max(size.width, size.height) * 0.5
            let colors = stops.map { $0.1.cgColor } as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: stops.map { $0.0 })!
            c.drawRadialGradient(gradient,
                                 startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: r,
                                 options: [])
        }
        return SKTexture(image: image)
    }

    private static func darker(_ color: UIColor, factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }

    // MARK: - Studio background

    /// Dark cozy studio backdrop. Children are laid out around the node's
    /// center (caller positions the returned node, e.g. at the scene center).
    static func studioBackground(size: CGSize, emberColor: SKColor? = nil) -> SKNode {
        let root = SKNode()

        let bgImage = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let top = UIColor(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x14 / 255.0, alpha: 1)
            let bottom = UIColor(red: 0x1A / 255.0, green: 0x0F / 255.0, blue: 0x08 / 255.0, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [top.cgColor, bottom.cgColor] as CFArray,
                                      locations: [0, 1])!
            c.drawLinearGradient(gradient,
                                 start: CGPoint(x: size.width / 2, y: 0),
                                 end: CGPoint(x: size.width / 2, y: size.height),
                                 options: [])
        }
        let bg = SKSpriteNode(texture: SKTexture(image: bgImage), size: size)
        bg.zPosition = -10
        root.addChild(bg)

        let glow = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: size.width * 1.1, height: size.height * 0.55),
            stops: [
                (0.0, UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.55)),
                (0.5, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.18)),
                (1.0, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.0)),
            ]))
        glow.position = CGPoint(x: 0, y: -size.height * 0.32)
        glow.blendMode = .add
        glow.zPosition = -9
        root.addChild(glow)

        let vignette = SKSpriteNode(texture: radialTexture(
            size: size,
            stops: [
                (0.0, UIColor(white: 0, alpha: 0.0)),
                (0.55, UIColor(white: 0, alpha: 0.0)),
                (1.0, UIColor(white: 0, alpha: 0.7)),
            ],
            radius: hypot(size.width, size.height) / 2))
        vignette.zPosition = 10
        root.addChild(vignette)

        for x in [-size.width * 0.28, size.width * 0.28] {
            let emitter = emberEmitter(color: emberColor)
            emitter.position = CGPoint(x: x, y: -size.height * 0.38)
            emitter.zPosition = -8
            root.addChild(emitter)
        }

        return root
    }

    // MARK: - The kiln

    /// The kiln arch with a glowing fire mouth, brick courses, and a shelf
    /// beam. Re-themed per skin: brick color, mortar, and fire tint all
    /// change, so owned skins are unmistakable. `width` is the kiln's outer
    /// width; children are centered on the node's origin with the kiln
    /// mouth centered at `mouthCenter`.
    static func kilnNode(width: CGFloat, height: CGFloat, skin: KilnSkin) -> SKNode {
        let root = SKNode()
        let brick: UIColor = skin.brickColor
        let mortar: UIColor = skin.mortarColor
        let fire: UIColor = skin.fireColor

        // Kiln body: rounded arch (image space, y-down), brick courses drawn
        // as horizontal mortar lines + offset vertical joints.
        let bodyImage = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
            let c = ctx.cgContext
            let arch = UIBezierPath()
            let r = width / 2
            // Arch: rectangle with a semicircular top.
            arch.move(to: CGPoint(x: 0, y: height))
            arch.addLine(to: CGPoint(x: 0, y: r))
            arch.addArc(withCenter: CGPoint(x: r, y: r), radius: r,
                        startAngle: .pi, endAngle: 0, clockwise: true)
            arch.addLine(to: CGPoint(x: width, y: height))
            arch.close()
            c.setFillColor(brick.cgColor)
            c.addPath(arch.cgPath)
            c.fillPath()
            // Brick courses.
            c.setStrokeColor(mortar.cgColor)
            c.setLineWidth(max(2, width * 0.012))
            let courseH = height * 0.09
            var y = courseH
            var row = 0
            while y < height {
                c.move(to: CGPoint(x: 4, y: y))
                c.addLine(to: CGPoint(x: width - 4, y: y))
                c.strokePath()
                // Vertical joints, offset per row.
                let jointW = width * 0.18
                var x = row % 2 == 0 ? jointW / 2 : jointW
                while x < width {
                    c.move(to: CGPoint(x: x, y: max(0, y - courseH)))
                    c.addLine(to: CGPoint(x: x, y: y))
                    c.strokePath()
                    x += jointW
                }
                y += courseH
                row += 1
            }
            // Subtle top highlight for roundness.
            let hl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor(white: 1, alpha: 0.10).cgColor,
                                         UIColor(white: 1, alpha: 0.0).cgColor] as CFArray,
                                locations: [0, 1])!
            c.saveGState()
            c.addPath(arch.cgPath)
            c.clip()
            c.drawLinearGradient(hl, start: CGPoint(x: width / 2, y: 0),
                                 end: CGPoint(x: width / 2, y: height * 0.4), options: [])
            c.restoreGState()
        }
        let body = SKSpriteNode(texture: SKTexture(image: bodyImage))
        body.zPosition = 0
        root.addChild(body)

        // Kiln mouth: dark opening with animated fire glow (the flicker is
        // driven by KilnScene, which holds a reference by name).
        let mouthW = width * 0.62
        let mouthH = height * 0.30
        let mouthImage = UIGraphicsImageRenderer(size: CGSize(width: mouthW, height: mouthH)).image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(origin: .zero, size: CGSize(width: mouthW, height: mouthH))
            let p = UIBezierPath(roundedRect: rect, cornerRadius: mouthH * 0.45)
            c.setFillColor(UIColor(white: 0.02, alpha: 1).cgColor)
            c.addPath(p.cgPath)
            c.fillPath()
            // Inner fire gradient: hot core at the bottom.
            c.saveGState()
            c.addPath(p.cgPath)
            c.clip()
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [UIColor(white: 1, alpha: 0.95).cgColor,
                                        fire.withAlphaComponent(0.9).cgColor,
                                        fire.withAlphaComponent(0.15).cgColor] as CFArray,
                               locations: [0, 0.55, 1])!
            c.drawLinearGradient(g, start: CGPoint(x: mouthW / 2, y: mouthH),
                                 end: CGPoint(x: mouthW / 2, y: 0), options: [])
            c.restoreGState()
        }
        let mouth = SKSpriteNode(texture: SKTexture(image: mouthImage))
        mouth.name = "fireMouth"
        mouth.position = CGPoint(x: 0, y: -height * 0.18)
        mouth.zPosition = 1
        root.addChild(mouth)

        // Additive halo over the mouth for the flicker to breathe on.
        let halo = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: mouthW * 1.7, height: mouthH * 2.2),
            stops: [
                (0.0, fire.withAlphaComponent(0.55)),
                (0.6, fire.withAlphaComponent(0.18)),
                (1.0, fire.withAlphaComponent(0.0)),
            ]))
        halo.name = "fireHalo"
        halo.blendMode = .add
        halo.position = mouth.position
        halo.zPosition = 2
        root.addChild(halo)

        // Stone lintel above the mouth.
        let lintel = SKSpriteNode(color: darker(mortar, factor: 0.8),
                                  size: CGSize(width: mouthW * 1.12, height: height * 0.045))
        lintel.position = CGPoint(x: 0, y: mouth.position.y + mouthH / 2 + height * 0.03)
        lintel.zPosition = 1
        root.addChild(lintel)

        return root
    }

    // MARK: - Molten blob (firing piece)

    /// A gob of molten glass: white-hot core, additive glow layers.
    /// `heat` 1 = just started (white hot), 0 = cooled to its color.
    static func firingPieceNode(radius: CGFloat, color: PieceColor, heat: Double) -> SKNode {
        let root = SKNode()
        let base: UIColor = color.skColor
        let hot = UIColor(white: 1, alpha: 1)
        // Lerp the core color from white-hot to the glass color as it cools.
        let t = CGFloat(min(1, max(0, heat)))
        var hr: CGFloat = 0, hg: CGFloat = 0, hb: CGFloat = 0, ha: CGFloat = 0
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        hot.getRed(&hr, green: &hg, blue: &hb, alpha: &ha)
        base.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        let core = UIColor(red: cr + (hr - cr) * t, green: cg + (hg - cg) * t,
                           blue: cb + (hb - cb) * t, alpha: 1)
        let d = radius * 2
        let box = CGSize(width: d, height: d)

        let coreTexture = radialTexture(size: box, stops: [
            (0.0, .white),
            (0.30, core),
            (0.70, core.withAlphaComponent(0.6)),
            (1.0, core.withAlphaComponent(0.0)),
        ])

        let coreNode = SKSpriteNode(texture: coreTexture)
        coreNode.zPosition = 2
        let mid = SKSpriteNode(texture: coreTexture)
        mid.setScale(1.8)
        mid.blendMode = .add
        mid.alpha = 0.5
        mid.zPosition = 1
        let halo = SKSpriteNode(texture: coreTexture)
        halo.setScale(2.8)
        halo.blendMode = .add
        halo.alpha = 0.22
        halo.zPosition = 0
        root.addChild(halo)
        root.addChild(mid)
        root.addChild(coreNode)
        return root
    }

    // MARK: - Finished piece

    /// Silhouette for each shape, drawn in a square box (image space, y-down).
    static func silhouettePath(for shape: PieceShape, in rect: CGRect) -> CGPath {
        let p = UIBezierPath()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let minY = rect.minY
        switch shape {
        case .orb:
            p.append(UIBezierPath(ovalIn: rect.insetBy(dx: w * 0.06, dy: h * 0.06)))
        case .teardrop:
            p.move(to: CGPoint(x: cx, y: minY + h * 0.04))
            p.addCurve(to: CGPoint(x: cx - w * 0.36, y: minY + h * 0.60),
                       controlPoint1: CGPoint(x: cx - w * 0.05, y: minY + h * 0.16),
                       controlPoint2: CGPoint(x: cx - w * 0.30, y: minY + h * 0.36))
            p.addCurve(to: CGPoint(x: cx, y: minY + h * 0.96),
                       controlPoint1: CGPoint(x: cx - w * 0.40, y: minY + h * 0.80),
                       controlPoint2: CGPoint(x: cx - w * 0.16, y: minY + h * 0.96))
            p.addCurve(to: CGPoint(x: cx + w * 0.36, y: minY + h * 0.60),
                       controlPoint1: CGPoint(x: cx + w * 0.16, y: minY + h * 0.96),
                       controlPoint2: CGPoint(x: cx + w * 0.40, y: minY + h * 0.80))
            p.addCurve(to: CGPoint(x: cx, y: minY + h * 0.04),
                       controlPoint1: CGPoint(x: cx + w * 0.30, y: minY + h * 0.36),
                       controlPoint2: CGPoint(x: cx + w * 0.05, y: minY + h * 0.16))
            p.close()
        case .vase:
            p.append(UIBezierPath(roundedRect: CGRect(x: cx - w * 0.20, y: minY + h * 0.05,
                                                     width: w * 0.40, height: h * 0.07),
                                              cornerRadius: h * 0.035))
            p.append(UIBezierPath(rect: CGRect(x: cx - w * 0.11, y: minY + h * 0.11,
                                               width: w * 0.22, height: h * 0.32)))
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.37, y: minY + h * 0.38,
                                                 width: w * 0.74, height: h * 0.58)))
        case .twist:
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.34, y: minY + h * 0.06,
                                                 width: w * 0.56, height: h * 0.40)))
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.22, y: minY + h * 0.52,
                                                 width: w * 0.62, height: h * 0.44)))
        }
        return p.cgPath
    }

    /// A cooled glass piece: translucent gradient body, drop shadow, additive
    /// inner glow, caustic highlight streak, rim-light crescent.
    static func finishedPieceNode(shape: PieceShape, color: PieceColor, size: CGFloat) -> SKNode {
        let root = SKNode()
        let base: UIColor = color.skColor
        let glow: UIColor = color.glowColor
        let box = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let silhouette = UIBezierPath(cgPath: silhouettePath(for: shape, in: box))

        let shadow = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: size * 0.95, height: size * 0.30),
            stops: [
                (0.0, UIColor(white: 0, alpha: 0.5)),
                (0.6, UIColor(white: 0, alpha: 0.25)),
                (1.0, UIColor(white: 0, alpha: 0.0)),
            ]))
        shadow.position = CGPoint(x: 0, y: -size / 2 - size * 0.05)
        shadow.zPosition = -1
        root.addChild(shadow)

        let bodyImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            c.saveGState()
            c.addPath(silhouette.cgPath)
            c.clip()
            let topColor = base.withAlphaComponent(0.55)
            let bottomColor = darker(base, factor: 0.45).withAlphaComponent(0.85)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                                      locations: [0, 1])!
            c.drawLinearGradient(gradient,
                                 start: CGPoint(x: size / 2, y: 0),
                                 end: CGPoint(x: size / 2, y: size),
                                 options: [])
            c.restoreGState()

            c.saveGState()
            c.clip(to: CGRect(x: 0, y: 0, width: size * 0.55, height: size * 0.55))
            c.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor)
            c.setLineWidth(max(2, size * 0.03))
            c.setLineCap(.round)
            c.addPath(silhouette.cgPath)
            c.strokePath()
            c.restoreGState()
        }
        let body = SKSpriteNode(texture: SKTexture(image: bodyImage))
        root.addChild(body)

        let innerGlowImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(glow.withAlphaComponent(0.6).cgColor)
            c.addPath(silhouette.cgPath)
            c.fillPath()
        }
        let innerGlow = SKSpriteNode(texture: SKTexture(image: innerGlowImage))
        innerGlow.blendMode = .add
        innerGlow.alpha = 0.35
        root.addChild(innerGlow)

        let streakImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            let streak = UIBezierPath()
            streak.move(to: CGPoint(x: size * 0.30, y: size * 0.26))
            streak.addCurve(to: CGPoint(x: size * 0.38, y: size * 0.72),
                            controlPoint1: CGPoint(x: size * 0.20, y: size * 0.42),
                            controlPoint2: CGPoint(x: size * 0.28, y: size * 0.58))
            c.setStrokeColor(UIColor(white: 1, alpha: 1).cgColor)
            c.setLineWidth(max(2, size * 0.05))
            c.setLineCap(.round)
            c.addPath(streak.cgPath)
            c.strokePath()
        }
        let caustic = SKSpriteNode(texture: SKTexture(image: streakImage))
        caustic.blendMode = .add
        caustic.alpha = 0.35
        root.addChild(caustic)

        return root
    }

    // MARK: - Particles

    /// Ambient rising sparks, tinted per kiln skin.
    static func emberEmitter(color: SKColor? = nil) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softDotTexture
        e.particleBirthRate = 10
        e.particleLifetime = 2.6
        e.particleLifetimeRange = 1.0
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 65
        e.particleSpeedRange = 25
        e.xAcceleration = 8
        e.particleScale = 0.05
        e.particleScaleSpeed = -0.015
        e.particleColor = color ?? SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1.0)
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -0.3
        e.particleBlendMode = .add
        e.particlePositionRange = CGVector(dx: 50, dy: 8)
        return e
    }

    /// One-shot celebration burst. The caller positions the returned node;
    /// it removes itself after firing.
    static func burst(at point: CGPoint, color: SKColor) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.position = point
        e.particleTexture = softDotTexture
        e.numParticlesToEmit = 42
        e.particleBirthRate = 300
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 130
        e.particleSpeedRange = 130
        e.particleLifetime = 0.9
        e.particleScale = 0.1
        e.particleScaleSpeed = -0.09
        e.particleColor = color
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 1.0
        e.particleAlphaSpeed = -1.0
        e.particleBlendMode = .add
        e.yAcceleration = -120
        e.run(.sequence([
            SKAction.wait(forDuration: 1.4),
            SKAction.removeFromParent(),
        ]))
        return e
    }

    /// A gold coin that flies to a target point, then calls completion.
    /// Used for the collect coin-fly juice.
    static func coinFly(from: CGPoint, to: CGPoint, completion: @escaping () -> Void) -> SKNode {
        let root = SKNode()
        root.position = from
        let coinImage = UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { ctx in
            let c = ctx.cgContext
            let gold = UIColor(red: 1.0, green: 0.84, blue: 0.20, alpha: 1)
            c.setFillColor(gold.cgColor)
            c.fillEllipse(in: CGRect(x: 2, y: 2, width: 40, height: 40))
            c.setFillColor(darker(gold, factor: 0.72).cgColor)
            c.fillEllipse(in: CGRect(x: 9, y: 9, width: 26, height: 26))
            c.setFillColor(gold.cgColor)
            c.fillEllipse(in: CGRect(x: 13, y: 13, width: 18, height: 18))
        }
        let coin = SKSpriteNode(texture: SKTexture(image: coinImage))
        coin.zPosition = 20
        root.addChild(coin)
        let glowDot = SKSpriteNode(texture: softDotTexture)
        glowDot.setScale(1.6)
        glowDot.color = SKColor(red: 1.0, green: 0.84, blue: 0.2, alpha: 1)
        glowDot.colorBlendFactor = 1
        glowDot.blendMode = .add
        glowDot.alpha = 0.6
        glowDot.zPosition = 19
        root.addChild(glowDot)

        let mid = CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + 120)
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: to.x - from.x, y: to.y - from.y),
                          control: CGPoint(x: mid.x - from.x, y: mid.y - from.y))
        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.55)
        fly.timingMode = .easeIn
        coin.run(.repeatForever(.sequence([
            SKAction.scaleX(to: 0.25, duration: 0.12),
            SKAction.scaleX(to: 1.0, duration: 0.12),
        ])))
        root.run(.sequence([
            fly,
            SKAction.run { completion() },
            SKAction.removeFromParent(),
        ]))
        return root
    }
}
