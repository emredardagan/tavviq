import SceneKit
import Observation
import UIKit

enum Phase: Equatable { case home, playing, paused, dead }
enum Dir { case up, down, left, right }
enum DeathKind {
    case car, water, drift, train, eagle

    var title: String {
        switch self {
        case .car: return "Ezildin!"
        case .water: return "Cup!"
        case .drift: return "Akıntıya kapıldın!"
        case .train: return "Çuf çuf... çat!"
        case .eagle: return "Kartal kaptı!"
        }
    }

    var lines: [String] {
        switch self {
        case .car: return ["O araba durmayacaktı.", "Önce sağa, sonra sola bak.", "Trafik sıkışıktı, sen de sıkıştın.", "Korna çaldı ama sen dans ediyordun."]
        case .water: return ["Tavuklar yüzemez. Şimdi biliyorsun.", "Kütükler yüzer. Sen yüzmezsin.", "Nehir bu turu kazandı."]
        case .drift: return ["Kütüğe bin ama o kadar uzağa değil.", "Ekranın dışı pek güvenli değil."]
        case .train: return ["Zil çalıyordu, değil mi?", "Tren her zaman kazanır.", "17:15 treni tam vaktinde geldi."]
        case .eagle: return ["Oyalandın, kartal fark etti.", "İleri zıplamayı unutma!", "Yukarı, yukarı ve uzaklara."]
        }
    }
}

/// Owns the SceneKit scene and runs the whole game on SceneKit's render loop.
/// UI-facing values are published on the main thread.
@Observable
final class GameController: NSObject, SCNSceneRendererDelegate {
    // MARK: published to SwiftUI
    private(set) var phase: Phase = .home
    private(set) var score = 0
    private(set) var runCoins = 0
    private(set) var death: DeathKind = .car
    private(set) var deathLine = ""
    private(set) var newBest = false
    private(set) var banner: (title: String, sub: String, id: Int)?
    /// False once the run has used its one "continue".
    private(set) var canContinue = true

    /// Called on main for fun moments the mascot can react to.
    @ObservationIgnored var onEvent: ((GameEvent) -> Void)?

    enum GameEvent { case zone(Biome), newBest, died(DeathKind), coin }

    // MARK: scene
    @ObservationIgnored let scene = SCNScene()
    @ObservationIgnored private let cameraRig = SCNNode()
    @ObservationIgnored private let cameraNode = SCNNode()
    @ObservationIgnored private let sun = SCNNode()
    @ObservationIgnored private let ambient = SCNNode()
    @ObservationIgnored private let worldNode = SCNNode()
    @ObservationIgnored private let fx = SCNNode()

    // MARK: game state (render thread only)
    @ObservationIgnored private let gen = WorldGen()
    @ObservationIgnored private var lanes: [Int: Lane] = [:]
    @ObservationIgnored private var minLane = 0
    @ObservationIgnored private var maxLane = 0
    @ObservationIgnored private var player = SCNNode()
    @ObservationIgnored private var playerBody: SCNNode?
    @ObservationIgnored private var skin = GameStore.shared.skin

    @ObservationIgnored private var state: Phase = .home
    @ObservationIgnored private var lane = 0
    @ObservationIgnored private var px: Float = 0
    @ObservationIgnored private var py: Float = 0
    @ObservationIgnored private var yaw: Float = 0
    @ObservationIgnored private var targetYaw: Float = 0
    @ObservationIgnored private var squash: Float = 0
    @ObservationIgnored private var squashVel: Float = 0
    @ObservationIgnored private var pressed = false
    @ObservationIgnored private var riding: Mover?
    @ObservationIgnored private var rideOffset: Float = 0
    @ObservationIgnored private var hop: Hop?
    @ObservationIgnored private var queue: [Dir] = []
    @ObservationIgnored private var bestLane = 0
    @ObservationIgnored private var coinsThisRun = 0
    @ObservationIgnored private var started = false

