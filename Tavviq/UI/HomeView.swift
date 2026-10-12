import SwiftUI

struct Logo: View {
    var size: CGFloat = 64
    @State private var t0 = Date()

    private let letters = Array("TAVVIQ")
    private let colors: [Color] = [Theme.yolk, Color(hex: 0xffe14d), Theme.tomato, Theme.yolk, Color(hex: 0x7ad3ff), Theme.leaf]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(t0)
            HStack(spacing: -4) {
                ForEach(Array(letters.enumerated()), id: \.offset) { i, ch in
                    let phase = t * 3.2 - Double(i) * 0.55
                    OutlinedText(text: String(ch), size: size, fill: colors[i], width: 4)
                        .rotationEffect(.degrees(i % 2 == 0 ? -5 : 5))
                        .offset(y: sin(phase) * 6)
                        .scaleEffect(1 + max(0, sin(phase)) * 0.05, anchor: .bottom)
                }
            }
        }
    }
}

struct Ribbon: View {
    let text: String
    var color: Color = Theme.tomato
    var dark: Color = Theme.tomatoDark

    var body: some View {
        Text(text)
            .font(Theme.font(17, .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 8)
            .background(
                RibbonShape().fill(color)
                    .overlay(RibbonShape().stroke(Theme.ink, lineWidth: 3))
            )
            .background(RibbonShape().fill(dark).overlay(RibbonShape().stroke(Theme.ink, lineWidth: 3)).offset(y: 4))
    }
}

private struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n: CGFloat = 12
        p.move(to: CGPoint(x: r.minX - n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX + n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX - n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct BestPill: View {
    let best: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.yolk)
                .shadow(color: Theme.ink, radius: 0, x: 1, y: 1)
            Text("EN İYİ \(best)")
                .font(Theme.font(16))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Theme.paper))
        .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
    }
}

struct HomeView: View {
    let store: GameStore
    let onPlay: () -> Void
    let onShop: () -> Void
    let onGift: () -> Void
    let onSettings: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BestPill(best: store.best)
                Spacer()
                CoinPill(amount: store.coins)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 14) {
                Logo(size: 66)
                Ribbon(text: "yolun karşısına geç!")
                    .rotationEffect(.degrees(-3))
            }
            .padding(.top, 26)
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .allowsHitTesting(false)

            Spacer()

            TapHint()
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Button(action: onPlay) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 26, weight: .black))
                        Text("OYNA").font(Theme.font(32))
                    }
                    .frame(width: 210, height: 46)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.yolk, dark: Theme.yolkDark, radius: 26, depth: 7))

                HStack(spacing: 14) {
                    MenuTile(icon: "bag.fill", title: "Kümes", color: Theme.tomato, dark: Theme.tomatoDark, action: onShop)
                    GiftTile(store: store, action: onGift)
                    MenuTile(icon: "gearshape.fill", title: "Ayarlar", color: Theme.sky, dark: Theme.skyDark, action: onSettings)
                }
            }
            .padding(.bottom, 30)
            .offset(y: appeared ? 0 : 220)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.62).delay(0.05)) { appeared = true }
        }
    }
}

struct MenuTile: View {
    let icon: String
    let title: String
    let color: Color
    let dark: Color
    var badge: String? = nil
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 2)
                Text(subtitle ?? title)
                    .font(Theme.font(13, .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 66, height: 52)
        }
        .buttonStyle(ChunkyButtonStyle(color: color, dark: dark, radius: 20, depth: 6))
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(Theme.font(14))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(Theme.tomato))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2.5))
                    .offset(x: 8, y: -8)
                    .modifier(Wiggle())
            }
        }
    }
}

struct GiftTile: View {
    let store: GameStore
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let ready = store.giftReady(at: tl.date)
            MenuTile(icon: "gift.fill", title: "Hediye",
                     color: ready ? Theme.leaf : Color(hex: 0xb4b9a8),
                     dark: ready ? Theme.leafDark : Color(hex: 0x878c7c),
                     badge: ready ? "!" : nil,
                     subtitle: ready ? nil : Self.format(store.giftRemaining(at: tl.date)),
                     action: action)
        }
    }

    static func format(_ s: TimeInterval) -> String {
        let t = Int(s)
        return String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
    }
}

struct Wiggle: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(on ? 10 : -10))
            .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

private struct TapHint: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .bold))
            Text("Dokun: zıpla · Kaydır: yön değiştir")
                .font(Theme.font(15, .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(Theme.ink.opacity(0.55)))
        .scaleEffect(pulse ? 1.04 : 0.98)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}
