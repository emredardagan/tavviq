import SwiftUI

struct HUDView: View {
    let game: GameController
    let store: GameStore

    @State private var bannerShown: (title: String, sub: String, id: Int)?
    @State private var bestToast = false
    @State private var scorePop = false

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: -2) {
                    OutlinedText(text: "\(game.score)", size: 58, width: 4)
                        .scaleEffect(scorePop ? 1.12 : 1, anchor: .bottomLeading)
                    if store.best > 0 {
                        Text("EN İYİ \(max(store.best, game.score))")
                            .font(Theme.font(14, .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: Theme.ink, radius: 0, x: 1.5, y: 1.5)
                            .padding(.leading, 4)
                    }
                }
                .allowsHitTesting(false)
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    CoinPill(amount: store.coins).allowsHitTesting(false)
                    RoundIconButton(systemName: "pause.fill", size: 46) { game.pause() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            if let b = bannerShown {
                VStack(spacing: 6) {
                    Ribbon(text: b.title.uppercased(with: Locale(identifier: "tr")), color: Theme.plum, dark: Theme.plumDark)
                    Text(b.sub)
                        .font(Theme.font(15, .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink, radius: 0, x: 1.5, y: 1.5)
                }
                .padding(.top, 130)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
                .id(b.id)
                .allowsHitTesting(false)
            }

            if bestToast {
                Ribbon(text: "YENİ REKOR!", color: Theme.yolk, dark: Theme.yolkDark)
                    .padding(.top, 200)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: game.score) { _, _ in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { scorePop = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.2)) { scorePop = false }
            }
        }
        .onChange(of: game.banner?.id) { _, _ in
            guard let b = game.banner else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { bannerShown = b }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeIn(duration: 0.25)) { if bannerShown?.id == b.id { bannerShown = nil } }
            }
        }
        .onChange(of: game.newBest) { _, v in
            guard v else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { bestToast = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { bestToast = false }
            }
        }
    }
}

struct PauseView: View {
    let onResume: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 18) {
                OutlinedText(text: "MOLA", size: 46, fill: Theme.yolk, width: 4)
                Text("Tavuk nefesleniyor...")
                    .font(Theme.font(17, .heavy))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Button(action: onResume) {
                    Label("DEVAM", systemImage: "play.fill")
                        .font(Theme.font(24))
                        .frame(width: 200, height: 40)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark))
                Button(action: onHome) {
                    Label("Ana Menü", systemImage: "house.fill")
                        .font(Theme.font(18, .heavy))
                        .frame(width: 200, height: 30)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.paper, dark: Color(hex: 0xd9ccb3)))
            }
            .padding(28)
            .cardStyle()
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }
}

struct GameOverView: View {
    let game: GameController
    let store: GameStore
    let ads: Ads
    let onRetry: () -> Void
    let onHome: () -> Void
    let onShop: () -> Void

    @State private var shown = false
    @State private var countUp = 0
    @State private var doubled = false

