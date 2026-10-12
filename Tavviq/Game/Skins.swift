import SceneKit

enum Rarity: String {
    case common = "Sıradan", rare = "Nadir", epic = "Destansı", legend = "Efsane"

    var color: UInt32 {
        switch self {
        case .common: return 0x7cc25b
        case .rare: return 0x46a8ff
        case .epic: return 0xb66cff
        case .legend: return 0xffb21e
        }
    }
}

enum Accessory {
    case none, roosterTail, cowboy, ninja, pirate, astronaut, crown, beanie, robot, chef, sunglasses, party
}

struct Skin: Identifiable, Hashable {
    let id: String
    let name: String
    let line: String
    let price: Int
    let rarity: Rarity
    var body: UInt32 = 0xfdfbf5
    var wing: UInt32 = 0xece6da
    var comb: UInt32 = 0xff4b3e
    var beak: UInt32 = 0xffa928
    var legs: UInt32 = 0xff9a1f
    var scale: Float = 1
    var accessory: Accessory = .none

    static func == (a: Skin, b: Skin) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum Skins {
    static let all: [Skin] = [
        Skin(id: "tavviq", name: "Tavviq", line: "Kümesin yıldızı. Yolun da.", price: 0, rarity: .common),
        Skin(id: "civciv", name: "Civciv", line: "Minik ama cesur.", price: 100, rarity: .common,
             body: 0xffe14d, wing: 0xffcf2e, comb: 0xffb02e, scale: 0.82),
        Skin(id: "kara", name: "Kara Tavuk", line: "Gecenin gölgesi.", price: 150, rarity: .common,
             body: 0x3a3440, wing: 0x2a2530, comb: 0xff3d5a),
        Skin(id: "horoz", name: "Horoz Rıza", line: "Sabah 5'te uyandırır.", price: 200, rarity: .rare,
             body: 0xc8562b, wing: 0x9c3b1c, comb: 0xff2a2a, accessory: .roosterTail),
        Skin(id: "parti", name: "Parti Tavuk", line: "Her gün doğum günü.", price: 250, rarity: .rare,
             body: 0xffc4dd, wing: 0xff9cc6, accessory: .party),
        Skin(id: "kovboy", name: "Kovboy", line: "Bu kasabaya iki tavuk fazla.", price: 300, rarity: .rare,
             body: 0xf3e3c3, wing: 0xdcc59d, accessory: .cowboy),
        Skin(id: "havali", name: "Havalı", line: "Güneş gözlüğü gece de takılır.", price: 300, rarity: .rare,
             body: 0x7ad3ff, wing: 0x52b9ef, accessory: .sunglasses),
        Skin(id: "ninja", name: "Ninja Tavuk", line: "Sessiz. Görünmez. Gıdak.", price: 400, rarity: .epic,
             body: 0x2c2f3a, wing: 0x1e2029, comb: 0xff3d3d, accessory: .ninja),
        Skin(id: "korsan", name: "Korsan", line: "Yo ho ho ve bir avuç mısır.", price: 400, rarity: .epic,
             body: 0xf7f3ea, wing: 0xe0d9c9, accessory: .pirate),
        Skin(id: "asci", name: "Şef Tavuk", line: "Menüde tavuk yok.", price: 450, rarity: .epic,
             body: 0xfffaf0, wing: 0xefe7d6, accessory: .chef),
        Skin(id: "kardan", name: "Kardan Tavuk", line: "Bere şart, atkı şart.", price: 450, rarity: .epic,
             body: 0xf4f8ff, wing: 0xdbe6f5, accessory: .beanie),
        Skin(id: "robot", name: "Robo-Gıdak", line: "Bip bop gıdak.", price: 600, rarity: .epic,
             body: 0xb8c3cf, wing: 0x8e9aa8, comb: 0x3cf0ff, beak: 0xffd23c, legs: 0x5d6875, accessory: .robot),
        Skin(id: "astronot", name: "Astronot", line: "Bir tavuk için küçük bir zıplama.", price: 750, rarity: .legend,
             body: 0xffffff, wing: 0xe6e9f0, accessory: .astronaut),
        Skin(id: "kral", name: "Kral Tavuk", line: "Taç takmak kolay değil.", price: 1000, rarity: .legend,
             body: 0xffd84a, wing: 0xf2bb24, comb: 0xff3d3d, accessory: .crown),
    ]

    static func skin(_ id: String) -> Skin { all.first { $0.id == id } ?? all[0] }
}

/// Builds the voxel chicken. The root sits at the feet, facing -z.
/// Child names: "body" (squash target), "wingL", "wingR".
enum ChickenModel {
    static func make(_ s: Skin) -> SCNNode {
        let root = SCNNode()
        let body = SCNNode()
        body.name = "body"
        root.addChildNode(body)

        let ink: UInt32 = 0x2a1c16
        // legs
        Vox.box(0.07, 0.16, 0.07, s.legs, x: -0.11, y: 0, z: 0.02, chamfer: 0.01, in: body)
        Vox.box(0.07, 0.16, 0.07, s.legs, x: 0.11, y: 0, z: 0.02, chamfer: 0.01, in: body)
        Vox.box(0.13, 0.03, 0.16, s.legs, x: -0.11, y: 0, z: -0.02, chamfer: 0.01, in: body)
        Vox.box(0.13, 0.03, 0.16, s.legs, x: 0.11, y: 0, z: -0.02, chamfer: 0.01, in: body)
        // torso
        Vox.box(0.56, 0.42, 0.56, s.body, x: 0, y: 0.15, z: 0.04, chamfer: 0.06, in: body)
        // head / neck block
        Vox.box(0.42, 0.36, 0.38, s.body, x: 0, y: 0.5, z: -0.06, chamfer: 0.06, in: body)
        // tail
        Vox.box(0.3, 0.22, 0.14, s.wing, x: 0, y: 0.42, z: 0.36, chamfer: 0.04, in: body)
        // wings
        let wl = Vox.box(0.08, 0.24, 0.36, s.wing, x: -0.31, y: 0.24, z: 0.06, chamfer: 0.03, in: body)
        wl.name = "wingL"
        let wr = Vox.box(0.08, 0.24, 0.36, s.wing, x: 0.31, y: 0.24, z: 0.06, chamfer: 0.03, in: body)
        wr.name = "wingR"
        // comb
        Vox.box(0.1, 0.12, 0.26, s.comb, x: 0, y: 0.86, z: -0.08, chamfer: 0.03, in: body)
        Vox.box(0.1, 0.07, 0.1, s.comb, x: 0, y: 0.95, z: -0.14, chamfer: 0.02, in: body)
        // beak + wattle
        Vox.box(0.16, 0.1, 0.14, s.beak, x: 0, y: 0.6, z: -0.3, chamfer: 0.02, in: body)
        Vox.box(0.08, 0.12, 0.07, s.comb, x: 0, y: 0.48, z: -0.27, chamfer: 0.02, in: body)
        // eyes
        Vox.box(0.04, 0.08, 0.08, ink, x: -0.215, y: 0.66, z: -0.12, chamfer: 0.01, in: body)
        Vox.box(0.04, 0.08, 0.08, ink, x: 0.215, y: 0.66, z: -0.12, chamfer: 0.01, in: body)

        addAccessory(s, to: body)
        root.scale = SCNVector3(s.scale, s.scale, s.scale)
        return root
    }

