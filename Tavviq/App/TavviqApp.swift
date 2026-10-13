import SwiftUI

@main
struct TavviqApp: App {
    init() {
        // load saved settings first so the audio engine boots with the player's choices
        _ = GameStore.shared
        Audio.shared.boot()
        SkinThumbs.shared.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @State private var game = GameController()
    @State private var mascot = MascotDirector()
    @State private var store = GameStore.shared
    @State private var thumbs = SkinThumbs.shared
    @State private var ads = Ads.shared
    @State private var booted = false

    @State private var showShop = false
    @State private var showSettings = false
    @State private var showGift = false
    @State private var eggSkin: Skin?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            GameView(controller: game)
                .ignoresSafeArea()
            GameTouchLayer(controller: game)
                .ignoresSafeArea()

            Group {
                switch game.phase {
                case .home:
                    HomeView(store: store,
                             onPlay: { game.startRun() },
                             onShop: { open(shop: true) },
                             onGift: openGift,
                             onSettings: { withAnimation(.spring(response: 0.35)) { showSettings = true } })
                    .transition(.opacity)
                case .playing:
                    HUDView(game: game, store: store).transition(.opacity)
                case .paused:
                    HUDView(game: game, store: store)
                    PauseView(onResume: { game.resume() }, onHome: { game.goHome() })
                case .dead:
                    GameOverView(game: game, store: store, ads: ads,
                                 onRetry: { ads.leavingGameOver(store: store) { game.startRun() } },
                                 onHome: { ads.leavingGameOver(store: store) { game.goHome() } },
                                 onShop: { open(shop: true) })
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: game.phase)

            if showShop {
                ShopView(store: store, thumbs: thumbs,
                         onClose: { open(shop: false) },
                         onSelect: { s in
                             store.selected = s.id
                             game.setSkin(s)
                         },
                         onEgg: { s in
                             mascot.context = .modal
                             mascot.hide()
                             withAnimation(.spring(response: 0.35)) { eggSkin = s }
                         },
                         mascot: mascot,
                         ads: ads)
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }

            if showSettings {
                SettingsView(store: store, ads: ads) { withAnimation(.spring(response: 0.3)) { showSettings = false } }
                    .zIndex(3)
            }

            if showGift {
                GiftView(onClaim: { store.claimGift() }, onClose: {
                    withAnimation(.spring(response: 0.3)) { showGift = false }
                    mascot.context = .home
                    mascot.say("Afiyet olsun! Şimdi git harca onları.", edge: .trailing, mood: .laugh)
                })
                .transition(.opacity)
                .zIndex(4)
            }

            if let s = eggSkin {
                EggRevealView(skin: s, image: thumbs.images[s.id],
                              onWear: {
                                  store.selected = s.id
                                  game.setSkin(s)
                                  closeEgg(s)
                              },
                              onClose: { closeEgg(s) })
                .transition(.opacity)
                .zIndex(5)
            }

            MascotLayer(director: mascot, interactive: game.phase != .playing) {
                store.coins += 5
                Audio.shared.play(.coin)
                mascot.say("Tamam tamam! Al şu 5 jetonu, rahat bırak tüylerimi.", mood: .laugh, hold: 3.5)
            }
            .zIndex(10)
        }
        .onAppear {
            // full-screen ads make SwiftUI call onAppear again; only boot once
            guard !booted else { return }
            booted = true
            game.onEvent = handle
            ads.start()
            mascot.context = .home
            mascot.startChatter()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                mascot.say(store.runs == 0 ? "Merhaba! Ben Gıdık. Hadi yolun karşısına geçelim!" : "Tekrar hoş geldin! Hazır mısın?", edge: .leading)
            }
        }
        .onChange(of: game.phase) { _, p in
            switch p {
            case .home: mascot.context = showShop ? .shop : .home
            case .playing, .paused: mascot.context = .playing; mascot.hide()
            case .dead: mascot.context = .gameOver
            }
        }
        .onChange(of: scenePhase) { _, p in
            if p != .active { game.pause() }
        }
    }

    private func open(shop: Bool) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { showShop = shop }
        mascot.hide()
        mascot.context = shop ? .shop : (game.phase == .dead ? .gameOver : .home)
        if shop {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                mascot.say(MascotDirector.shopLines.randomElement()!, edge: .trailing, mood: .wink)
            }
        }
    }

    private func openGift() {
        if store.giftReady() {
            mascot.context = .modal
            mascot.hide()
            withAnimation(.spring(response: 0.35)) { showGift = true }
        } else {
            Audio.shared.play(.bump)
            mascot.say("Sabırlı ol! Hediye \(GiftTile.format(store.giftRemaining())) sonra hazır.", mood: .wink)
        }
    }

    private func closeEgg(_ s: Skin) {
        withAnimation(.spring(response: 0.3)) { eggSkin = nil }
        mascot.context = .shop
        mascot.say("\(s.name)! Ne kadar şık!", edge: .trailing, mood: .laugh)
    }

    private func handle(_ e: GameController.GameEvent) {
        switch e {
        case .zone(let b):
            mascot.say(b.mascotLine, edge: Bool.random() ? .leading : .trailing, mood: .surprised, hold: 2.6, sound: true)
        case .newBest:
            mascot.say("REKOR! Gıdaaak!", edge: Bool.random() ? .leading : .trailing, mood: .laugh, hold: 2.0)
        case .died(let kind):
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                let extra: String
                switch kind {
                case .water, .drift: extra = "Brr, ıslak tüy kokusu..."
                case .train: extra = "O tren benim de üstüme geliyordu!"
                case .eagle: extra = "Kartal! Hep o kartal!"
                case .car: extra = "Ah! Tüylerim yamyassı oldu."
                }
                mascot.say(Bool.random() ? extra : MascotDirector.deadLines.randomElement()!, edge: .bottom, mood: .sad, hold: 3.2)
            }
        case .coin:
            break
        }
    }
}