    @ObservationIgnored private var camLane: Float = 4
    @ObservationIgnored private var camX: Float = 0
    @ObservationIgnored private var deathT: Float = 0
    @ObservationIgnored private var deathKind: DeathKind = .car
    @ObservationIgnored private var deathVel = SIMD3<Float>(0, 0, 0)
    @ObservationIgnored private var eagle: SCNNode?
    @ObservationIgnored private var eagleZ: Float = 0
    @ObservationIgnored private var eagleGrabbed = false
    @ObservationIgnored private var idleT: Float = 0
    @ObservationIgnored private var honkCooldown: Float = 0
    @ObservationIgnored private var lastTime: TimeInterval = 0
    @ObservationIgnored private var zoneShown = 0
    @ObservationIgnored private var bestAtStart = 0
    @ObservationIgnored private var announcedBest = false
    @ObservationIgnored private var deathPublished = false
    @ObservationIgnored private var lastSafeLane = 0
    @ObservationIgnored private var lastSafeX: Float = 0
    @ObservationIgnored private var invuln: Float = 0
    @ObservationIgnored private var continued = false

    @ObservationIgnored private var lightSun = SIMD4<Float>(1, 1, 1, 1000)
    @ObservationIgnored private var lightAmb = SIMD4<Float>(1, 1, 1, 400)
    @ObservationIgnored private var skyColor = SIMD3<Float>(0.5, 0.8, 1)

    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private var commands: [() -> Void] = []

    private struct Hop {
        var from: SIMD3<Float>
        var to: SIMD3<Float>
        var t: Float = 0
        let dur: Float
        let toLane: Int
        let lateralOnLog: Bool
        let height: Float
    }

    static let hopTime: Float = 0.13

    override init() {
        super.init()
        setupScene()
        rebuildWorld()
        let b = Biomes.all[0]
        lightSun = rgbI(b.sun, Float(b.sunIntensity))
        lightAmb = rgbI(b.ambient, Float(b.ambientIntensity))
        skyColor = rgb(b.sky)
        applyLights()
    }

    // MARK: - Public API (main thread)

    func press() { send { [self] in pressed = true } }

    func input(_ d: Dir) {
        send { [self] in
            pressed = false
            switch state {
            case .home:
                beginRun()
                enqueue(d)
            case .playing:
                enqueue(d)
            default: break
            }
        }
    }

    func startRun() {
        send { [self] in
            if state == .dead || state == .paused { rebuildWorld() }
            beginRun()
        }
    }

    func goHome() {
        send { [self] in
            rebuildWorld()
            state = .home
            publish { $0.phase = .home }
        }
    }

    func pause() {
        send { [self] in
            guard state == .playing else { return }
            state = .paused
            publish { $0.phase = .paused }
        }
    }

    func resume() {
        send { [self] in
            guard state == .paused else { return }
            state = .playing
            lastTime = 0
            publish { $0.phase = .playing }
        }
    }

    /// Brings the chicken back after a rewarded ad: last safe grass tile, short invulnerability.
    func revive() {
        send { [self] in
            guard state == .dead, !continued else { return }
            continued = true
            eagle?.removeFromParentNode(); eagle = nil
            player.removeFromParentNode()
            makePlayer()
            worldNode.addChildNode(player)
            lane = lastSafeLane
            px = lastSafeX; py = 0
            riding = nil; hop = nil; queue = []
            yaw = 0; targetYaw = 0; squash = -0.4; squashVel = 0
            player.position = SCNVector3(px, py, -Float(lane))
            camLane = Float(lane) + 2.3
            invuln = 2.5
            idleT = 0
            state = .playing
            lastTime = 0
            Audio.shared.play(.unlock, volume: 0.6)
            sparkle(at: player.position + SCNVector3(0, 0.5, 0))
            publish { c in
                c.canContinue = false
                c.phase = .playing
                Audio.shared.duckMusic(true)
            }
        }
    }

    func setSkin(_ s: Skin) {
        send { [self] in
            skin = s
            let parent = player.parent
            let pos = player.position
            let rot = player.eulerAngles
            player.removeFromParentNode()
            makePlayer()
            player.position = pos
            player.eulerAngles = rot
            parent?.addChildNode(player)
            squash = -0.35
        }
    }

    // MARK: - Scene setup

