import SwiftUI

struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.86, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.36))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.86),
                   control2: CGPoint(x: r.minX + w * 0.78, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.22, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.86))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.36),
                   control2: CGPoint(x: r.minX + w * 0.14, y: r.minY))
        return p
    }
}

/// Diagonal candy stripes used as the shop background.
struct StripesBackground: View {
    var a = Color(hex: 0xfff1d0)
    var b = Color(hex: 0xffe7b8)
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(a))
            let step: CGFloat = 34
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + step / 2, y: 0))
                p.addLine(to: CGPoint(x: x + step / 2 + size.height, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(b))
                x += step
            }
        }
        .ignoresSafeArea()
    }
}

struct ShopView: View {
    let store: GameStore
    let thumbs: SkinThumbs
    let onClose: () -> Void
    let onSelect: (Skin) -> Void
    let onEgg: (Skin) -> Void
    let mascot: MascotDirector
    let ads: Ads

    @State private var focus: Skin = GameStore.shared.skin
    @State private var shake = 0

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            StripesBackground()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        preview
                        eggBanner
                        if ads.rewardedReady && store.shopAdsLeft > 0 { adBanner }
                        LazyVGrid(columns: cols, spacing: 14) {
                            ForEach(Skins.all) { s in
                                SkinCard(skin: s, image: thumbs.images[s.id],
                                         owned: store.owned.contains(s.id),
                                         selected: store.selected == s.id,
                                         focused: focus.id == s.id)
                                .onTapGesture {
                                    Audio.shared.play(.pop, volume: 0.6)
                                    Haptics.tap()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { focus = s }
                                }
                            }
                        }
                        Text("\(store.owned.count)/\(Skins.all.count) kostüm toplandı")
                            .font(Theme.font(14, .heavy))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            RoundIconButton(systemName: "xmark", size: 46, action: onClose)
            Spacer()
            OutlinedText(text: "KÜMES", size: 34, fill: Theme.tomato, width: 3.5)
            Spacer()
            CoinPill(amount: store.coins)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var preview: some View {
        let owned = store.owned.contains(focus.id)
        let selected = store.selected == focus.id
        let afford = store.coins >= focus.price
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: focus.rarity.color).opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 120))
                    .frame(width: 240, height: 240)
                SkinPreview(skin: focus)
                    .frame(width: 230, height: 210)
            }
            .frame(height: 200)
            HStack(spacing: 8) {
                Text(focus.name).font(Theme.font(26)).foregroundStyle(Theme.ink)
                Text(focus.rarity.rawValue.uppercased(with: Locale(identifier: "tr")))
                    .font(Theme.font(11, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: focus.rarity.color)))
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
            }
            Text(focus.line)
                .font(Theme.font(15, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.65))

            Group {
                if selected {
                    Label("GİYİLDİ", systemImage: "checkmark.circle.fill")
                        .font(Theme.font(20))
                        .foregroundStyle(Theme.leafDark)
                        .frame(height: 46)
                } else if owned {
                    Button {
                        onSelect(focus)
                    } label: {
                        Text("GİY").font(Theme.font(22)).frame(width: 150, height: 34)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark))
                } else {
                    Button {
                        if store.buy(focus) {
                            Audio.shared.play(.unlock)
                            Haptics.success()
                            onSelect(focus)
                            mascot.say(["Çok yakıştı!", "Vay! Yeni tüyler!", "İşte bu! Tam bir yıldız."].randomElement()!, mood: .laugh)
                        } else {
                            Audio.shared.play(.bump)
                            withAnimation(.default) { shake += 1 }
                            mascot.say("Jetonun yetmiyor... Biraz daha zıpla!", mood: .sad)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("AL").font(Theme.font(22))
                            CoinIcon(size: 22)
                            Text("\(focus.price)").font(Theme.font(22)).monospacedDigit()
                        }
                        .frame(width: 170, height: 34)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: afford ? Theme.yolk : Color(hex: 0xd8d2c4),
                                                   dark: afford ? Theme.yolkDark : Color(hex: 0xa9a294)))
                    .modifier(ShakeEffect(animatableData: CGFloat(shake)))
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var adBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                CoinIcon(size: 40).offset(x: -6, y: 4)
                CoinIcon(size: 40).offset(x: 8, y: -4)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bedava Jeton").font(Theme.font(19)).foregroundStyle(Theme.ink)
                Text("Kısa bir reklam izle, +\(Ads.Rules.shopReward) jeton kap. Bugün \(store.shopAdsLeft) hak kaldı.")
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                ads.showRewarded { ok in
                    guard ok else { return }
                    store.grantShopAdReward()
                    Audio.shared.play(.coin)
                    Haptics.success()
                    mascot.say("+\(Ads.Rules.shopReward) jeton! Kolay para, gıdak.", mood: .laugh)
                }
            } label: {
                Image(systemName: "play.fill").font(.system(size: 20, weight: .black)).frame(width: 64, height: 30)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark))
            .foregroundStyle(.white)
        }
        .padding(14)
        .cardStyle(Color(hex: 0xeefbe6), radius: 24)
    }

    private var eggBanner: some View {
        let can = store.coins >= GameStore.eggPrice && !store.unownedSkins.isEmpty
        return HStack(spacing: 14) {
            WobblyEgg(size: 56, wobble: can)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sürpriz Yumurta").font(Theme.font(19)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(store.unownedSkins.isEmpty ? "Hepsini topladın! Efsanesin." : "\(GameStore.eggPrice) jetona rastgele kostüm")
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            Spacer()
            Button {
                if let s = store.crackEgg() {
                    onEgg(s)
                } else {
                    Audio.shared.play(.bump)
                    mascot.say(store.unownedSkins.isEmpty ? "Kümes dolu! Hepsi sende." : "100 jeton lazım. Yolda çok var!", mood: .sad)
                }
            } label: {
                Text("KIR!").font(Theme.font(20)).frame(width: 64, height: 30)
            }
            .buttonStyle(ChunkyButtonStyle(color: can ? Theme.plum : Color(hex: 0xc9c2d8),
                                           dark: can ? Theme.plumDark : Color(hex: 0x9a93ab)))
            .foregroundStyle(.white)
        }
        .padding(14)
        .cardStyle(Color(hex: 0xf4eeff), radius: 24)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 9 * sin(animatableData * .pi * 4), y: 0))
    }
}

