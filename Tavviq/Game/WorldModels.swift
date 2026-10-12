import SceneKit

/// Prototype factory for every world prop. Prototypes are built once and flattened,
/// then `clone()`d (clones share geometry, so they are almost free).
enum Models {
    private static var cache: [String: SCNNode] = [:]

    private static func proto(_ key: String, flatten: Bool = true, _ build: () -> SCNNode) -> SCNNode {
        if let n = cache[key] { return n.clone() }
        let raw = build()
        let n = flatten ? raw.flattenedClone() : raw
        cache[key] = n
        return n.clone()
    }

    // MARK: - Ground

    static let worldHalf: Float = 20
    static let playHalf: Float = 4.5

    static func ground(top: Float, depth: CGFloat = 0.5, color: UInt32, sideDarken: Float = 0.14) -> SCNNode {
        proto("ground-\(top)-\(color)-\(sideDarken)") {
            let n = SCNNode()
            let side = CGFloat(worldHalf - playHalf)
            Vox.box(CGFloat(playHalf * 2), depth, 1.0, color, x: 0, y: top - Float(depth), z: 0, chamfer: 0, in: n)
            let dark = shade(color, -sideDarken)
            Vox.box(side, depth, 1.0, dark, x: -(playHalf + Float(side) / 2), y: top - Float(depth), z: 0, chamfer: 0, in: n)
            Vox.box(side, depth, 1.0, dark, x: (playHalf + Float(side) / 2), y: top - Float(depth), z: 0, chamfer: 0, in: n)
            return n
        }
    }

    static func roadLines(color: UInt32 = 0xf3f3f3) -> SCNNode {
        proto("roadlines-\(color)") {
            let n = SCNNode()
            var x: Float = -worldHalf
            while x < worldHalf {
                Vox.box(0.62, 0.02, 0.08, color, x: x, y: -0.06, z: -0.5, chamfer: 0, in: n)
                x += 1.6
            }
            return n
        }
    }

    static func roadCurb() -> SCNNode {
        proto("curb") {
            let n = SCNNode()
            Vox.box(CGFloat(worldHalf * 2), 0.05, 0.08, 0x8e93a0, x: 0, y: -0.06, z: 0.46, chamfer: 0, in: n)
            return n
        }
    }

    static func rails() -> SCNNode {
        proto("rails") {
            let n = SCNNode()
            var x: Float = -worldHalf
            while x < worldHalf {
                Vox.box(0.2, 0.06, 0.9, 0x7a5638, x: x, y: -0.04, z: 0, chamfer: 0.01, in: n)
                x += 0.6
            }
            Vox.box(CGFloat(worldHalf * 2), 0.08, 0.07, 0xa9b2bd, x: 0, y: 0.0, z: -0.26, chamfer: 0, in: n)
            Vox.box(CGFloat(worldHalf * 2), 0.08, 0.07, 0xa9b2bd, x: 0, y: 0.0, z: 0.26, chamfer: 0, in: n)
            return n
        }
    }

    static func foam(z: Float) -> SCNNode {
        proto("foam-\(z)") {
            let n = SCNNode()
            Vox.box(CGFloat(worldHalf * 2), 0.03, 0.1, 0xe9fbff, x: 0, y: -0.27, z: z, chamfer: 0, alpha: 0.8, in: n)
            return n
        }
    }

    /// A signal post with its own (unshared) light material so it can blink.
    static func signal() -> (node: SCNNode, light: SCNMaterial) {
        let n = SCNNode()
        Vox.box(0.1, 0.9, 0.1, 0x3c3f48, x: 0, y: 0, z: 0, chamfer: 0.01, in: n)
        Vox.box(0.34, 0.26, 0.14, 0x22242b, x: 0, y: 0.82, z: 0, chamfer: 0.03, in: n)
        let g = SCNBox(width: 0.12, height: 0.12, length: 0.06, chamferRadius: 0.02)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(hex: 0x5a1b1b)
        g.firstMaterial = m
        let l = SCNNode(geometry: g)
        l.position = SCNVector3(0, 0.95, -0.08)
        n.addChildNode(l)
        return (n, m)
    }

