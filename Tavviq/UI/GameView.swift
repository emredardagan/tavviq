import SwiftUI
import SceneKit

/// Hosts the game's SCNView and turns touches into hops (tap = forward, swipe = direction).
struct GameView: UIViewRepresentable {
    let controller: GameController

    func makeUIView(context: Context) -> TouchSCNView {
        let v = TouchSCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        v.scene = controller.scene
        v.delegate = controller
        v.isPlaying = true
        v.rendersContinuously = true
        v.preferredFramesPerSecond = 60
        v.antialiasingMode = .multisampling4X
        v.backgroundColor = UIColor(hex: 0x8fd8ff)
        v.isUserInteractionEnabled = false
        v.controller = controller
        return v
    }

    func updateUIView(_ uiView: TouchSCNView, context: Context) {}
}

final class TouchSCNView: SCNView {
    weak var controller: GameController?
}

/// Full-screen gesture layer that sits right above the 3D view and below every menu,
/// so buttons always win and empty space always reaches the game.
struct GameTouchLayer: View {
    let controller: GameController
    @State private var fired = false
    @State private var down = false
    private let threshold: CGFloat = 22

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        guard controller.phase == .home || controller.phase == .playing else { return }
                        if !down { down = true; fired = false; controller.press() }
                        guard !fired else { return }
                        let dx = v.translation.width, dy = v.translation.height
                        guard max(abs(dx), abs(dy)) > threshold else { return }
                        fired = true
                        if abs(dx) > abs(dy) {
                            controller.input(dx > 0 ? .right : .left)
                        } else {
                            controller.input(dy > 0 ? .down : .up)
                        }
                    }
                    .onEnded { _ in
                        defer { down = false; fired = false }
                        guard down, controller.phase == .home || controller.phase == .playing else { return }
                        if !fired { controller.input(.up) }
                    }
            )
    }
}

// MARK: - Skin previews

/// Renders a small portrait of every skin once, off the main thread.
@Observable
final class SkinThumbs {
    static let shared = SkinThumbs()
    private(set) var images: [String: UIImage] = [:]
    private var started = false

    func warmUp() {
        guard !started else { return }
        started = true
        DispatchQueue.global(qos: .utility).async {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            let renderer = SCNRenderer(device: device, options: nil)
            for s in Skins.all {
                let scene = Self.stage(for: s, spin: false)
                renderer.scene = scene
                renderer.pointOfView = scene.rootNode.childNode(withName: "cam", recursively: false)
                let img = renderer.snapshot(atTime: 0, with: CGSize(width: 240, height: 240), antialiasingMode: .multisampling4X)
                DispatchQueue.main.async { self.images[s.id] = img }
            }
        }
    }

    /// A tiny scene with the chicken on a grass block, used for thumbnails and the big preview.
    static func stage(for s: Skin, spin: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let holder = SCNNode()
        holder.name = "holder"
        let chicken = ChickenModel.make(s)
        chicken.position.y = 0
        holder.addChildNode(chicken)
        Vox.box(1.0, 0.3, 1.0, 0x9ad65c, x: 0, y: -0.3, z: 0, chamfer: 0.05, in: holder)
        Vox.box(1.0, 0.16, 1.0, 0x8a6a4a, x: 0, y: -0.45, z: 0, chamfer: 0.05, in: holder)
        holder.eulerAngles.y = .pi - 0.6
        scene.rootNode.addChildNode(holder)
        if spin {
            holder.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 7)))
        }

        let cam = SCNNode()
        cam.name = "cam"
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 30
        cam.position = SCNVector3(0, 1.6, 3.4)
        cam.look(at: SCNVector3(0, 0.36, 0))
        scene.rootNode.addChildNode(cam)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.light?.color = UIColor(hex: 0xfff3dc)
        sun.eulerAngles = SCNVector3(-0.9, -0.5, 0)
        scene.rootNode.addChildNode(sun)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 420
        amb.light?.color = UIColor(hex: 0xc8d8f0)
        scene.rootNode.addChildNode(amb)
        return scene
    }
}

/// Live, slowly spinning 3D preview of one skin.
struct SkinPreview: UIViewRepresentable {
    let skin: Skin

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 60
        v.isUserInteractionEnabled = false
        set(v)
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        if context.coordinator.id != skin.id { set(v); context.coordinator.id = skin.id }
    }

    func makeCoordinator() -> Coord { Coord(id: skin.id) }
    final class Coord { var id: String; init(id: String) { self.id = id } }

    private func set(_ v: SCNView) {
        let scene = SkinThumbs.stage(for: skin, spin: true)
        if let h = scene.rootNode.childNode(withName: "holder", recursively: false) {
            h.scale = SCNVector3(0.01, 0.01, 0.01)
            h.runAction(.sequence([
                .scale(to: 1.15, duration: 0.16),
                .scale(to: 1.0, duration: 0.12),
            ]))
        }
        v.scene = scene
        v.pointOfView = scene.rootNode.childNode(withName: "cam", recursively: false)
        v.isPlaying = true
    }
}