    private var showContinue: Bool {
        game.canContinue && game.score >= Ads.Rules.continueMinScore && ads.rewardedReady
    }
    private var showDouble: Bool { !doubled && game.runCoins > 0 && ads.rewardedReady }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink.opacity(0.15), Theme.ink.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .opacity(shown ? 1 : 0)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    CoinPill(amount: store.coins)
                }
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer(minLength: 10)

                VStack(spacing: 10) {
                    OutlinedText(text: game.death.title, size: 40, fill: Theme.tomato, width: 4)
                        .rotationEffect(.degrees(-3))
                        .padding(.top, 4)
                    Text(game.deathLine)
                        .font(Theme.font(16, .heavy))
                        .foregroundStyle(Theme.ink.opacity(0.65))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        stat(title: "SKOR", value: "\(countUp)", big: true)
                        stat(title: "EN İYİ", value: "\(store.best)", big: false)
                    }
                    .padding(.top, 6)

                    if game.newBest {
                        Ribbon(text: "YENİ REKOR!", color: Theme.yolk, dark: Theme.yolkDark)
                            .modifier(Wiggle())
                            .padding(.vertical, 4)
                    }

                    HStack(spacing: 6) {
                        CoinIcon(size: 20)
                        Text("+\(doubled ? game.runCoins * 2 : game.runCoins) jeton bu turda\(doubled ? " (2×)" : "")")
                            .font(Theme.font(15, .heavy))
                            .foregroundStyle(Theme.ink.opacity(0.75))
                    }
                    .padding(.top, 2)

                    if store.coins >= GameStore.eggPrice && !store.unownedSkins.isEmpty {
                        Button(action: onShop) {
                            HStack(spacing: 8) {
                                EggShape().fill(Color(hex: 0xfff3d6)).overlay(EggShape().stroke(Theme.ink, lineWidth: 2.5))
                                    .frame(width: 18, height: 23)
                                Text("Yumurta kırabilirsin!")
                                    .font(Theme.font(14, .heavy))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Color(hex: 0xffe7a3), dark: Theme.yolkDark, radius: 16, depth: 4))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 22)
                .frame(maxWidth: 340)
                .cardStyle()
                .padding(.horizontal, 24)
                .offset(y: shown ? 0 : -700)
                .rotationEffect(.degrees(shown ? 0 : -8))

                Spacer(minLength: 10)

                VStack(spacing: 14) {
                    if showContinue || showDouble {
                        HStack(spacing: 12) {
                            if showContinue {
                                adButton(icon: "heart.fill", title: "Devam Et") {
                                    ads.showRewarded { ok in if ok { game.revive() } }
                                }
                            }
                            if showDouble {
                                adButton(icon: "sparkles", title: "2× Jeton") {
                                    ads.showRewarded { ok in
                                        guard ok else { return }
                                        store.coins += game.runCoins
                                        Audio.shared.play(.coin)
                                        withAnimation(.spring(response: 0.3)) { doubled = true }
                                    }
                                }
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    Button(action: onRetry) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 24, weight: .black))
                            Text("TEKRAR").font(Theme.font(30))
                        }
                        .frame(width: 220, height: 46)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.leaf, dark: Theme.leafDark, radius: 26, depth: 7))

                    HStack(spacing: 14) {
                        MenuTile(icon: "house.fill", title: "Menü", color: Theme.sky, dark: Theme.skyDark, action: onHome)
                        MenuTile(icon: "bag.fill", title: "Kümes", color: Theme.tomato, dark: Theme.tomatoDark, action: onShop)
                    }
                }
                .padding(.bottom, 150)
                .offset(y: shown ? 0 : 400)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.66)) { shown = true }
            let target = game.score
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                let steps = min(target, 30)
                guard steps > 0 else { return }
                for i in 1...steps {
                    countUp = target * i / steps
                    if i % 3 == 0 { Audio.shared.play(.tap, volume: 0.3) }
                    try? await Task.sleep(for: .milliseconds(28))
                }
            }
        }
    }

    private func adButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 17, weight: .black))
                VStack(alignment: .leading, spacing: -2) {
                    Text(title).font(Theme.font(17))
                    HStack(spacing: 3) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 10, weight: .bold))
                        Text("reklam izle").font(Theme.font(11, .heavy))
                    }
                    .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 128, height: 38)
        }
        .buttonStyle(ChunkyButtonStyle(color: Theme.plum, dark: Theme.plumDark, radius: 20, depth: 5))
    }

    private func stat(title: String, value: String, big: Bool) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Theme.font(13, .heavy))
                .foregroundStyle(Theme.ink.opacity(0.55))
            Text(value)
                .font(Theme.font(big ? 46 : 30))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: big ? 128 : 100, height: 86)
        .background(RoundedRectangle(cornerRadius: 18).fill(big ? Color(hex: 0xfff0c4) : Color(hex: 0xf3ead8)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: 2.5))
    }
}