struct WobblyEgg: View {
    var size: CGFloat = 60
    var wobble = true
    var cracks = 0

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let w = wobble ? sin(t * 9) * (sin(t * 1.3) > 0.4 ? 9 : 1.5) : 0
            ZStack {
                EggShape().fill(Theme.ink).offset(y: 4)
                EggShape().fill(LinearGradient(colors: [Color(hex: 0xfffaf0), Color(hex: 0xffe9bf)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ForEach(0..<5) { i in
                    Circle().fill([Theme.plum, Theme.tomato, Theme.sky, Theme.leaf, Theme.yolk][i].opacity(0.85))
                        .frame(width: size * 0.13)
                        .offset(x: size * [-0.18, 0.16, -0.05, 0.22, -0.2][i], y: size * [-0.18, -0.05, 0.12, 0.25, 0.2][i])
                }
                if cracks > 0 { CrackShape(stage: cracks).stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)) }
                EggShape().stroke(Theme.ink, lineWidth: max(2.5, size * 0.04))
            }
            .frame(width: size * 0.78, height: size)
            .rotationEffect(.degrees(w), anchor: .bottom)
        }
        .frame(width: size * 0.78, height: size)
    }
}

struct CrackShape: Shape {
    let stage: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.minY + r.height * 0.45
        let pts: [CGFloat] = [0.08, 0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.92]
        let count = min(pts.count, stage * 3 + 1)
        p.move(to: CGPoint(x: r.minX + r.width * 0.04, y: y))
        for (i, x) in pts.prefix(count).enumerated() {
            p.addLine(to: CGPoint(x: r.minX + r.width * x, y: y + (i % 2 == 0 ? -r.height * 0.06 : r.height * 0.05)))
        }
        return p
    }
}

struct SkinCard: View {
    let skin: Skin
    let image: UIImage?
    let owned: Bool
    let selected: Bool
    let focused: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: skin.rarity.color).opacity(owned ? 0.28 : 0.14))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                        .saturation(owned ? 1 : 0.15)
                        .opacity(owned ? 1 : 0.75)
                } else {
                    ProgressView()
                }
                if !owned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Theme.ink.opacity(0.75)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            Text(skin.name)
                .font(Theme.font(13, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Group {
                if selected {
                    Label("Giyildi", systemImage: "checkmark").font(Theme.font(12, .heavy)).foregroundStyle(Theme.leafDark)
                } else if owned {
                    Text("Senin").font(Theme.font(12, .heavy)).foregroundStyle(Theme.ink.opacity(0.5))
                } else {
                    HStack(spacing: 3) {
                        CoinIcon(size: 13)
                        Text("\(skin.price)").font(Theme.font(12, .heavy)).foregroundStyle(Theme.ink).monospacedDigit()
                    }
                }
            }
            .frame(height: 16)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(focused ? Theme.tomato : Theme.ink, lineWidth: focused ? 4 : 2.5))
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.ink).offset(y: 4))
        .scaleEffect(focused ? 1.04 : 1)
    }
}