    // MARK: - Obstacles (one tile)

    static func obstacle(biome: Int, variant: Int) -> SCNNode {
        let v = variant
        switch biome {
        case 0: return [roundTree(0x6cc24a, 0x5aae3c, tiers: 1 + v % 3), roundTree(0x4fae46, 0x3f9a3a, tiers: 2), rock(0xa7adb6), bush(0x5fb848)][v % 4]
        case 1: return [roundTree(0xf08a24, 0xe06f1c, tiers: 1 + v % 3), roundTree(0xe5482f, 0xc93a26, tiers: 2), roundTree(0xffc02e, 0xeca81f, tiers: 1), pumpkin()][v % 4]
        case 2: return [pine(snow: true, tiers: 3), pine(snow: true, tiers: 2), snowman(), rock(0xc5d2e2)][v % 4]
        case 3: return [palm(), palm(), v % 3 == 0 ? parasol(v % 2 == 0 ? 0xff5a7a : 0x3db8ff) : palm(), rock(0xd9c79a)][v % 4]
        case 4: return [cactus(arms: v % 2 == 0), cactus(arms: true), mesa(), rock(0xc98a5a)][v % 4]
        default: return [building(v), building(v + 3), streetTree(), building(v + 7)][v % 4]
        }
    }

    static func roundTree(_ leaf: UInt32, _ leafDark: UInt32, tiers: Int) -> SCNNode {
        proto("tree-\(leaf)-\(tiers)") {
            let n = SCNNode()
            Vox.box(0.24, 0.32, 0.24, 0x8a5a3a, x: 0, y: 0, z: 0, chamfer: 0.02, in: n)
            var y: Float = 0.3
            for i in 0..<tiers {
                let s = CGFloat(0.78 - Double(i) * 0.06)
                let h: CGFloat = 0.42
                Vox.box(s, h, s, i % 2 == 0 ? leaf : leafDark, x: 0, y: y, z: 0, chamfer: 0.05, in: n)
                y += Float(h)
            }
            return n
        }
    }

    static func pine(snow: Bool, tiers: Int) -> SCNNode {
        proto("pine-\(snow)-\(tiers)") {
            let n = SCNNode()
            Vox.box(0.2, 0.26, 0.2, 0x7a4f33, x: 0, y: 0, z: 0, chamfer: 0.02, in: n)
            var y: Float = 0.24
            for i in 0..<tiers {
                let s = CGFloat(0.82 - Double(i) * 0.22)
                Vox.box(s, 0.34, s, 0x2f7d55, x: 0, y: y, z: 0, chamfer: 0.04, in: n)
                if snow { Vox.box(s * 0.9, 0.08, s * 0.9, 0xffffff, x: 0, y: y + 0.32, z: 0, chamfer: 0.03, in: n) }
                y += 0.34
            }
            return n
        }
    }

    static func rock(_ c: UInt32) -> SCNNode {
        proto("rock-\(c)") {
            let n = SCNNode()
            Vox.box(0.72, 0.36, 0.64, c, x: 0, y: 0, z: 0, chamfer: 0.08, in: n)
            Vox.box(0.44, 0.2, 0.4, shade(c, 0.12), x: -0.06, y: 0.34, z: 0.04, chamfer: 0.06, in: n)
            return n
        }
    }

    static func bush(_ c: UInt32) -> SCNNode {
        proto("bush-\(c)") {
            let n = SCNNode()
            Vox.box(0.7, 0.4, 0.66, c, x: 0, y: 0, z: 0, chamfer: 0.12, in: n)
            Vox.box(0.08, 0.08, 0.08, 0xff4d6d, x: 0.18, y: 0.36, z: -0.2, chamfer: 0.02, in: n)
            Vox.box(0.08, 0.08, 0.08, 0xff4d6d, x: -0.2, y: 0.3, z: 0.1, chamfer: 0.02, in: n)
            return n
        }
    }

