import SceneKit
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

/// Mixes two hex colours. `t = 0` gives `a`, `t = 1` gives `b`.
func mixHex(_ a: UInt32, _ b: UInt32, _ t: Float) -> UInt32 {
    func ch(_ v: UInt32, _ s: UInt32) -> Float { Float((v >> s) & 0xff) }
    func m(_ s: UInt32) -> UInt32 { UInt32(max(0, min(255, ch(a, s) + (ch(b, s) - ch(a, s)) * t)).rounded()) }
    return (m(16) << 16) | (m(8) << 8) | m(0)
}

func shade(_ c: UInt32, _ f: Float) -> UInt32 { f < 0 ? mixHex(c, 0x000000, -f) : mixHex(c, 0xffffff, f) }

/// Shared materials and box geometries. Everything in the world is built from these,
/// so SceneKit can reuse buffers and keep draw calls cheap.
enum Vox {
    private static var materials: [String: SCNMaterial] = [:]
    private static var geometries: [String: SCNGeometry] = [:]
    private static let lock = NSLock()

    static func material(_ hex: UInt32, glow: Bool = false, alpha: CGFloat = 1) -> SCNMaterial {
        let key = "\(hex)-\(glow)-\(alpha)"
        lock.lock(); defer { lock.unlock() }
        if let m = materials[key] { return m }
        let m = SCNMaterial()
        m.lightingModel = glow ? .constant : .lambert
        m.diffuse.contents = UIColor(hex: hex, alpha: alpha)
        if glow { m.emission.contents = UIColor(hex: hex) }
        if alpha < 1 { m.transparency = alpha; m.writesToDepthBuffer = false; m.blendMode = .alpha }
        m.isDoubleSided = false
        materials[key] = m
        return m
    }

    static func boxGeometry(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ hex: UInt32, chamfer: CGFloat, glow: Bool = false, alpha: CGFloat = 1) -> SCNGeometry {
        let key = "\(w)x\(h)x\(d)-\(chamfer)-\(hex)-\(glow)-\(alpha)"
        lock.lock()
        if let g = geometries[key] { lock.unlock(); return g }
        lock.unlock()
        let c = min(chamfer, min(w, min(h, d)) * 0.45)
        let g = SCNBox(width: w, height: h, length: d, chamferRadius: c)
        g.chamferSegmentCount = 2
        g.firstMaterial = material(hex, glow: glow, alpha: alpha)
        lock.lock(); geometries[key] = g; lock.unlock()
        return g
    }

    /// A box whose *bottom* sits at `y`. `x`/`z` are the centre.
    @discardableResult
    static func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ hex: UInt32,
                    x: Float = 0, y: Float = 0, z: Float = 0,
                    chamfer: CGFloat = 0.03, glow: Bool = false, alpha: CGFloat = 1,
                    in parent: SCNNode? = nil) -> SCNNode {
        let n = SCNNode(geometry: boxGeometry(w, h, d, hex, chamfer: chamfer, glow: glow, alpha: alpha))
        n.position = SCNVector3(x, y + Float(h) / 2, z)
        parent?.addChildNode(n)
        return n
    }

    static func cylinder(r: CGFloat, h: CGFloat, _ hex: UInt32, x: Float = 0, y: Float = 0, z: Float = 0, glow: Bool = false, in parent: SCNNode? = nil) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.radialSegmentCount = 14
        g.firstMaterial = material(hex, glow: glow)
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(x, y + Float(h) / 2, z)
        parent?.addChildNode(n)
        return n
    }

    /// Small white square used by every particle system (tinted per system).
    static let particleImage: UIImage = {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return r.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 2, y: 2, width: 12, height: 12))
        }
    }()
}

func rnd(_ a: Float, _ b: Float) -> Float { Float.random(in: a..<b) }
func chance(_ p: Float) -> Bool { Float.random(in: 0..<1) < p }