// MARK: - Egg reveal

struct EggRevealView: View {
    let skin: Skin
    let image: UIImage?
    let onWear: () -> Void
    let onClose: () -> Void

    @State private var cracks = 0
    @State private var opened = false
    @State private var spin = false
    @State private var bounce = false

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.7).ignoresSafeArea()
                .onTapGesture { if !opened { tap() } }

            if opened {
                Color.clear
                    .overlay {
                        Rays(color: Color(hex: skin.rarity.color))
                            .frame(width: 560, height: 560)
                            .rotationEffect(.degrees(spin ? 360 : 0))
                            .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: spin)
                            .opacity(0.8)
                    }
                    .allowsHitTesting(false)
                ConfettiView().allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                if opened {
                    OutlinedText(text: "YENİ KOSTÜM!", size: 36, fill: Theme.yolk, width: 4)
                    ZStack {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 230, height: 230)
                        }
                    }
                    .scaleEffect(bounce ? 1 : 0.2)
                    VStack(spacing: 4) {
                        Text(skin.name).font(Theme.font(30)).foregroundStyle(.white)
                        Text(skin.rarity.rawValue.uppercased(with: Locale(identifier: "tr")))
                            .font(Theme.font(13, .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: skin.rarity.color)))
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                    }
                    HStack(spacing: 14) {
                        Button(action: onClose) { Text("Tamam").font(Theme.font(19)).frame(width: 100, height: 30) }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.paper, dark: Color(hex: 0xd9ccb3)))
                        Button(action: onWear) { Text("HEMEN GİY").font(Theme.font(19)).frame(width: 140, height: 30) }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark))
                    }
                    .padding(.top, 8)
                } else {
                    Text("Kırmak için dokun!")
                        .font(Theme.font(22))
                        .foregroundStyle(.white)
                    WobblyEgg(size: 210, wobble: true, cracks: cracks)
                        .scaleEffect(1 + CGFloat(cracks) * 0.06)
                        .onTapGesture { tap() }
                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in
                            Circle().fill(i < cracks ? Theme.yolk : .white.opacity(0.3)).frame(width: 12)
                        }
                    }
                }
            }
        }
    }

    private func tap() {
        Haptics.hit()
        Audio.shared.play(.crack)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { cracks += 1 }
        if cracks >= 3 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                Audio.shared.play(.unlock)
                Haptics.success()
                withAnimation(.spring(response: 0.4)) { opened = true }
                spin = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1)) { bounce = true }
            }
        }
    }
}

struct Rays: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let n = 14
            for i in 0..<n {
                let a0 = Double(i) / Double(n) * 2 * .pi
                let a1 = a0 + .pi / Double(n)
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a0) * size.width, y: c.y + sin(a0) * size.width))
                p.addLine(to: CGPoint(x: c.x + cos(a1) * size.width, y: c.y + sin(a1) * size.width))
                p.closeSubpath()
                ctx.fill(p, with: .color(color.opacity(0.35)))
            }
        }
        .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 280))
    }
}

struct ConfettiView: View {
    struct Bit: Identifiable { let id = UUID(); let x: CGFloat; let delay: Double; let color: Color; let spin: Double; let w: CGFloat }
    @State private var bits: [Bit] = (0..<60).map { _ in
        Bit(x: .random(in: 0...1), delay: .random(in: 0...0.6),
            color: [Theme.yolk, Theme.tomato, Theme.sky, Theme.leaf, Theme.plum, .white].randomElement()!,
            spin: .random(in: -720...720), w: .random(in: 7...12))
    }
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ForEach(bits) { b in
                RoundedRectangle(cornerRadius: 2)
                    .fill(b.color)
                    .frame(width: b.w, height: b.w * 0.6)
                    .rotationEffect(.degrees(fall ? b.spin : 0))
                    .position(x: b.x * geo.size.width, y: fall ? geo.size.height + 40 : -30)
                    .animation(.easeIn(duration: 2.2).delay(b.delay), value: fall)
            }
        }
        .ignoresSafeArea()
        .onAppear { fall = true }
    }
}

