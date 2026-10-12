import SceneKit

enum LaneKind { case grass, road, river, rail, forest }

final class Mover {
    let node: SCNNode
    var x: Float
    let len: Float
    init(node: SCNNode, x: Float, len: Float) {
        self.node = node; self.x = x; self.len = len
    }
}

enum TrainState { case idle, warning, passing }

final class Lane {
    let index: Int
    let kind: LaneKind
    let biome: Int
    let node = SCNNode()
    var blocked = Set<Int>()
    var obstacles: [Int: SCNNode] = [:]
    var coins: [Int: SCNNode] = [:]
    var movers: [Mover] = []
    var velocity: Float = 0
    var pads: [Int: SCNNode] = [:]
    var lily = false
    var riverStyle: RiverStyle = .logs

    // rail
    var signal: SCNMaterial?
    var trainState: TrainState = .idle
    var trainTimer: Float = 0
    var train: SCNNode?
    var trainX: Float = 0
    var trainLen: Float = 0
    var blink: Float = 0

    init(index: Int, kind: LaneKind, biome: Int) {
        self.index = index; self.kind = kind; self.biome = biome
        node.position = SCNVector3(0, 0, -Float(index))
    }

    var groundTop: Float {
        switch kind {
        case .grass, .forest: return 0
        case .road: return -0.06
        case .rail: return -0.04
        case .river: return -0.28
        }
    }

    /// The platform under world-x `x`, if any (logs, boats, ice, lily pads).
    func platform(at x: Float) -> Mover? {
        for m in movers where abs(x - m.x) <= m.len / 2 + 0.12 { return m }
        return nil
    }
}

/// Generates lanes in order. Keeps a guaranteed free "path" column through every grass lane
/// so a run can never become impossible.
final class WorldGen {
    static let half = 4            // playable columns: -4...4
    static let wrap: Float = 18    // movers loop in [-wrap, wrap)

    private(set) var kinds: [Int: LaneKind] = [:]
    private var planned = 0
    private var pathCol = 0
    private var lastRoadDir: Float = 1
    private var lastRiverDir: Float = -1

    func reset() {
        kinds = [:]
        planned = -30
        pathCol = 0
        lastRoadDir = Bool.random() ? 1 : -1
        lastRiverDir = -lastRoadDir
    }

    static func difficulty(_ i: Int) -> Float { min(1, max(0, Float(i) / 180)) }

    func kind(_ i: Int) -> LaneKind {
        while planned <= i + 1 { planChunk() }
        return kinds[i] ?? .grass
    }

    private func planChunk() {
        let i = planned
        if i < 0 { kinds[i] = .forest; planned += 1; return }
        if i <= 2 { kinds[i] = .grass; planned += 1; return }

        let d = Self.difficulty(i)
        // the first lanes of a new zone are always grass, to make room for the banner
        let zonePos = i % Biomes.zoneLength
        if zonePos == 0 || zonePos == 1 { kinds[i] = .grass; planned += 1; return }

        var out: [LaneKind] = []
        let r = Float.random(in: 0..<1)
        let railOK = i > 14
        if r < 0.48 {
            out = Array(repeating: .road, count: Int.random(in: 1...(d > 0.4 ? 5 : 3)))
        } else if r < 0.8 {
            out = Array(repeating: .river, count: Int.random(in: 1...(d > 0.3 ? 3 : 2)))
        } else if railOK {
            out = Array(repeating: .rail, count: Int.random(in: 1...(d > 0.5 ? 2 : 1)))
        } else {
            out = [.road, .road]
        }
        let grass = d > 0.6 ? Int.random(in: 1...2) : Int.random(in: 1...3)
        out += Array(repeating: .grass, count: grass)
        for k in out {
            kinds[planned] = k
            planned += 1
            // don't let a chunk run over a zone boundary
            if planned % Biomes.zoneLength == 0 { break }
        }
    }