    static func pumpkin() -> SCNNode {
        proto("pumpkin") {
            let n = SCNNode()
            Vox.box(0.62, 0.42, 0.58, 0xff8a1f, x: 0, y: 0, z: 0, chamfer: 0.12, in: n)
            Vox.box(0.08, 0.14, 0.08, 0x4f7a2a, x: 0, y: 0.4, z: 0, chamfer: 0.02, in: n)
            return n
        }
    }

    static func snowman() -> SCNNode {
        proto("snowman") {
            let n = SCNNode()
            Vox.box(0.6, 0.46, 0.6, 0xffffff, x: 0, y: 0, z: 0, chamfer: 0.12, in: n)
            Vox.box(0.44, 0.36, 0.44, 0xffffff, x: 0, y: 0.44, z: 0, chamfer: 0.1, in: n)
            Vox.box(0.08, 0.08, 0.2, 0xff8a1f, x: 0, y: 0.58, z: 0.28, chamfer: 0.02, in: n)
            Vox.box(0.05, 0.05, 0.03, 0x222222, x: -0.09, y: 0.66, z: 0.22, chamfer: 0, in: n)
            Vox.box(0.05, 0.05, 0.03, 0x222222, x: 0.09, y: 0.66, z: 0.22, chamfer: 0, in: n)
            Vox.box(0.48, 0.08, 0.48, 0xe63946, x: 0, y: 0.42, z: 0, chamfer: 0.02, in: n)
            return n
        }
    }

    static func palm() -> SCNNode {
        proto("palm") {
            let n = SCNNode()
            for i in 0..<5 {
                Vox.box(0.2, 0.26, 0.2, i % 2 == 0 ? 0xb07a4a : 0x9b6a3e, x: Float(i) * 0.03, y: Float(i) * 0.25, z: 0, chamfer: 0.03, in: n)
            }
            for a in 0..<5 {
                let t = Float(a) / 5 * 2 * .pi + 0.3
                let leaf = Vox.box(0.95, 0.07, 0.3, a % 2 == 0 ? 0x3fb54a : 0x2f9e3e, x: 0, y: 0, z: 0, chamfer: 0.02)
                leaf.position = SCNVector3(0.14 + cos(t) * 0.4, 1.26 - 0.08, -sin(t) * 0.4)
                leaf.eulerAngles = SCNVector3(0, t, -0.3)
                n.addChildNode(leaf)
            }
            Vox.box(0.36, 0.14, 0.36, 0x46c052, x: 0.14, y: 1.2, z: 0, chamfer: 0.05, in: n)
            Vox.box(0.14, 0.14, 0.14, 0x7a4f2a, x: 0.2, y: 1.06, z: 0.08, chamfer: 0.04, in: n)
            return n
        }
    }

    static func parasol(_ c: UInt32) -> SCNNode {
        proto("parasol-\(c)") {
            let n = SCNNode()
            Vox.box(0.06, 0.9, 0.06, 0xf4f4f4, x: 0, y: 0, z: 0, chamfer: 0, in: n)
            Vox.box(0.7, 0.1, 0.7, c, x: 0, y: 0.86, z: 0, chamfer: 0.04, in: n)
            Vox.box(0.36, 0.1, 0.36, 0xffffff, x: 0, y: 0.93, z: 0, chamfer: 0.04, in: n)
            Vox.box(0.7, 0.06, 0.34, 0x3db8ff, x: 0, y: 0, z: 0.22, chamfer: 0.02, in: n)
            return n
        }
    }