    private func setupScene() {
        scene.rootNode.addChildNode(worldNode)
        scene.rootNode.addChildNode(fx)

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.projectionDirection = .horizontal
        cam.orthographicScale = 4.5
        cam.zNear = 1
        cam.zFar = 80
        cameraNode.camera = cam
        cameraNode.eulerAngles = SCNVector3(-0.96, 0.24, 0)
        // pull the camera back along its own view axis
        let back = simd_act(simd_quatf(angle: 0.24, axis: [0, 1, 0]) * simd_quatf(angle: -0.96, axis: [1, 0, 0]), SIMD3<Float>(0, 0, 30))
        cameraNode.simdPosition = back
        cameraRig.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraRig)

        let l = SCNLight()
        l.type = .directional
        l.castsShadow = true
        l.shadowMode = .forward
        l.shadowMapSize = CGSize(width: 2048, height: 2048)
        l.shadowSampleCount = 8
        l.shadowRadius = 2.0
        l.shadowColor = UIColor(white: 0, alpha: 0.26)
        l.orthographicScale = 17
        l.zNear = 1
        l.zFar = 60
        l.shadowBias = 2
        sun.light = l
        sun.eulerAngles = SCNVector3(-1.0, -0.62, 0)
        let sunBack = simd_act(simd_quatf(angle: -0.62, axis: [0, 1, 0]) * simd_quatf(angle: -1.0, axis: [1, 0, 0]), SIMD3<Float>(0, 0, 25))
        sun.simdPosition = sunBack
        cameraRig.addChildNode(sun)

