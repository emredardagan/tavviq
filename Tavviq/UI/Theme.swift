import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x3a2618)
    static let cream = Color(hex: 0xfff6e4)
    static let yolk = Color(hex: 0xffc93c)
    static let yolkDark = Color(hex: 0xe59a12)
    static let tomato = Color(hex: 0xff5a4e)
    static let tomatoDark = Color(hex: 0xc93a30)
    static let leaf = Color(hex: 0x6cc24a)
    static let leafDark = Color(hex: 0x3f9a3a)
    static let sky = Color(hex: 0x58b9ff)
    static let skyDark = Color(hex: 0x2b86d6)
    static let plum = Color(hex: 0x7b5cff)
    static let plumDark = Color(hex: 0x5236c9)
    static let paper = Color(hex: 0xfffbf2)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

/// Text with a thick cartoon outline (8 offset copies under the fill).
struct OutlinedText: View {
    let text: String
    var size: CGFloat
    var fill: Color = .white
    var stroke: Color = Theme.ink
    var width: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Text(text).font(Theme.font(size)).foregroundStyle(stroke)
                    .offset(x: cos(a) * width, y: sin(a) * width)
            }
            Text(text).font(Theme.font(size)).foregroundStyle(stroke).offset(y: width + 2)
            Text(text).font(Theme.font(size)).foregroundStyle(fill)
        }
    }
}

/// Chunky "3D" button: a darker base under a raised face that presses down.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.yolk
    var dark: Color = Theme.yolkDark
    var radius: CGFloat = 22
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        configuration.label
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.white.opacity(0.28))
                            .frame(height: 10)
                            .padding(.horizontal, 10)
                            .padding(.top, 5)
                    }
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.ink, lineWidth: 3))
            .offset(y: down ? depth - 1 : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(dark)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.ink, lineWidth: 3))
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .scaleEffect(down ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: down)
            .onChange(of: down) { _, isDown in
                if isDown { Audio.shared.play(.tap, volume: 0.7); Haptics.tap() }
            }
    }
}

/// Coin icon drawn in SwiftUI.
struct CoinIcon: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xe59a12)).offset(y: size * 0.08)
            Circle().fill(Color(hex: 0xffc21a))
            Circle().stroke(Color(hex: 0xffe27a), lineWidth: size * 0.1).padding(size * 0.18)
            Circle().stroke(Theme.ink, lineWidth: max(1.5, size * 0.09))
        }
        .frame(width: size, height: size)
    }
}

struct CoinPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 22)
            Text("\(amount)")
                .font(Theme.font(19))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(amount)))
                .monospacedDigit()
        }
        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 5)
        .background(Capsule().fill(Theme.paper))
        .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
        .animation(.spring(response: 0.3), value: amount)
    }
}

/// Round icon button (settings, close, pause).
struct RoundIconButton: View {
    let systemName: String
    var color: Color = Theme.paper
    var dark: Color = Color(hex: 0xd9ccb3)
    var size: CGFloat = 50
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .frame(width: size - 22, height: size - 26)
        }
        .buttonStyle(ChunkyButtonStyle(color: color, dark: dark, radius: size / 2, depth: 5))
    }
}

extension View {
    func cardStyle(_ fill: Color = Theme.paper, radius: CGFloat = 28) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.ink, lineWidth: 3.5))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.ink).offset(y: 7))
    }
}