    static func cactus(arms: Bool) -> SCNNode {
        proto("cactus-\(arms)") {
            let n = SCNNode()
            Vox.box(0.3, 1.0, 0.3, 0x4fa65a, x: 0, y: 0, z: 0, chamfer: 0.06, in: n)
            if arms {
                Vox.box(0.24, 0.16, 0.18, 0x4fa65a, x: -0.24, y: 0.4, z: 0, chamfer: 0.04, in: n)
                Vox.box(0.16, 0.36, 0.18, 0x4fa65a, x: -0.32, y: 0.48, z: 0, chamfer: 0.05, in: n)
                Vox.box(0.24, 0.16, 0.18, 0x4fa65a, x: 0.24, y: 0.55, z: 0, chamfer: 0.04, in: n)
                Vox.box(0.16, 0.3, 0.18, 0x4fa65a, x: 0.32, y: 0.62, z: 0, chamfer: 0.05, in: n)
            }
            Vox.box(0.1, 0.1, 0.1, 0xff6fa3, x: 0, y: 1.0, z: 0, chamfer: 0.03, in: n)
            return n
        }
    }

    static func mesa() -> SCNNode {
        proto("mesa") {
            let n = SCNNode()
            Vox.box(0.8, 0.5, 0.74, 0xc9734a, x: 0, y: 0, z: 0, chamfer: 0.05, in: n)
            Vox.box(0.62, 0.4, 0.58, 0xdb8a5c, x: 0.04, y: 0.48, z: 0, chamfer: 0.05, in: n)
            Vox.box(0.66, 0.06, 0.62, 0xb8623e, x: 0.04, y: 0.86, z: 0, chamfer: 0.02, in: n)
            return n
        }
    }

    static func streetTree() -> SCNNode {
        proto("streettree") {
            let n = SCNNode()
            Vox.box(0.7, 0.14, 0.7, 0x9aa0ae, x: 0, y: 0, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.14, 0.4, 0.14, 0x6b4a35, x: 0, y: 0.12, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.56, 0.5, 0.56, 0x3d9e6b, x: 0, y: 0.48, z: 0, chamfer: 0.1, in: n)
            return n
        }
    }

    static func building(_ v: Int) -> SCNNode {
        let colors: [UInt32] = [0x5b5f97, 0x3f4a7a, 0x8a4f8f, 0x2f6f8f, 0x6a5acd, 0x47506b]
        let glows: [UInt32] = [0xffe08a, 0x7ff6ff, 0xff8ad8]
        let floors = 2 + v % 4
        let c = colors[v % colors.count], g = glows[v % glows.count]
        return proto("bld-\(v % 12)") {
            let n = SCNNode()
            let h = Float(floors) * 0.42 + 0.2
            Vox.box(0.86, CGFloat(h), 0.86, c, x: 0, y: 0, z: 0, chamfer: 0.03, in: n)
            Vox.box(0.9, 0.08, 0.9, shade(c, -0.25), x: 0, y: h, z: 0, chamfer: 0.02, in: n)
            for f in 0..<floors {
                let y = 0.22 + Float(f) * 0.42
                for side in [-1, 1] as [Float] {
                    for k in [-0.2, 0.2] as [Float] {
                        let lit = (f + Int(k * 10) + v) % 3 != 0
                        let col = lit ? g : shade(c, -0.3)
                        Vox.box(0.16, 0.18, 0.02, col, x: k, y: y, z: side * 0.44, chamfer: 0, glow: lit, in: n)
                        Vox.box(0.02, 0.18, 0.16, col, x: side * 0.44, y: y, z: k, chamfer: 0, glow: lit, in: n)
                    }
                }
            }
            return n
        }
    }

    static func decoration(biome: Int, variant: Int) -> SCNNode {
        switch biome {
        case 0: return [flower(0xff5d8a), flower(0xffd23c), flower(0xffffff), tuft(0x7fc94e)][variant % 4]
        case 1: return [mushroom(), leafPile(0xe5482f), leafPile(0xffc02e), tuft(0xcf9a3f)][variant % 4]
        case 2: return [tuft(0xd6e2f0), pebble(0xc5d2e2), tuft(0xe3ecf6), pebble(0xb7c6d8)][variant % 4]
        case 3: return [shell(0xffb3c7), pebble(0xe2cf9d), shell(0xfff1e0), tuft(0x9bc95a)][variant % 4]
        case 4: return [pebble(0xc98a5a), tuft(0xc2a15a), pebble(0xb36f45), skull()][variant % 4]
        default: return [hydrant(), pebble(0x6c7183), cone(), tuft(0x5b9e7a)][variant % 4]
        }
    }