// MARK: - Daily gift

struct GiftView: View {
    let onClaim: () -> Int
    let onClose: () -> Void

    @State private var amount: Int?
    @State private var lid = false
    @State private var shake = false

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.7).ignoresSafeArea()
            if amount != nil {
                Color.clear.overlay { Rays(color: Theme.yolk).frame(width: 560, height: 560).opacity(0.8) }.allowsHitTesting(false)
                ConfettiView().allowsHitTesting(false)
            }
            VStack(spacing: 20) {
                OutlinedText(text: amount == nil ? "HEDİYE!" : "+\(amount!)", size: 44, fill: Theme.yolk, width: 4)
                ZStack {
                    if let _ = amount {
                        HStack(spacing: -8) {
                            ForEach(0..<5) { i in
                                CoinIcon(size: 46).offset(y: i % 2 == 0 ? -10 : 6)
                            }
                        }
                        .offset(y: -100)
                        .transition(.scale.combined(with: .move(edge: .bottom)))
                    }
                    giftBox
                }
                .frame(height: 220)
                if amount == nil {
                    Text("Açmak için dokun!").font(Theme.font(20)).foregroundStyle(.white)
                } else {
                    Button(action: onClose) { Text("TOPLA").font(Theme.font(24)).frame(width: 170, height: 36) }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark))
                }
            }
        }
        .onTapGesture { open() }
        .onAppear { shake = true }
    }

    private var giftBox: some View {
        ZStack {
            // box
            RoundedRectangle(cornerRadius: 14).fill(Theme.tomato)
                .overlay(Rectangle().fill(Theme.yolk).frame(width: 30))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 4))
                .frame(width: 150, height: 120)
                .offset(y: 40)
            // lid
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xff7468))
                    .overlay(Rectangle().fill(Theme.yolk).frame(width: 30))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 4))
                    .frame(width: 172, height: 40)
                HStack(spacing: 0) {
                    Ellipse().fill(Theme.yolk).overlay(Ellipse().stroke(Theme.ink, lineWidth: 4)).frame(width: 52, height: 34).rotationEffect(.degrees(-20))
                    Ellipse().fill(Theme.yolk).overlay(Ellipse().stroke(Theme.ink, lineWidth: 4)).frame(width: 52, height: 34).rotationEffect(.degrees(20))
                }
                .offset(y: -30)
            }
            .offset(x: lid ? 120 : 0, y: lid ? -150 : -40)
            .rotationEffect(.degrees(lid ? 40 : 0))
            .opacity(lid ? 0 : 1)
        }
        .rotationEffect(.degrees(amount == nil && shake ? 4 : -4), anchor: .bottom)
        .animation(amount == nil ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: shake)
    }

    private func open() {
        guard amount == nil else { return }
        Haptics.success()
        Audio.shared.play(.gift)
        let a = onClaim()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            lid = true
            amount = a
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Bindable var store: GameStore
    let ads: Ads
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                HStack {
                    OutlinedText(text: "AYARLAR", size: 32, fill: Theme.sky, width: 3.5)
                    Spacer()
                    RoundIconButton(systemName: "xmark", size: 44, action: onClose)
                }
                toggle("Ses efektleri", icon: "speaker.wave.2.fill", isOn: $store.sfxOn)
                toggle("Müzik", icon: "music.note", isOn: $store.musicOn)
                toggle("Titreşim", icon: "iphone.radiowaves.left.and.right", isOn: $store.hapticsOn)
                VStack(spacing: 4) {
                    Text("Tavviq 1.0")
                        .font(Theme.font(15, .heavy))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                    Text("Bütün modeller, sesler ve müzik kodla üretildi.\nHiçbir tavuk zarar görmedi. Çoğunlukla.")
                        .font(Theme.font(12, .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink.opacity(0.45))
                }
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .cardStyle()
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func toggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            Audio.shared.play(.pop, volume: 0.6)
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .frame(width: 30)
                Text(title).font(Theme.font(18, .heavy))
                Spacer()
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule().fill(isOn.wrappedValue ? Theme.leaf : Color(hex: 0xd8d2c4))
                        .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
                        .frame(width: 58, height: 32)
                    Circle().fill(.white).overlay(Circle().stroke(Theme.ink, lineWidth: 2.5))
                        .frame(width: 26).padding(.horizontal, 3)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isOn.wrappedValue)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xf6efe0)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }
}
