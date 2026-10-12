import SwiftUI
import Observation

enum MascotMood { case happy, surprised, laugh, wink, sad }

/// "Gıdık", the Tavviq mascot, drawn entirely with SwiftUI shapes.
/// Animations (bob, blink, beak, wing flap) are driven by time, so the view is cheap and stateless.
struct MascotView: View {
    var mood: MascotMood = .happy
    var talking = false
    var excited = false
    var size: CGFloat = 140

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let blink = (t.truncatingRemainder(dividingBy: 3.3)) < 0.13 && mood != .wink
            let beak = talking ? abs(sin(t * 15)) : (mood == .laugh || mood == .surprised ? 0.8 : 0)
            let flap = excited ? sin(t * 26) * 28 : sin(t * 2.2) * 5
            let bob = excited ? abs(sin(t * 9)) * -6 : sin(t * 3) * 2
            let squish = 1 + (excited ? sin(t * 18) * 0.03 : sin(t * 3) * 0.015)
            canvas(blink: blink, beak: beak, flap: flap)
                .scaleEffect(x: 1 / squish, y: squish, anchor: .bottom)
                .offset(y: bob)
        }
        .frame(width: size, height: size * 1.08)
    }

    private func canvas(blink: Bool, beak: Double, flap: Double) -> some View {
        let s = size / 140
        let ink = Theme.ink
        let lw = 4 * s
        return ZStack {
            // legs
            ForEach([52.0, 84.0], id: \.self) { x in
                ZStack {
                    RoundedRectangle(cornerRadius: 3 * s).fill(Color(hex: 0xff9a1f)).frame(width: 7 * s, height: 22 * s)
                        .overlay(RoundedRectangle(cornerRadius: 3 * s).stroke(ink, lineWidth: 2.5 * s))
                        .position(x: x * s, y: 132 * s)
                    Capsule().fill(Color(hex: 0xff9a1f)).frame(width: 22 * s, height: 8 * s)
                        .overlay(Capsule().stroke(ink, lineWidth: 2.5 * s))
                        .position(x: (x + 4) * s, y: 143 * s)
                }
            }
            // tail feathers
            ForEach(0..<3) { i in
                Ellipse().fill(Color(hex: 0xece6da))
                    .overlay(Ellipse().stroke(ink, lineWidth: 3 * s))
                    .frame(width: 30 * s, height: 16 * s)
                    .rotationEffect(.degrees(-35 + Double(i) * 28))
                    .position(x: 20 * s, y: (70 + Double(i) * 10) * s)
            }
            // body
            Ellipse().fill(Color.white)
                .overlay(Ellipse().stroke(ink, lineWidth: lw))
                .frame(width: 112 * s, height: 108 * s)
                .position(x: 70 * s, y: 80 * s)
            // belly shade
            Ellipse().fill(Color(hex: 0xf1ebdf))
                .frame(width: 70 * s, height: 40 * s)
                .position(x: 74 * s, y: 112 * s)
                .mask(Ellipse().frame(width: 104 * s, height: 100 * s).position(x: 70 * s, y: 80 * s))
            // comb
            ForEach(Array([(54.0, 30.0, 22.0), (70.0, 22.0, 26.0), (86.0, 30.0, 22.0)].enumerated()), id: \.offset) { _, c in
                Circle().fill(Theme.tomato)
                    .overlay(Circle().stroke(ink, lineWidth: 3.5 * s))
                    .frame(width: c.2 * s, height: c.2 * s)
                    .position(x: c.0 * s, y: c.1 * s)
            }
            // cover the comb/body seam
            Ellipse().fill(Color.white).frame(width: 60 * s, height: 20 * s).position(x: 70 * s, y: 40 * s)
            // cheeks
            ForEach([42.0, 98.0], id: \.self) { x in
                Ellipse().fill(Color(hex: 0xff8fa3).opacity(0.55)).frame(width: 16 * s, height: 10 * s).position(x: x * s, y: 86 * s)
            }
            // eyes
            eye(blink: blink, wink: false, s: s).position(x: 54 * s, y: 66 * s)
            eye(blink: blink, wink: mood == .wink, s: s).position(x: 86 * s, y: 66 * s)
            if mood == .surprised || mood == .sad {
                ForEach([54.0, 86.0], id: \.self) { x in
                    Capsule().fill(ink).frame(width: 14 * s, height: 3.5 * s)
                        .rotationEffect(.degrees((x < 70 ? 1 : -1) * (mood == .sad ? -18 : 12)))
                        .position(x: x * s, y: 50 * s)
                }
            }
            // wattle
            Ellipse().fill(Theme.tomato)
                .overlay(Ellipse().stroke(ink, lineWidth: 3 * s))
                .frame(width: 13 * s, height: 18 * s)
                .position(x: 70 * s, y: (100 + beak * 5) * s)
            // beak
            BeakHalf(top: false).fill(Color(hex: 0xff9a1f))
                .overlay(BeakHalf(top: false).stroke(ink, style: StrokeStyle(lineWidth: 3 * s, lineJoin: .round)))
                .frame(width: 24 * s, height: 10 * s)
                .rotationEffect(.degrees(beak * 18), anchor: .top)
                .position(x: 70 * s, y: 87 * s)
            BeakHalf(top: true).fill(Color(hex: 0xffb43c))
                .overlay(BeakHalf(top: true).stroke(ink, style: StrokeStyle(lineWidth: 3 * s, lineJoin: .round)))
                .frame(width: 26 * s, height: 13 * s)
                .position(x: 70 * s, y: 79 * s)
            // wing
            Ellipse().fill(Color(hex: 0xf3eee4))
                .overlay(Ellipse().stroke(ink, lineWidth: 3.5 * s))
                .frame(width: 42 * s, height: 30 * s)
                .rotationEffect(.degrees(-25 - flap), anchor: .leading)
                .position(x: 112 * s, y: 94 * s)
        }
        .frame(width: 140 * s, height: 150 * s)
    }

    private func eye(blink: Bool, wink: Bool, s: CGFloat) -> some View {
        Group {
            if blink || wink || mood == .laugh {
                // closed: a happy arc
                Arc().stroke(Theme.ink, style: StrokeStyle(lineWidth: 3.5 * s, lineCap: .round))
                    .frame(width: 14 * s, height: 7 * s)
            } else {
                ZStack {
                    Ellipse().fill(Theme.ink).frame(width: 12 * s, height: (mood == .surprised ? 18 : 16) * s)
                    Circle().fill(.white).frame(width: 4.5 * s).offset(x: 2 * s, y: -3.5 * s)
                }
            }
        }
    }
}