    static func flower(_ c: UInt32) -> SCNNode {
        proto("flower-\(c)") {
            let n = SCNNode()
            Vox.box(0.04, 0.16, 0.04, 0x3f8f3a, x: 0, y: 0, z: 0, chamfer: 0, in: n)
            Vox.box(0.14, 0.08, 0.14, c, x: 0, y: 0.15, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.06, 0.06, 0.06, 0xffc21a, x: 0, y: 0.19, z: 0, chamfer: 0.01, in: n)
            return n
        }
    }

    static func tuft(_ c: UInt32) -> SCNNode {
        proto("tuft-\(c)") {
            let n = SCNNode()
            Vox.box(0.06, 0.14, 0.06, c, x: -0.06, y: 0, z: 0, chamfer: 0, in: n)
            Vox.box(0.06, 0.2, 0.06, c, x: 0.02, y: 0, z: 0.03, chamfer: 0, in: n)
            Vox.box(0.06, 0.12, 0.06, c, x: 0.08, y: 0, z: -0.03, chamfer: 0, in: n)
            return n
        }
    }

    static func pebble(_ c: UInt32) -> SCNNode {
        proto("pebble-\(c)") { Vox.box(0.2, 0.08, 0.16, c, chamfer: 0.03) }
    }

    static func mushroom() -> SCNNode {
        proto("mushroom") {
            let n = SCNNode()
            Vox.box(0.08, 0.12, 0.08, 0xf5ead6, x: 0, y: 0, z: 0, chamfer: 0.01, in: n)
            Vox.box(0.22, 0.1, 0.22, 0xe63946, x: 0, y: 0.11, z: 0, chamfer: 0.04, in: n)
            Vox.box(0.05, 0.02, 0.05, 0xffffff, x: 0.05, y: 0.21, z: 0.03, chamfer: 0, in: n)
            return n
        }
    }

    static func leafPile(_ c: UInt32) -> SCNNode {
        proto("leaf-\(c)") { Vox.box(0.3, 0.06, 0.24, c, chamfer: 0.02) }
    }

    static func shell(_ c: UInt32) -> SCNNode {
        proto("shell-\(c)") { Vox.box(0.16, 0.07, 0.14, c, chamfer: 0.04) }
    }

    static func skull() -> SCNNode {
        proto("cowskull") {
            let n = SCNNode()
            Vox.box(0.2, 0.1, 0.24, 0xf3ead8, x: 0, y: 0, z: 0, chamfer: 0.03, in: n)
            Vox.box(0.4, 0.05, 0.05, 0xf3ead8, x: 0, y: 0.06, z: -0.08, chamfer: 0.01, in: n)
            return n
        }
    }

    static func hydrant() -> SCNNode {
        proto("hydrant") {
            let n = SCNNode()
            Vox.box(0.16, 0.3, 0.16, 0xe63946, x: 0, y: 0, z: 0, chamfer: 0.03, in: n)
            Vox.box(0.26, 0.06, 0.08, 0xe63946, x: 0, y: 0.16, z: 0, chamfer: 0.02, in: n)
            return n
        }
    }

    static func cone() -> SCNNode {
        proto("cone") {
            let n = SCNNode()
            Vox.box(0.26, 0.04, 0.26, 0xff7a1a, x: 0, y: 0, z: 0, chamfer: 0.01, in: n)
            Vox.box(0.14, 0.18, 0.14, 0xff7a1a, x: 0, y: 0.04, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.15, 0.05, 0.15, 0xffffff, x: 0, y: 0.1, z: 0, chamfer: 0.01, in: n)
            return n
        }
    }

    // MARK: - Vehicles (front faces +x)