        let a = SCNLight()
        a.type = .ambient
        ambient.light = a
        scene.rootNode.addChildNode(ambient)
    }

    private func makePlayer() {
        player = ChickenModel.make(skin)
        playerBody = player.childNode(withName: "body", recursively: false)
    }

    private func rebuildWorld() {
        for (_, l) in lanes { l.node.removeFromParentNode() }
        lanes = [:]
        fx.childNodes.forEach { $0.removeFromParentNode() }
        eagle?.removeFromParentNode(); eagle = nil
        player.removeFromParentNode()
        gen.reset()
        minLane = -14
        maxLane = minLane - 1
        // reset before building: ensureLanes trims lanes behind `lane` and `camLane`
        lane = 0
        camLane = 2.3
        ensureLanes(upTo: 24)

        makePlayer()
        worldNode.addChildNode(player)
        lane = 0; px = 0; py = 0; yaw = 0; targetYaw = 0
        squash = 0; squashVel = 0; pressed = false
        riding = nil; hop = nil; queue = []
        bestLane = 0; coinsThisRun = 0; started = false
        lastSafeLane = 0; lastSafeX = 0; invuln = 0; continued = false
        camLane = 2.3; camX = 0; deathT = 0
        eagleGrabbed = false; idleT = 0
        zoneShown = 0
        player.position = SCNVector3(0, 0, 0)
        player.eulerAngles = SCNVector3(0, 0, 0)
        player.scale = SCNVector3(skin.scale, skin.scale, skin.scale)
        cameraRig.position = SCNVector3(0, 0, -camLane)
        publish { c in c.score = 0; c.runCoins = 0; c.newBest = false }
    }

    private func beginRun() {
        state = .playing
        bestAtStart = GameStore.shared.best
        announcedBest = false
        lastTime = 0
        publish { c in
            c.phase = .playing
            c.score = 0
            c.runCoins = 0
            c.newBest = false
            c.canContinue = true
            Audio.shared.duckMusic(true)
        }
    }

    private func ensureLanes(upTo top: Int) {
        while maxLane < top {
            maxLane += 1
            let l = gen.build(maxLane)
            lanes[maxLane] = l
            worldNode.addChildNode(l.node)
        }
        let cutoff = min(lane - 14, Int(camLane) - 18)
        while minLane < cutoff {
            if let l = lanes.removeValue(forKey: minLane) { l.node.removeFromParentNode() }
            minLane += 1
        }
    }

    // MARK: - Thread hand-off

    private func send(_ f: @escaping () -> Void) {
        lock.lock(); commands.append(f); lock.unlock()
    }

    private func publish(_ f: @escaping (GameController) -> Void) {
        DispatchQueue.main.async { [weak self] in if let self { f(self) } }
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lock.lock(); let cmds = commands; commands = []; lock.unlock()
        cmds.forEach { $0() }

        let dt: Float = lastTime == 0 ? 1 / 60 : Float(min(1 / 20, max(0, time - lastTime)))
        lastTime = time
        if state == .paused { return }

        updateMovers(dt)
        updateTrains(dt)

        switch state {
        case .home: updateIdle(dt)
        case .playing: updatePlayer(dt)
        case .dead: updateDeath(dt)
        case .paused: break
        }

        updateSquash(dt)
        updateCamera(dt)
        updateLights(dt)
    }

    // MARK: movers

    private func updateMovers(_ dt: Float) {
        let w = WorldGen.wrap
        for (_, l) in lanes where l.velocity != 0 && (l.kind == .road || l.kind == .river) {
            for m in l.movers {
                m.x += l.velocity * dt
                if m.x > w + m.len / 2 { m.x -= 2 * w + m.len }
                if m.x < -w - m.len / 2 { m.x += 2 * w + m.len }
                m.node.position.x = m.x
            }
        }
        honkCooldown -= dt
    }

    private func updateTrains(_ dt: Float) {
        for (_, l) in lanes where l.kind == .rail {
            let near = abs(l.index - lane) < 12
            switch l.trainState {
            case .idle:
                l.trainTimer -= dt
                if l.trainTimer <= 0 {
                    l.trainState = .warning
                    l.trainTimer = 1.4
                    if near && state != .home { Audio.shared.play(.bell, volume: 0.7) }
                }
            case .warning:
                l.trainTimer -= dt
                l.blink += dt
                let on = Int(l.blink / 0.16) % 2 == 0
                l.signal?.diffuse.contents = UIColor(hex: on ? 0xff3030 : 0x5a1b1b)
                if l.trainTimer <= 0 {
                    l.trainState = .passing
                    spawnTrain(l)
                    if near && state != .home { Audio.shared.play(.train, volume: 0.8) }
                }
            case .passing:
                l.blink += dt
                let on = Int(l.blink / 0.16) % 2 == 0
                l.signal?.diffuse.contents = UIColor(hex: on ? 0xff3030 : 0x5a1b1b)
                l.trainX += l.velocity * 30 * dt
                l.train?.position.x = l.trainX
                let back = l.trainX - l.velocity * l.trainLen
                if (l.velocity > 0 && back > 24) || (l.velocity < 0 && back < -24) {
                    l.train?.removeFromParentNode()
                    l.train = nil
                    l.trainState = .idle
                    l.trainTimer = rnd(3, 7.5) - WorldGen.difficulty(l.index) * 2
                    l.signal?.diffuse.contents = UIColor(hex: 0x5a1b1b)
                }
            }
        }
    }

    private func spawnTrain(_ l: Lane) {
        let t = SCNNode()
        let colors: [UInt32] = [0xe63946, 0x2b6be0, 0x2a9d8f, 0xffb21e, 0x6a4c93]
        let loco = Models.locomotive(colors.randomElement()!)
        t.addChildNode(loco)
        loco.position.x = -1.5
        var x: Float = -3.0
        for _ in 0..<Int.random(in: 3...6) {
            let w = Models.wagon(colors.randomElement()!)
            w.position.x = x - 1.3
            t.addChildNode(w)
            x -= 2.6
        }
        l.trainLen = -x
        if l.velocity < 0 { t.eulerAngles.y = .pi }
        l.trainX = -l.velocity * 24
        t.position = SCNVector3(l.trainX, -0.04, 0)
        l.node.addChildNode(t)
        l.train = t
    }

    // MARK: player

    private func enqueue(_ d: Dir) {
        if queue.count < 2 { queue.append(d) }
    }

    private func updateIdle(_ dt: Float) {
        idleT += dt
        // little look-around while on the title screen
        let cycle = idleT.truncatingRemainder(dividingBy: 6)
        targetYaw = cycle < 2.2 ? 0 : (cycle < 3.4 ? 0.7 : (cycle < 4.6 ? -0.7 : 0))
        yaw += (targetYaw - yaw) * min(1, dt * 8)
        player.eulerAngles.y = yaw
        if Int(idleT * 10) % 37 == 0 && squash == 0 { squash = 0.18 }
    }

    private func updatePlayer(_ dt: Float) {
        if hop == nil, !queue.isEmpty {
            startHop(queue.removeFirst())
        }

        if var h = hop {
            if h.lateralOnLog, let r = riding, let l = lanes[lane] {
                _ = r
                let v = l.velocity * dt
                h.from.x += v; h.to.x += v
            }
            h.t = min(1, h.t + dt / h.dur)
            let e = h.t
            let p = h.from + (h.to - h.from) * e
            px = p.x
            py = p.y + sin(e * .pi) * h.height
            player.position = SCNVector3(px, py, p.z)
            hop = h
            if h.t >= 1 {
                hop = nil
                land(h)
            }
        } else if let r = riding {
            px = r.x + rideOffset
            player.position = SCNVector3(px, py, -Float(lane))
            if abs(px) > Float(WorldGen.half) + 1.2 {
                die(.drift)
                return
            }
        }

        if invuln > 0 {
            invuln -= dt
            player.opacity = invuln > 0 && Int(invuln * 10) % 2 == 0 ? 0.35 : 1
        }
        yaw = lerpAngle(yaw, targetYaw, min(1, dt * 22))
        player.eulerAngles.y = yaw

        checkHits()

        if state == .playing {
            idleT += dt
            if Float(lane) < camLane - 8.8 { die(.eagle) }
        }
    }

    private func startHop(_ d: Dir) {
        var tLane = lane
        var col = Int(px.rounded())
        switch d {
        case .up: tLane += 1; targetYaw = 0
        case .down: tLane -= 1; targetYaw = .pi
        case .left: col -= 1; targetYaw = .pi / 2
        case .right: col += 1; targetYaw = -.pi / 2
        }
        if !started { started = true }

        let lateral = tLane == lane
        let onLog = riding != nil && lateral
        let targetX: Float = onLog ? px + (d == .left ? -1 : 1) : Float(col)

        // blocked: bounds, trees, missing lanes
        guard let target = lanes[tLane], tLane > minLane + 1 else { bump(); return }
        if abs(targetX) > Float(WorldGen.half) + 0.4 { bump(); return }
        if target.kind == .grass || target.kind == .forest {
            if target.blocked.contains(Int(targetX.rounded())) {
                bump(obstacle: target.obstacles[Int(targetX.rounded())])
                return
            }
        }

        if !onLog { riding = nil }
        let toY: Float
        if target.kind == .river {
            toY = onLog ? -0.05 : (target.lily ? -0.24 : -0.05)
        } else {
            toY = target.groundTop
        }
        hop = Hop(from: SIMD3(px, py, -Float(lane)), to: SIMD3(targetX, toY, -Float(tLane)),
                  dur: Self.hopTime, toLane: tLane, lateralOnLog: onLog, height: 0.42)
        squash = -0.28   // stretch on takeoff
        pressed = false
        Audio.shared.hop()
        Haptics.hop()
    }

    private func bump(obstacle: SCNNode? = nil) {
        squash = 0.25
        Audio.shared.play(.bump, volume: 0.6)
        if let o = obstacle {
            o.removeAction(forKey: "wobble")
            o.runAction(.sequence([
                .rotateBy(x: 0.12, y: 0, z: 0.08, duration: 0.06),
                .rotateBy(x: -0.2, y: 0, z: -0.14, duration: 0.1),
                .rotateBy(x: 0.08, y: 0, z: 0.06, duration: 0.08),
            ]), forKey: "wobble")
        }
    }

    private func land(_ h: Hop) {
        lane = h.toLane
        squash = 0.32
        guard let l = lanes[lane] else { return }

        if l.kind == .river {
            if h.lateralOnLog, riding != nil {
                rideOffset = px - (riding?.x ?? 0)
                clampRide()
            } else if let m = l.platform(at: px) {
                riding = m
                if l.lily {
                    px = m.x
                    rideOffset = 0
                    player.position.x = px
                    m.node.runAction(.sequence([.moveBy(x: 0, y: -0.06, z: 0, duration: 0.06), .moveBy(x: 0, y: 0.06, z: 0, duration: 0.15)]))
                } else {
                    // snap onto the nearest half-tile of the platform
                    rideOffset = ((px - m.x) * 2).rounded() / 2
                    clampRide()
                    m.node.runAction(.sequence([.moveBy(x: 0, y: -0.05, z: 0, duration: 0.06), .moveBy(x: 0, y: 0.05, z: 0, duration: 0.18)]))
                }
                py = l.lily ? -0.24 : -0.05
            } else {
                die(.water)
                return
            }
        } else {
            riding = nil
            px = px.rounded()
            py = l.groundTop
            player.position = SCNVector3(px, py, -Float(lane))
            if l.kind == .grass { lastSafeLane = lane; lastSafeX = px }
            puff(at: SCNVector3(px, py + 0.02, -Float(lane)), color: dustColor(l))
        }

        let col = Int(px.rounded())
        if let c = l.coins[col], abs(px - Float(col)) < 0.5 {
            l.coins[col] = nil
            collect(c)
        }

        if lane > bestLane {
            bestLane = lane
            idleT = 0
            let s = bestLane
            publish { $0.score = s }
            if bestAtStart > 0, s > bestAtStart, !announcedBest {
                announcedBest = true
                Audio.shared.play(.record, volume: 0.6)
                publish { c in c.newBest = true; c.onEvent?(.newBest) }
            }
            let z = Biomes.index(forLane: s)
            let zoneIdx = s / Biomes.zoneLength
            if zoneIdx > zoneShown, s % Biomes.zoneLength >= 0 {
                zoneShown = zoneIdx
                let b = Biomes.all[z]
                Audio.shared.play(.whoosh, volume: 0.7)
                publish { c in
                    c.banner = (b.name, b.sub, zoneIdx)
                    c.onEvent?(.zone(b))
                }
            }
        }
        ensureLanes(upTo: lane + 26)
    }

    private func clampRide() {
        guard let r = riding else { return }
        let lim = max(0, r.len / 2 - 0.35)
        rideOffset = max(-lim, min(lim, rideOffset))
        px = r.x + rideOffset
    }

    private func checkHits() {
        guard state == .playing, invuln <= 0 else { return }
        let checkLane: Int
        if let h = hop { checkLane = h.t > 0.5 ? h.toLane : lane } else { checkLane = lane }
        guard let l = lanes[checkLane] else { return }
        let half: Float = 0.3 * skin.scale

        switch l.kind {
        case .road:
            for m in l.movers where abs(m.x - px) < m.len / 2 + half {
                die(.car, mover: m, lane: l)
                return
            }
            if honkCooldown <= 0 {
                for m in l.movers {
                    let ahead = (m.x - px) * (l.velocity > 0 ? -1 : 1)
                    if ahead > 0.8 && ahead < 2.6 {
                        honkCooldown = 5
                        Audio.shared.play(.honk, volume: 0.35)
                        break
                    }
                }
            }
        case .rail:
            if l.trainState == .passing {
                let front = l.trainX + l.velocity * 1.5
                let back = l.trainX - l.velocity * (l.trainLen - 1.5)
                let lo = min(front, back), hi = max(front, back)
                if px > lo - half && px < hi + half { die(.train, lane: l) }
            }
        default: break
        }
    }

    private func collect(_ c: SCNNode) {
        coinsThisRun += 1
        let n = coinsThisRun
        Audio.shared.play(.coin, volume: 0.7)
        Haptics.coin()
        sparkle(at: c.worldPosition + SCNVector3(0, 0.4, 0))
        c.removeAllActions()
        c.runAction(.sequence([
            .group([.moveBy(x: 0, y: 1.2, z: 0, duration: 0.25), .scale(to: 0.2, duration: 0.25)]),
            .removeFromParentNode(),
        ]))
        publish { ctl in
            ctl.runCoins = n
            GameStore.shared.coins += 1
            ctl.onEvent?(.coin)
        }
    }

    // MARK: death

    private func die(_ kind: DeathKind, mover: Mover? = nil, lane l: Lane? = nil) {
        guard state == .playing else { return }
        state = .dead
        deathKind = kind
        deathT = 0
        deathPublished = false
        hop = nil
        queue = []
        Haptics.hit()
        let pos = player.position
        switch kind {
        case .car:
            Audio.shared.play(.squash)
            player.position.y = (l?.groundTop ?? 0) + 0.01
            player.scale = SCNVector3(1.35 * skin.scale, 0.12 * skin.scale, 1.35 * skin.scale)
            feathers(at: pos + SCNVector3(0, 0.3, 0))
        case .water, .drift:
            Audio.shared.play(.splash)
            splash(at: SCNVector3(pos.x, -0.25, pos.z))
            riding = nil
        case .train:
            Audio.shared.play(.squash)
            feathers(at: pos + SCNVector3(0, 0.4, 0))
            deathVel = SIMD3((l?.velocity ?? 1) * 14, 7, rnd(-1, 1))
        case .eagle:
            Audio.shared.play(.eagle)
            let e = Models.eagle()
            e.position = SCNVector3(pos.x, 2.2, pos.z - 16)
            worldNode.addChildNode(e)
            for n in ["wingL", "wingR"] {
                if let w = e.childNode(withName: n, recursively: true) {
                    let s: CGFloat = n == "wingL" ? 1 : -1
                    w.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: 0.5 * s, duration: 0.12), .rotateTo(x: 0, y: 0, z: -0.4 * s, duration: 0.12)])))
                }
            }
            eagle = e
            eagleZ = pos.z - 16
            eagleGrabbed = false
        }
        let line = kind.lines.randomElement()!
        let score = bestLane
        let coins = coinsThisRun
        publish { c in
            c.death = kind
            c.deathLine = line
            let store = GameStore.shared
            store.runs += 1
            if score > store.best { store.best = score }
            _ = coins
        }
    }

    private func updateDeath(_ dt: Float) {
        deathT += dt
        switch deathKind {
        case .water, .drift:
            py -= dt * 1.4
            player.position.y = py
            if py < -1.2 { player.isHidden = true }
        case .train:
            deathVel.y -= 22 * dt
            player.position = player.position + SCNVector3(deathVel.x * dt, deathVel.y * dt, deathVel.z * dt)
            player.eulerAngles.z += 14 * dt
            player.eulerAngles.x += 9 * dt
        case .eagle:
            guard let e = eagle else { break }
            eagleZ += 26 * dt
            e.position.z = eagleZ
            if !eagleGrabbed && eagleZ >= player.position.z - 0.2 {
                eagleGrabbed = true
                Audio.shared.play(.squash, volume: 0.5)
                feathers(at: player.position + SCNVector3(0, 0.4, 0))
                player.removeFromParentNode()
                player.position = SCNVector3(0, -0.75, 0.2)
                player.eulerAngles = SCNVector3(0, 0, 0)
                e.addChildNode(player)
            }
            if eagleGrabbed { e.position.y += dt * 2.5 }
        case .car:
            break
        }
        if deathT > 1.15, !deathPublished {
            deathPublished = true
            let kind = deathKind
            publish { c in
                c.phase = .dead
                Audio.shared.duckMusic(false)
                Audio.shared.play(.gameover, volume: 0.6)
                c.onEvent?(.died(kind))
            }
        }
    }

    // MARK: animation helpers

    private func updateSquash(_ dt: Float) {
        guard let b = playerBody, state != .dead || deathKind != .car else { return }
        // critically damped spring back to 0, unless the finger is down (anticipation)
        let target: Float = (pressed && hop == nil && (state == .playing || state == .home)) ? 0.22 : 0
        let k: Float = 260, damp: Float = 18
        squashVel += ((target - squash) * k - squashVel * damp) * dt
        squash += squashVel * dt
        let sy = 1 - squash
        let sxz = 1 + squash * 0.5
        b.scale = SCNVector3(sxz, sy, sxz)
    }

    private func updateCamera(_ dt: Float) {
        if state == .playing && started {
            let speed: Float = 0.42 + WorldGen.difficulty(bestLane) * 0.55
            camLane += speed * dt
        }
        let follow = Float(lane) + 2.3
        if follow > camLane { camLane += (follow - camLane) * min(1, dt * 3.2) }
        let tx = max(-1.6, min(1.6, px * 0.45))
        camX += (tx - camX) * min(1, dt * 2.5)
        cameraRig.position = SCNVector3(camX, 0, -camLane)
        ensureLanes(upTo: Int(camLane) + 22)
    }

    private func updateLights(_ dt: Float) {
        let b = Biomes.biome(forLane: max(0, Int(camLane) - 6))
        let k = min(1, dt * 1.2)
        lightSun += (rgbI(b.sun, Float(b.sunIntensity)) - lightSun) * k
        lightAmb += (rgbI(b.ambient, Float(b.ambientIntensity)) - lightAmb) * k
        skyColor += (rgb(b.sky) - skyColor) * k
        applyLights()
    }

    private func applyLights() {
        sun.light?.color = UIColor(red: CGFloat(lightSun.x), green: CGFloat(lightSun.y), blue: CGFloat(lightSun.z), alpha: 1)
        sun.light?.intensity = CGFloat(lightSun.w)
        ambient.light?.color = UIColor(red: CGFloat(lightAmb.x), green: CGFloat(lightAmb.y), blue: CGFloat(lightAmb.z), alpha: 1)
        ambient.light?.intensity = CGFloat(lightAmb.w)
        scene.background.contents = UIColor(red: CGFloat(skyColor.x), green: CGFloat(skyColor.y), blue: CGFloat(skyColor.z), alpha: 1)
    }

    private func dustColor(_ l: Lane) -> UIColor {
        let b = Biomes.all[l.biome]
        switch l.kind {
        case .road: return UIColor(hex: shade(b.road, 0.35))
        case .rail: return UIColor(hex: 0xb8ada0)
        default: return UIColor(hex: shade(b.grass.0, 0.25))
        }
    }

    // MARK: particles

    private func burst(at p: SCNVector3, color: UIColor, count: Int, speed: CGFloat, size: CGFloat,
                       life: CGFloat, gravity: Float, spread: CGFloat = 70, spin: Bool = true) {
        let ps = SCNParticleSystem()
        ps.particleImage = Vox.particleImage
        ps.loops = false
        ps.emissionDuration = 0.04
        ps.birthRate = CGFloat(count) / 0.04
        ps.particleLifeSpan = life
        ps.particleLifeSpanVariation = life * 0.4
        ps.particleVelocity = speed
        ps.particleVelocityVariation = speed * 0.6
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = spread
        ps.particleSize = size
        ps.particleSizeVariation = size * 0.5
        ps.particleColor = color
        ps.particleColorVariation = SCNVector4(0, 0, 0.05, 0)
        ps.acceleration = SCNVector3(0, gravity, 0)
        ps.dampingFactor = 1.2
        if spin {
            ps.particleAngularVelocity = 400
            ps.particleAngularVelocityVariation = 400
            ps.particleAngleVariation = 180
        }
        ps.isLightingEnabled = false
        ps.blendMode = .alpha
        let fade = CAKeyframeAnimation()
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.65, 1]
        ps.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        let holder = SCNNode()
        holder.position = p
        holder.addParticleSystem(ps)
        fx.addChildNode(holder)
        holder.runAction(.sequence([.wait(duration: Double(life) * 1.6), .removeFromParentNode()]))
    }

    private func feathers(at p: SCNVector3) {
        burst(at: p, color: UIColor(hex: skin.body), count: 22, speed: 3.2, size: 0.14, life: 1.1, gravity: -3, spread: 90)
        burst(at: p, color: UIColor(hex: skin.wing), count: 10, speed: 2.4, size: 0.1, life: 1.0, gravity: -3, spread: 90)
    }

    private func splash(at p: SCNVector3) {
        burst(at: p, color: UIColor(hex: 0xeafcff), count: 30, speed: 4.2, size: 0.12, life: 0.75, gravity: -14, spread: 30)
        burst(at: p, color: UIColor(hex: 0x7fd6ff), count: 16, speed: 3.0, size: 0.1, life: 0.7, gravity: -14, spread: 40)
    }

    private func puff(at p: SCNVector3, color: UIColor) {
        burst(at: p, color: color.withAlphaComponent(0.7), count: 4, speed: 0.9, size: 0.06, life: 0.3, gravity: -1, spread: 85, spin: false)
    }

    private func sparkle(at p: SCNVector3) {
        burst(at: p, color: UIColor(hex: 0xffe27a), count: 8, speed: 2.8, size: 0.06, life: 0.45, gravity: -5, spread: 180)
    }
}

// MARK: - small math helpers

private func rgb(_ hex: UInt32) -> SIMD3<Float> {
    SIMD3(Float((hex >> 16) & 0xff) / 255, Float((hex >> 8) & 0xff) / 255, Float(hex & 0xff) / 255)
}

private func rgbI(_ hex: UInt32, _ i: Float) -> SIMD4<Float> {
    let c = rgb(hex)
    return SIMD4(c.x, c.y, c.z, i)
}

private func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
    var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return a + d * t
}

func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z) }