private struct BeakHalf: Shape {
    let top: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if top {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
            p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.6))
        }
        return p
    }
}

private struct Arc: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.5))
        return p
    }
}

// MARK: - Director

enum MascotEdge: CaseIterable { case leading, trailing, bottom }
enum MascotContext { case home, shop, gameOver, playing, modal }

struct MascotPeek: Identifiable, Equatable {
    let id = UUID()
    let line: String?
    let edge: MascotEdge
    let mood: MascotMood
    let yFraction: CGFloat
    let hold: Double
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
}

/// Decides when and where the mascot pops onto the screen.
@Observable
final class MascotDirector {
    private(set) var current: MascotPeek?
    var context: MascotContext = .home
    private var hideTask: Task<Void, Never>?
    private var chatterTask: Task<Void, Never>?
    private var lastEdge: MascotEdge = .bottom
    var tapCount = 0

    static let homeLines = [
        "Yolun karşısında ne var? Hadi bakalım!",
        "Sağa bak, sola bak... sonra yine sağa bak.",
        "Trenlere dikkat. Ciddiyim. Çok ciddiyim.",
        "Ben de bir zamanlar civcivdim.",
        "Tavuk mu yumurtadan, yumurta mı tavuktan? Boş ver, zıpla!",
        "Bu tüyler kendiliğinden parlamıyor.",
        "Gıt gıt gıdaaak!",
        "Kütüklere bin, suya basma. Tavuk kuralı #1.",
        "Kartallar oyalananları sever. Oyalanma!",
        "Bana dokunma! ...Tamam bir kere dokun.",
    ]
    static let shopLines = [
        "Bu şapka sana çok yakışır!",
        "Jetonlar ağaçta yetişmiyor... ama yolda var!",
        "Sürpriz yumurta! İçinden ne çıkacak acaba?",
        "Kral tacı mı? Önce rekor kır.",
        "Kovboy şapkası, tam bir tavuk klasiği.",
    ]
    static let deadLines = [
        "Ahh! Az kalmıştı!",
        "Ben görmedim, kimse görmedi.",
        "Bir daha! Bir daha!",
        "Tüylerim diken diken oldu.",
        "Sorun değil, ben de ilk seferde ezildim.",
        "Yeniden doğ, yeniden zıpla!",
    ]
    static let tapLines = ["GIDAK!", "Hey! Gıdıklanıyorum!", "Bok bok bok!", "Ne var ne var?", "Tüylerimi bozma!", "Hı hı, ben de seni seviyorum."]