    private static func addAccessory(_ s: Skin, to b: SCNNode) {
        switch s.accessory {
        case .none: break
        case .roosterTail:
            Vox.box(0.12, 0.34, 0.12, 0x2b8c4b, x: -0.09, y: 0.46, z: 0.42, chamfer: 0.03, in: b).eulerAngles.x = -0.5
            Vox.box(0.12, 0.4, 0.12, 0x1f5fbf, x: 0.0, y: 0.48, z: 0.44, chamfer: 0.03, in: b).eulerAngles.x = -0.35
            Vox.box(0.12, 0.34, 0.12, 0xffb21e, x: 0.09, y: 0.46, z: 0.42, chamfer: 0.03, in: b).eulerAngles.x = -0.5
            Vox.box(0.12, 0.16, 0.34, 0xff2a2a, x: 0, y: 0.86, z: -0.06, chamfer: 0.04, in: b)
        case .cowboy:
            Vox.box(0.72, 0.04, 0.66, 0x8a5a35, x: 0, y: 0.85, z: -0.06, chamfer: 0.02, in: b)
            Vox.box(0.4, 0.2, 0.36, 0x9c6a40, x: 0, y: 0.88, z: -0.06, chamfer: 0.04, in: b)
            Vox.box(0.41, 0.05, 0.37, 0x4a2e1c, x: 0, y: 0.9, z: -0.06, chamfer: 0.01, in: b)
        case .ninja:
            Vox.box(0.44, 0.08, 0.4, 0xe63946, x: 0, y: 0.72, z: -0.06, chamfer: 0.02, in: b)
            Vox.box(0.06, 0.06, 0.22, 0xe63946, x: 0.05, y: 0.7, z: 0.22, chamfer: 0.01, in: b).eulerAngles.y = 0.4
        case .pirate:
            Vox.box(0.5, 0.16, 0.44, 0x22202a, x: 0, y: 0.84, z: -0.06, chamfer: 0.03, in: b)
            Vox.box(0.56, 0.06, 0.2, 0x22202a, x: 0, y: 0.84, z: -0.08, chamfer: 0.02, in: b)
            Vox.box(0.08, 0.08, 0.02, 0xffffff, x: 0, y: 0.89, z: -0.29, chamfer: 0.01, in: b)
            Vox.box(0.05, 0.11, 0.11, 0x111111, x: 0.225, y: 0.645, z: -0.12, chamfer: 0.01, in: b)
        case .astronaut:
            Vox.box(0.58, 0.52, 0.54, 0xffffff, x: 0, y: 0.42, z: -0.06, chamfer: 0.12, alpha: 0.35, in: b)
            Vox.box(0.24, 0.3, 0.12, 0xd7dce6, x: 0, y: 0.2, z: 0.36, chamfer: 0.03, in: b)
            Vox.box(0.06, 0.06, 0.04, 0xff5c5c, glow: true, in: b).position = SCNVector3(0.07, 0.4, 0.43)
        case .crown:
            Vox.box(0.36, 0.1, 0.32, 0xffc21a, x: 0, y: 0.86, z: -0.06, chamfer: 0.02, in: b)
            for (dx, dz) in [(-0.13, -0.11), (0.13, -0.11), (-0.13, 0.0), (0.13, 0.0), (0, -0.2)] {
                Vox.box(0.07, 0.1, 0.07, 0xffc21a, x: Float(dx), y: 0.96, z: Float(dz) - 0.0, chamfer: 0.01, in: b)
            }
            Vox.box(0.07, 0.07, 0.03, 0xff3d6e, x: 0, y: 0.88, z: -0.23, chamfer: 0.01, in: b)
        case .beanie:
            Vox.box(0.44, 0.16, 0.4, 0x3f7ee8, x: 0, y: 0.8, z: -0.06, chamfer: 0.06, in: b)
            Vox.box(0.46, 0.06, 0.42, 0xffffff, x: 0, y: 0.78, z: -0.06, chamfer: 0.02, in: b)
            Vox.box(0.12, 0.12, 0.12, 0xffffff, x: 0, y: 0.95, z: -0.06, chamfer: 0.05, in: b)
            Vox.box(0.6, 0.1, 0.6, 0xe63946, x: 0, y: 0.47, z: 0.0, chamfer: 0.03, in: b)
            Vox.box(0.12, 0.26, 0.06, 0xe63946, x: 0.18, y: 0.24, z: -0.27, chamfer: 0.02, in: b)
        case .robot:
            Vox.box(0.03, 0.18, 0.03, 0x5d6875, x: 0, y: 0.98, z: 0.02, chamfer: 0.0, in: b)
            Vox.box(0.08, 0.08, 0.08, 0x3cf0ff, glow: true, in: b).position = SCNVector3(0, 1.18, 0.02)
            Vox.box(0.44, 0.04, 0.04, 0x3cf0ff, glow: true, in: b).position = SCNVector3(0, 0.66, -0.25)
        case .chef:
            Vox.box(0.36, 0.1, 0.32, 0xffffff, x: 0, y: 0.84, z: -0.06, chamfer: 0.02, in: b)
            Vox.box(0.44, 0.22, 0.4, 0xffffff, x: 0, y: 0.92, z: -0.06, chamfer: 0.1, in: b)
            Vox.box(0.2, 0.12, 0.04, 0xe63946, x: 0, y: 0.36, z: -0.25, chamfer: 0.02, in: b)
        case .sunglasses:
            Vox.box(0.46, 0.1, 0.05, 0x14151a, x: 0, y: 0.64, z: -0.26, chamfer: 0.02, in: b)
            Vox.box(0.04, 0.04, 0.3, 0x14151a, x: -0.22, y: 0.67, z: -0.12, chamfer: 0.01, in: b)
            Vox.box(0.04, 0.04, 0.3, 0x14151a, x: 0.22, y: 0.67, z: -0.12, chamfer: 0.01, in: b)
        case .party:
            let hat = Vox.box(0.24, 0.3, 0.24, 0x7b5cff, x: 0, y: 0.86, z: -0.06, chamfer: 0.1, in: b)
            hat.scale = SCNVector3(1, 1, 1)
            Vox.box(0.1, 0.1, 0.1, 0xffe14d, x: 0, y: 1.14, z: -0.06, chamfer: 0.04, in: b)
            Vox.box(0.26, 0.05, 0.26, 0xff4fa3, x: 0, y: 0.94, z: -0.06, chamfer: 0.02, in: b)
        }
    }
}