    static func car(_ color: UInt32, kind: Int, night: Bool) -> SCNNode {
        proto("car-\(color)-\(kind)-\(night)") {
            let n = SCNNode()
            let L: CGFloat = 1.3
            for (x, z) in [(-0.38, -0.36), (0.38, -0.36), (-0.38, 0.36), (0.38, 0.36)] {
                Vox.box(0.28, 0.26, 0.12, 0x1d1e24, x: Float(x), y: 0, z: Float(z), chamfer: 0.04, in: n)
            }
            Vox.box(L, 0.34, 0.78, color, x: 0, y: 0.1, z: 0, chamfer: 0.06, in: n)
            Vox.box(0.74, 0.26, 0.7, 0x2c3a52, x: -0.06, y: 0.42, z: 0, chamfer: 0.04, in: n)
            Vox.box(0.66, 0.07, 0.72, kind == 2 ? 0xffffff : shade(color, 0.12), x: -0.08, y: 0.66, z: 0, chamfer: 0.03, in: n)
            // lights
            for z in [-0.26, 0.26] as [Float] {
                Vox.box(0.04, 0.08, 0.14, 0xfff6c8, x: Float(L) / 2, y: 0.26, z: z, chamfer: 0, glow: true, in: n)
                Vox.box(0.04, 0.08, 0.12, 0xff3040, x: -Float(L) / 2, y: 0.26, z: z, chamfer: 0, glow: true, in: n)
            }
            if kind == 1 { // taxi sign
                Vox.box(0.26, 0.1, 0.34, 0xfff2a8, x: -0.08, y: 0.72, z: 0, chamfer: 0.02, glow: night, in: n)
                Vox.box(L + 0.01, 0.06, 0.79, 0x222222, x: 0, y: 0.25, z: 0, chamfer: 0, in: n)
            } else if kind == 2 { // police
                Vox.box(0.14, 0.08, 0.2, 0xff2a3a, x: -0.08, y: 0.72, z: -0.12, chamfer: 0.02, glow: true, in: n)
                Vox.box(0.14, 0.08, 0.2, 0x2a6bff, x: -0.08, y: 0.72, z: 0.12, chamfer: 0.02, glow: true, in: n)
                Vox.box(L * 0.5, 0.18, 0.79, 0x1f2a5a, x: 0, y: 0.18, z: 0, chamfer: 0.03, in: n)
            }
            if night {
                Vox.box(1.2, 0.02, 0.7, 0xfff3b0, x: Float(L) / 2 + 0.6, y: 0.0, z: 0, chamfer: 0, glow: true, alpha: 0.18, in: n)
            }
            return n
        }
    }

    static func truck(_ color: UInt32, night: Bool) -> SCNNode {
        proto("truck-\(color)-\(night)") {
            let n = SCNNode()
            for x in [-0.85, -0.25, 0.85] as [Float] {
                for z in [-0.4, 0.4] as [Float] {
                    Vox.box(0.32, 0.3, 0.12, 0x1d1e24, x: x, y: 0, z: z, chamfer: 0.04, in: n)
                }
            }
            Vox.box(0.8, 0.7, 0.86, color, x: 0.82, y: 0.14, z: 0, chamfer: 0.06, in: n)
            Vox.box(0.06, 0.28, 0.74, 0x2c3a52, x: 1.22, y: 0.5, z: 0, chamfer: 0.02, in: n)
            Vox.box(1.7, 0.86, 0.9, 0xf2f2f2, x: -0.42, y: 0.14, z: 0, chamfer: 0.05, in: n)
            Vox.box(1.72, 0.12, 0.92, shade(color, -0.1), x: -0.42, y: 0.5, z: 0, chamfer: 0.02, in: n)
            for z in [-0.3, 0.3] as [Float] {
                Vox.box(0.04, 0.1, 0.14, 0xfff6c8, x: 1.23, y: 0.24, z: z, chamfer: 0, glow: true, in: n)
            }
            if night {
                Vox.box(1.4, 0.02, 0.76, 0xfff3b0, x: 1.95, y: 0.0, z: 0, chamfer: 0, glow: true, alpha: 0.18, in: n)
            }
            return n
        }
    }