    func say(_ line: String?, edge: MascotEdge? = nil, mood: MascotMood = .happy, hold: Double = 3.2, sound: Bool = true) {
        hideTask?.cancel()
        let allowed: [MascotEdge] = context == .gameOver ? MascotEdge.allCases : [.leading, .trailing]
        let e = edge ?? (allowed.filter { $0 != lastEdge }.randomElement() ?? .leading)
        lastEdge = e
        let peek = MascotPeek(line: line, edge: e, mood: mood, yFraction: CGFloat.random(in: 0.32...0.62), hold: hold)
        withAnimation(.spring(response: 0.25)) { current = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(current == nil ? 10 : 220))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { self.current = peek }
            if sound { Audio.shared.play(.cluck, volume: 0.55) }
        }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            self.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { current = nil }
    }

    /// Random chatter while the player is in menus.
    func startChatter() {
        chatterTask?.cancel()
        chatterTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            while !Task.isCancelled {
                if current == nil {
                    switch context {
                    case .home: say(Self.homeLines.randomElement()!)
                    case .shop: say(Self.shopLines.randomElement()!, mood: .wink)
                    case .gameOver: say(Self.deadLines.randomElement()!, edge: .bottom, mood: .sad)
                    case .playing, .modal: break
                    }
                }
                try? await Task.sleep(for: .seconds(Double.random(in: 9...15)))
            }
        }
    }
}

// MARK: - Peek layer

struct MascotLayer: View {
    let director: MascotDirector
    var interactive = true
    var onTapReward: (() -> Void)?

    @State private var jump = false
    @State private var excited = false
    @State private var tapLine: String?
    @State private var feathers: [Feather] = []

    struct Feather: Identifiable { let id = UUID(); let dx: CGFloat; let dy: CGFloat; let rot: Double }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let p = director.current {
                    peekView(p, in: geo.size)
                        .id(p.id)
                        .transition(transition(for: p.edge))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func transition(for e: MascotEdge) -> AnyTransition {
        switch e {
        case .leading: return .move(edge: .leading).combined(with: .opacity)
        case .trailing: return .move(edge: .trailing).combined(with: .opacity)
        case .bottom: return .move(edge: .bottom)
        }
    }

    @ViewBuilder
    private func peekView(_ p: MascotPeek, in size: CGSize) -> some View {
        let line = tapLine ?? p.line
        let mood: MascotMood = tapLine != nil ? .laugh : p.mood
        let m = MascotView(mood: mood, talking: line != nil, excited: excited, size: 130)
            .scaleEffect(jump ? 1.15 : 1)
            .offset(y: jump ? -24 : 0)
            .overlay { featherBurst }
            .contentShape(Rectangle())
            .onTapGesture { tapped() }
            .allowsHitTesting(interactive)

        switch p.edge {
        case .leading:
            HStack(alignment: .top, spacing: -6) {
                m.rotationEffect(.degrees(28), anchor: .bottom)
                if let line { bubble(line, tail: .leading).padding(.top, 6) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: -44)
            .position(x: size.width / 2, y: size.height * p.yFraction)
        case .trailing:
            HStack(alignment: .top, spacing: -6) {
                if let line { bubble(line, tail: .trailing).padding(.top, 6) }
                m.scaleEffect(x: -1, y: 1).rotationEffect(.degrees(-28), anchor: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: 44)
            .position(x: size.width / 2, y: size.height * p.yFraction)
        case .bottom:
            VStack(spacing: 2) {
                if let line { bubble(line, tail: .bottom) }
                m
            }
            .frame(maxWidth: 300)
            .position(x: size.width * 0.5, y: size.height - 48 - (line == nil ? 0 : 20))
        }
    }

    private enum Tail { case leading, trailing, bottom }

    private func bubble(_ text: String, tail: Tail) -> some View {
        Text(text)
            .font(Theme.font(16, .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: 210)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.ink, lineWidth: 3))
            .overlay(alignment: tail == .bottom ? .bottom : (tail == .leading ? .bottomLeading : .bottomTrailing)) {
                BubbleTail()
                    .fill(Theme.paper)
                    .overlay(BubbleTail().stroke(Theme.ink, lineWidth: 3))
                    .frame(width: 18, height: 14)
                    .rotationEffect(.degrees(tail == .trailing ? -30 : (tail == .leading ? 30 : 0)))
                    .offset(x: tail == .leading ? 6 : (tail == .trailing ? -6 : 0), y: 11)
                    .mask(Rectangle().offset(y: 3).frame(height: 24))
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var featherBurst: some View {
        ZStack {
            ForEach(feathers) { f in
                Ellipse().fill(.white).overlay(Ellipse().stroke(Theme.ink, lineWidth: 2))
                    .frame(width: 16, height: 8)
                    .rotationEffect(.degrees(f.rot))
                    .offset(x: f.dx, y: f.dy)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }

    private func tapped() {
        Audio.shared.play(.cluck, volume: 0.8)
        Haptics.tap()
        director.tapCount += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { jump = true; excited = true }
        tapLine = MascotDirector.tapLines.randomElement()
        let burst = (0..<7).map { _ in Feather(dx: .random(in: -70...70), dy: .random(in: -90...(-10)), rot: .random(in: 0...360)) }
        feathers = burst.map { Feather(dx: 0, dy: 0, rot: $0.rot) }
        withAnimation(.easeOut(duration: 0.6)) { feathers = burst }
        if director.tapCount % 8 == 0 { onTapReward?() }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jump = false }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation { feathers = []; excited = false }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation { tapLine = nil }
        }
    }
}

private struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}