    func build(_ i: Int) -> Lane {
        let k = kind(i)
        let biome = Biomes.index(forLane: i)
        let lane = Lane(index: i, kind: k, biome: biome)
        let b = Biomes.all[biome]
        let d = Self.difficulty(i)
        let shadeA = (i & 1) == 0 ? b.grass.0 : b.grass.1

        switch k {
        case .forest:
            lane.node.addChildNode(Models.ground(top: 0, color: shadeA))
            for c in -11...11 {
                lane.blocked.insert(c)
                if chance(0.85) || abs(c) <= Self.half { addObstacle(lane, col: c, biome: biome, keep: abs(c) <= Self.half) }
            }

        case .grass:
            lane.node.addChildNode(Models.ground(top: 0, color: shadeA))
            if i <= 0 {
                // the start: open around the chicken
                for c in -Self.half...Self.half where abs(c) >= 3 && chance(0.5) {
                    addObstacle(lane, col: c, biome: biome, keep: true)
                }
            } else {
                let newPath = max(-Self.half + 1, min(Self.half - 1, pathCol + Int.random(in: -2...2)))
                let free = min(pathCol, newPath)...max(pathCol, newPath)
                pathCol = newPath
                let density: Float = 0.16 + d * 0.12
                for c in -Self.half...Self.half where !free.contains(c) && chance(density) {
                    addObstacle(lane, col: c, biome: biome, keep: true)
                }
                if chance(0.22) {
                    let opts = (-Self.half...Self.half).filter { !lane.blocked.contains($0) }
                    if let c = opts.randomElement() { addCoin(lane, col: c) }
                }
            }
            // sides: dense, non-playable scenery
            for c in (-12)...(-Self.half - 1) where chance(0.5) { addObstacle(lane, col: c, biome: biome, keep: false) }
            for c in (Self.half + 1)...12 where chance(0.5) { addObstacle(lane, col: c, biome: biome, keep: false) }
            for _ in 0..<Int.random(in: 1...4) {
                let deco = Models.decoration(biome: biome, variant: Int.random(in: 0..<4))
                deco.position = SCNVector3(rnd(-11, 11), 0, rnd(-0.35, 0.35))
                deco.eulerAngles.y = rnd(0, 6.28)
                lane.node.addChildNode(deco)
            }

        case .road:
            lane.node.addChildNode(Models.ground(top: -0.06, color: b.road, sideDarken: 0.1))
            if kind(i + 1) == .road { lane.node.addChildNode(Models.roadLines()) }
            if kind(i - 1) != .road { lane.node.addChildNode(Models.roadCurb()) }
            let dir: Float = chance(0.7) ? -lastRoadDir : lastRoadDir
            lastRoadDir = dir
            let speed = rnd(1.3, 2.2) + d * rnd(0.8, 2.6)
            lane.velocity = dir * speed
            var x = -Self.wrap + rnd(0, 4)
            while x < Self.wrap - 2 {
                let truck = chance(0.22)
                let len: Float = truck ? 2.5 : 1.3
                let color = b.carColors.randomElement()!
                let n: SCNNode
                if truck {
                    n = Models.truck(color, night: b.night)
                } else {
                    let kind = b.night ? (chance(0.35) ? 1 : (chance(0.15) ? 2 : 0)) : (chance(0.1) ? 1 : (chance(0.08) ? 2 : 0))
                    n = Models.car(kind == 1 ? 0xffc93c : (kind == 2 ? 0xf4f4f4 : color), kind: kind, night: b.night)
                }
                if dir < 0 { n.eulerAngles.y = .pi }
                let m = Mover(node: n, x: x + len / 2, len: len)
                n.position = SCNVector3(m.x, -0.06, 0)
                lane.node.addChildNode(n)
                lane.movers.append(m)
                x += len + max(2.6, rnd(3.2, 8.0) - d * 1.6)
            }
            if chance(0.12) { addCoin(lane, col: Int.random(in: -Self.half...Self.half), y: -0.06) }

        case .river:
            lane.node.addChildNode(Models.ground(top: -0.28, depth: 0.4, color: b.water, sideDarken: 0.08))
            if kind(i - 1) != .river { lane.node.addChildNode(Models.foam(z: 0.47)) }
            if kind(i + 1) != .river { lane.node.addChildNode(Models.foam(z: -0.47)) }
            lane.riverStyle = b.river
            let lilyOK = b.river == .logs && i > 4 && chance(0.28)
            if lilyOK {
                lane.lily = true
                var cols = Set([pathCol])
                for _ in 0..<Int.random(in: 1...3) { cols.insert(Int.random(in: -Self.half...Self.half)) }
                for c in cols {
                    let p = Models.lilyPad(flower: chance(0.3))
                    p.position = SCNVector3(Float(c), 0, rnd(-0.05, 0.05))
                    p.eulerAngles.y = rnd(0, 6.28)
                    lane.node.addChildNode(p)
                    lane.pads[c] = p
                    lane.movers.append(Mover(node: p, x: Float(c), len: 0.8))
                }
            } else {
                let dir = -lastRiverDir
                lastRiverDir = dir
                let speed = rnd(0.9, 1.5) + d * rnd(0.3, 1.1)
                lane.velocity = dir * speed
                var x = -Self.wrap + rnd(0, 2)
                while x < Self.wrap - 1.5 {
                    let length: Int
                    let n: SCNNode
                    switch b.river {
                    case .logs:
                        length = [2, 3, 3, 4].randomElement()!
                        n = Models.log(length: length)
                    case .ice:
                        length = [2, 2, 3].randomElement()!
                        n = Models.iceFloe(length: length)
                    case .boats:
                        length = [2, 3].randomElement()!
                        n = Models.boat(length: length, color: [0xff5a4e, 0x3d8bff, 0xffc93c, 0x2fc99a].randomElement()!)
                        if dir < 0 { n.eulerAngles.y = .pi }
                    }
                    let len = Float(length)
                    let m = Mover(node: n, x: x + len / 2, len: len - 0.1)
                    n.position = SCNVector3(m.x, 0, 0)
                    lane.node.addChildNode(n)
                    lane.movers.append(m)
                    x += len + rnd(1.3, 3.0) + d * 0.9
                }
            }

        case .rail:
            lane.node.addChildNode(Models.ground(top: -0.04, color: 0x8f8579, sideDarken: 0.1))
            lane.node.addChildNode(Models.rails())
            let s = Models.signal()
            s.node.position = SCNVector3(-4.95, -0.04, 0.38)
            lane.node.addChildNode(s.node)
            lane.signal = s.light
            lane.velocity = chance(0.5) ? 1 : -1
            lane.trainTimer = rnd(1.5, 4.5)
        }
        return lane
    }

    private func addObstacle(_ lane: Lane, col: Int, biome: Int, keep: Bool) {
        let n = Models.obstacle(biome: biome, variant: Int.random(in: 0..<16))
        n.position = SCNVector3(Float(col) + (keep ? 0 : rnd(-0.15, 0.15)), 0, keep ? 0 : rnd(-0.12, 0.12))
        n.eulerAngles.y = Float(Int.random(in: 0..<4)) * .pi / 2
        let s = rnd(0.9, 1.08)
        n.scale = SCNVector3(s, s, s)
        lane.node.addChildNode(n)
        if abs(col) <= Self.half {
            lane.blocked.insert(col)
            lane.obstacles[col] = n
        }
    }

    private func addCoin(_ lane: Lane, col: Int, y: Float = 0) {
        let c = Models.coin()
        c.position = SCNVector3(Float(col), y, 0)
        if let spin = c.childNode(withName: "spin", recursively: false) {
            spin.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.6)))
            spin.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.08, z: 0, duration: 0.6), .moveBy(x: 0, y: -0.08, z: 0, duration: 0.6)])))
        }
        lane.node.addChildNode(c)
        lane.coins[col] = c
    }
}