    // MARK: - River platforms (long side along x, top at y = -0.05)

    static func log(length: Int) -> SCNNode {
        proto("log-\(length)") {
            let n = SCNNode()
            let L = CGFloat(length) - 0.1
            Vox.box(L, 0.32, 0.7, 0x9a6339, x: 0, y: -0.37, z: 0, chamfer: 0.08, in: n)
            Vox.box(0.06, 0.26, 0.6, 0xd9a46c, x: -Float(L) / 2 - 0.01, y: -0.34, z: 0, chamfer: 0.04, in: n)
            Vox.box(0.06, 0.26, 0.6, 0xd9a46c, x: Float(L) / 2 + 0.01, y: -0.34, z: 0, chamfer: 0.04, in: n)
            var x = -Float(L) / 2 + 0.4
            while x < Float(L) / 2 - 0.2 {
                Vox.box(0.08, 0.02, 0.5, 0x7d4d2a, x: x, y: -0.06, z: rnd(-0.08, 0.08), chamfer: 0, in: n)
                x += 0.55
            }
            return n
        }
    }

    static func iceFloe(length: Int) -> SCNNode {
        proto("ice-\(length)") {
            let n = SCNNode()
            let L = CGFloat(length) - 0.12
            Vox.box(L, 0.26, 0.84, 0xe8f6ff, x: 0, y: -0.31, z: 0, chamfer: 0.06, in: n)
            Vox.box(L - 0.2, 0.02, 0.6, 0xffffff, x: 0, y: -0.06, z: 0, chamfer: 0.0, in: n)
            return n
        }
    }

    static func boat(length: Int, color: UInt32) -> SCNNode {
        proto("boat-\(length)-\(color)") {
            let n = SCNNode()
            let L = CGFloat(length) - 0.1
            Vox.box(L, 0.3, 0.84, 0xffffff, x: 0, y: -0.38, z: 0, chamfer: 0.08, in: n)
            Vox.box(L + 0.01, 0.08, 0.85, color, x: 0, y: -0.28, z: 0, chamfer: 0.02, in: n)
            Vox.box(L - 0.2, 0.03, 0.66, 0xc8915a, x: 0, y: -0.09, z: 0, chamfer: 0, in: n)
            Vox.box(0.24, 0.16, 0.24, color, x: Float(L) / 2 - 0.2, y: -0.08, z: 0, chamfer: 0.04, in: n)
            return n
        }
    }

    static func lilyPad(flower: Bool) -> SCNNode {
        proto("lily-\(flower)") {
            let n = SCNNode()
            Vox.box(0.82, 0.06, 0.82, 0x3fae4f, x: 0, y: -0.3, z: 0, chamfer: 0.12, in: n)
            Vox.box(0.2, 0.065, 0.06, 0x2d8f3d, x: 0.25, y: -0.3, z: 0.1, chamfer: 0, in: n)
            if flower {
                Vox.box(0.16, 0.1, 0.16, 0xff8ab8, x: -0.22, y: -0.25, z: -0.2, chamfer: 0.04, in: n)
                Vox.box(0.06, 0.06, 0.06, 0xffe14d, x: -0.22, y: -0.17, z: -0.2, chamfer: 0.01, in: n)
            }
            return n
        }
    }

    // MARK: - Trains (front faces +x)

    static func locomotive(_ color: UInt32) -> SCNNode {
        proto("loco-\(color)") {
            let n = SCNNode()
            Vox.box(3.0, 0.24, 0.9, 0x2a2b31, x: 0, y: 0.04, z: 0, chamfer: 0.03, in: n)
            Vox.box(2.2, 0.62, 0.84, color, x: 0.3, y: 0.26, z: 0, chamfer: 0.08, in: n)
            Vox.box(0.9, 1.0, 0.9, shade(color, -0.12), x: -0.9, y: 0.26, z: 0, chamfer: 0.06, in: n)
            Vox.box(0.06, 0.3, 0.7, 0x2c3a52, x: -0.45, y: 0.86, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.22, 0.34, 0.22, 0x2a2b31, x: 0.9, y: 0.86, z: 0, chamfer: 0.03, in: n)
            Vox.box(0.06, 0.16, 0.86, 0xffd23c, x: 1.42, y: 0.3, z: 0, chamfer: 0.02, in: n)
            Vox.box(0.05, 0.14, 0.2, 0xfff6c8, x: 1.44, y: 0.62, z: 0, chamfer: 0.01, glow: true, in: n)
            return n
        }
    }

