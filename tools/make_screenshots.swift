// Builds the App Store screenshots from raw 1320x2868 simulator captures.
// swift tools/make_screenshots.swift <raw-dir> <out-dir>
// Writes <out-dir>/<lang>/<size>/NN-name.png for tr/en and 6.9" (1320x2868) / 6.5" (1284x2778).
import AppKit

struct Slide {
    let file: String
    let top: UInt32, bottom: UInt32
    let tr: (String, String)
    let en: (String, String)
}

let slides: [Slide] = [
    Slide(file: "home", top: 0xffd84a, bottom: 0xff9f1c,
          tr: ("Yolun karşısına\ngeç!", "Dokun, zıpla, kaydır, kaç."),
          en: ("Cross the\nroad!", "Tap to hop, swipe to dodge.")),
    Slide(file: "play", top: 0x7fd6ff, bottom: 0x2b86d6,
          tr: ("Arabalardan kaç,\ntrene dikkat!", "Her şerit yeni bir macera."),
          en: ("Dodge the cars,\nbeat the train!", "Every lane is a new adventure.")),
    Slide(file: "autumn", top: 0xffb36b, bottom: 0xe0582f,
          tr: ("6 rengarenk\ndünya", "Çayırdan kumsala, kanyondan şehre."),
          en: ("6 colorful\nworlds", "Meadows, beaches, canyons and more.")),
    Slide(file: "neon", top: 0x8a6bff, bottom: 0x2a1f6b,
          tr: ("Neon Şehir'de\ngece koşusu", "Taksiler hiç durmaz."),
          en: ("Night run in\nNeon City", "The taxis never stop.")),
    Slide(file: "shop", top: 0xff8a7a, bottom: 0xd93a30,
          tr: ("14 çılgın tavuk\nkostümü", "Kovboydan krala, hepsini topla."),
          en: ("14 crazy chicken\ncostumes", "From cowboy to king, collect them all.")),
    Slide(file: "egg", top: 0xb79bff, bottom: 0x5a36d6,
          tr: ("Sürpriz yumurtayı\nkır!", "İçinden ne çıkacak?"),
          en: ("Crack the\nsurprise egg!", "Who will hatch next?")),
    Slide(file: "record", top: 0x9be36a, bottom: 0x3f9a3a,
          tr: ("Rekorunu kır,\nGıdık'la kutla!", "Ne kadar uzağa gidebilirsin?"),
          en: ("Beat your best\nwith Gıdık!", "How far can you hop?")),
]

let sizes: [(name: String, w: Int, h: Int)] = [("6.9", 1320, 2868), ("6.5", 1284, 2778), ("6.3", 1206, 2622)]
let ink = NSColor(srgbRed: 0x3a / 255, green: 0x26 / 255, blue: 0x18 / 255, alpha: 1)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}

func render(_ s: Slide, raw: NSImage, text: (String, String), w W: Int, h H: Int) -> Data {
    // opaque RGB (App Store screenshots must not have an alpha channel)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // flip so y grows downward
    ctx.translateBy(x: 0, y: CGFloat(H)); ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    let Wf = CGFloat(W), Hf = CGFloat(H)
    let u = Wf / 1320   // layout unit

    // background gradient + soft diagonal stripes
    NSGradient(starting: color(s.top), ending: color(s.bottom))!.draw(in: NSRect(x: 0, y: 0, width: Wf, height: Hf), angle: 90)
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.07).cgColor)
    var x = -Hf
    while x < Wf {
        ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x + 70 * u, y: 0))
        ctx.addLine(to: CGPoint(x: x + 70 * u + Hf, y: Hf)); ctx.addLine(to: CGPoint(x: x + Hf, y: Hf)); ctx.closePath()
        x += 160 * u
    }
    ctx.fillPath()
    ctx.restoreGState()

    // headline: white with a thick ink outline, then the subline
    let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineHeightMultiple = 0.92
    let titleFont = rounded(112 * u, .black)
    let shadow = NSShadow(); shadow.shadowColor = ink; shadow.shadowOffset = NSSize(width: 0, height: -9 * u); shadow.shadowBlurRadius = 0
    let titleRect = NSRect(x: 50 * u, y: 150 * u, width: Wf - 100 * u, height: 300 * u)
    NSAttributedString(string: text.0, attributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: para,
                                                   .strokeColor: ink, .strokeWidth: 16, .shadow: shadow]).draw(in: titleRect)
    NSAttributedString(string: text.0, attributes: [.font: titleFont, .foregroundColor: NSColor.white, .paragraphStyle: para]).draw(in: titleRect)
    NSAttributedString(string: text.1, attributes: [.font: rounded(50 * u, .heavy), .foregroundColor: NSColor.white.withAlphaComponent(0.95),
                                                   .paragraphStyle: para]).draw(in: NSRect(x: 50 * u, y: 470 * u, width: Wf - 100 * u, height: 80 * u))

    // phone: the capture with rounded corners, an ink bezel and a drop shadow; it bleeds off the bottom
    let pw = Wf * 0.78
    let ph = pw * raw.size.height / raw.size.width
    let phone = NSRect(x: (Wf - pw) / 2, y: 600 * u, width: pw, height: ph)
    let radius = pw * 0.115
    let bezel = phone.insetBy(dx: -22 * u, dy: -22 * u)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 30 * u), blur: 60 * u, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ink.setFill()
    NSBezierPath(roundedRect: bezel, xRadius: radius + 22 * u, yRadius: radius + 22 * u).fill()
    ctx.restoreGState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: phone, xRadius: radius, yRadius: radius).addClip()
    raw.draw(in: phone, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let rawDir = CommandLine.arguments[1], outDir = CommandLine.arguments[2]
for lang in ["tr", "en"] {
    for size in sizes {
        let dir = "\(outDir)/\(lang)/\(size.name)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (i, s) in slides.enumerated() {
            guard let raw = NSImage(contentsOfFile: "\(rawDir)/\(s.file).png") else { fatalError("missing \(s.file).png") }
            let data = render(s, raw: raw, text: lang == "tr" ? s.tr : s.en, w: size.w, h: size.h)
            try! data.write(to: URL(fileURLWithPath: String(format: "%@/%02d-%@.png", dir, i + 1, s.file)))
        }
    }
}
print("done")
