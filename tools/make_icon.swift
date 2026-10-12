// Draws the 1024px app icon: Gıdık's face on a sunny background.
// Usage: swift tools/make_icon.swift <out.png>
import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
// Flip so y grows downward, like the SwiftUI mascot.
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

func c(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}
let ink = c(0x3a2618)

// background: radial sun + rays
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(0xffe27a), c(0xffb21e)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(grad, startCenter: CGPoint(x: 512, y: 470), startRadius: 0, endCenter: CGPoint(x: 512, y: 470), endRadius: 760, options: [.drawsAfterEndLocation])
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
for i in 0..<12 {
    let a0 = Double(i) / 12 * 2 * .pi, a1 = a0 + .pi / 12
    ctx.move(to: CGPoint(x: 512, y: 470))
    ctx.addLine(to: CGPoint(x: 512 + cos(a0) * 1400, y: 470 + sin(a0) * 1400))
    ctx.addLine(to: CGPoint(x: 512 + cos(a1) * 1400, y: 470 + sin(a1) * 1400))
    ctx.closePath()
}
ctx.fillPath()

// road stripe at the bottom
ctx.setFillColor(c(0x545966)); ctx.fill(CGRect(x: 0, y: 840, width: S, height: 184))
ctx.setFillColor(c(0xf3f3f3))
for x in stride(from: 20, to: 1024, by: 170) { ctx.fill(CGRect(x: CGFloat(x), y: 924, width: 90, height: 18)) }

func ellipse(_ r: CGRect, _ fill: CGColor, stroke: CGFloat = 22) {
    ctx.setFillColor(fill); ctx.fillEllipse(in: r)
    ctx.setStrokeColor(ink); ctx.setLineWidth(stroke); ctx.strokeEllipse(in: r)
}

// body shadow + body
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
ctx.fillEllipse(in: CGRect(x: 230, y: 830, width: 560, height: 70))
// comb
ellipse(CGRect(x: 330, y: 150, width: 150, height: 150), c(0xff5a4e))
ellipse(CGRect(x: 430, y: 100, width: 170, height: 170), c(0xff5a4e))
ellipse(CGRect(x: 545, y: 150, width: 150, height: 150), c(0xff5a4e))
ellipse(CGRect(x: 182, y: 230, width: 660, height: 640), c(0xffffff), stroke: 26)
// cheeks
ctx.setFillColor(CGColor(red: 1, green: 0.56, blue: 0.64, alpha: 0.6))
ctx.fillEllipse(in: CGRect(x: 250, y: 560, width: 110, height: 66))
ctx.fillEllipse(in: CGRect(x: 664, y: 560, width: 110, height: 66))
// eyes
ctx.setFillColor(ink)
ctx.fillEllipse(in: CGRect(x: 360, y: 420, width: 78, height: 104))
ctx.fillEllipse(in: CGRect(x: 586, y: 420, width: 78, height: 104))
ctx.setFillColor(.white)
ctx.fillEllipse(in: CGRect(x: 398, y: 438, width: 28, height: 28))
ctx.fillEllipse(in: CGRect(x: 624, y: 438, width: 28, height: 28))
// wattle
ellipse(CGRect(x: 474, y: 650, width: 76, height: 110), c(0xff5a4e), stroke: 18)
// beak
ctx.setFillColor(c(0xffb43c))
ctx.move(to: CGPoint(x: 422, y: 620))
ctx.addQuadCurve(to: CGPoint(x: 602, y: 620), control: CGPoint(x: 512, y: 500))
ctx.closePath()
ctx.drawPath(using: .fillStroke)
ctx.setFillColor(c(0xff9a1f))
ctx.move(to: CGPoint(x: 438, y: 620))
ctx.addLine(to: CGPoint(x: 586, y: 620))
ctx.addQuadCurve(to: CGPoint(x: 438, y: 620), control: CGPoint(x: 512, y: 700))
ctx.drawPath(using: .fillStroke)

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