    static func wagon(_ color: UInt32) -> SCNNode {
        proto("wagon-\(color)") {
            let n = SCNNode()
            Vox.box(2.5, 0.2, 0.86, 0x2a2b31, x: 0, y: 0.04, z: 0, chamfer: 0.03, in: n)
            Vox.box(2.4, 0.8, 0.86, color, x: 0, y: 0.22, z: 0, chamfer: 0.05, in: n)
            for x in [-0.8, -0.4, 0, 0.4, 0.8] as [Float] {
                Vox.box(0.05, 0.7, 0.88, shade(color, -0.15), x: x, y: 0.27, z: 0, chamfer: 0, in: n)
            }
            return n
        }
    }

    // MARK: - Collectibles & creatures

    static func coin() -> SCNNode {
        proto("coin", flatten: false) {
            let holder = SCNNode()
            let spin = SCNNode(); spin.name = "spin"
            holder.addChildNode(spin)
            let a = Vox.cylinder(r: 0.24, h: 0.07, 0xffbe1f)
            a.position = SCNVector3(0, 0, 0); a.eulerAngles.x = .pi / 2
            let b = Vox.cylinder(r: 0.15, h: 0.09, 0xffe27a)
            b.position = SCNVector3(0, 0, 0); b.eulerAngles.x = .pi / 2
            spin.addChildNode(a); spin.addChildNode(b)
            spin.position.y = 0.38
            return holder
        }
    }

    static func eagle() -> SCNNode {
        let root = SCNNode()
        let n = SCNNode()
        n.eulerAngles.y = .pi   // modelled facing -z, but it flies toward +z
        root.addChildNode(n)
        Vox.box(0.6, 0.42, 1.2, 0x6b4a2f, x: 0, y: 0, z: 0, chamfer: 0.08, in: n)
        Vox.box(0.46, 0.42, 0.46, 0xffffff, x: 0, y: 0.12, z: -0.7, chamfer: 0.08, in: n)
        Vox.box(0.18, 0.14, 0.24, 0xffc21a, x: 0, y: 0.16, z: -1.0, chamfer: 0.03, in: n)
        Vox.box(0.06, 0.08, 0.08, 0x111111, x: -0.235, y: 0.38, z: -0.78, chamfer: 0, in: n)
        Vox.box(0.06, 0.08, 0.08, 0x111111, x: 0.235, y: 0.38, z: -0.78, chamfer: 0, in: n)
        Vox.box(0.5, 0.1, 0.4, 0x5a3d26, x: 0, y: 0.12, z: 0.75, chamfer: 0.03, in: n)
        for s in [-1, 1] as [Float] {
            let pivot = SCNNode(); pivot.name = s < 0 ? "wingL" : "wingR"
            pivot.position = SCNVector3(s * 0.3, 0.3, 0)
            Vox.box(1.5, 0.08, 0.7, 0x7a5636, x: s * 0.75, y: -0.04, z: 0, chamfer: 0.03, in: pivot)
            Vox.box(0.5, 0.09, 0.5, 0x4f3520, x: s * 1.35, y: -0.045, z: 0.05, chamfer: 0.03, in: pivot)
            n.addChildNode(pivot)
        }
        for s in [-0.15, 0.15] as [Float] {
            Vox.box(0.08, 0.2, 0.08, 0xffc21a, x: s, y: -0.2, z: 0.1, chamfer: 0.01, in: n)
        }
        return root
    }
}
