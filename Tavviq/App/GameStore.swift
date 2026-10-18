import Foundation
import Observation

/// Everything that survives a relaunch: coins, best score, owned skins, settings, gift timer.
@Observable
final class GameStore {
    static let shared = GameStore()

    private let d = UserDefaults.standard

    var coins: Int { didSet { d.set(coins, forKey: "coins") } }
    var best: Int { didSet { d.set(best, forKey: "best") } }
    var owned: Set<String> { didSet { d.set(Array(owned), forKey: "owned") } }
    var selected: String { didSet { d.set(selected, forKey: "selected") } }
    var runs: Int { didSet { d.set(runs, forKey: "runs") } }
    var sfxOn: Bool { didSet { d.set(sfxOn, forKey: "sfx"); Audio.shared.sfxOn = sfxOn } }
    var musicOn: Bool { didSet { d.set(musicOn, forKey: "music"); Audio.shared.musicOn = musicOn } }
    var hapticsOn: Bool { didSet { d.set(hapticsOn, forKey: "haptics"); Haptics.on = hapticsOn } }
    var lastGift: Date { didSet { d.set(lastGift, forKey: "lastGift") } }
    private var adRewardDay: String { didSet { d.set(adRewardDay, forKey: "adRewardDay") } }
    private var adRewardCount: Int { didSet { d.set(adRewardCount, forKey: "adRewardCount") } }

    static let giftInterval: TimeInterval = 6 * 3600
    static let eggPrice = 100

    private init() {
        d.register(defaults: ["sfx": true, "music": true, "haptics": true, "selected": "tavviq", "coins": 0])
        coins = d.integer(forKey: "coins")
        best = d.integer(forKey: "best")
        owned = Set((d.array(forKey: "owned") as? [String]) ?? ["tavviq"]).union(["tavviq"])
        selected = d.string(forKey: "selected") ?? "tavviq"
        runs = d.integer(forKey: "runs")
        sfxOn = d.bool(forKey: "sfx")
        musicOn = d.bool(forKey: "music")
        hapticsOn = d.bool(forKey: "haptics")
        lastGift = (d.object(forKey: "lastGift") as? Date) ?? .distantPast
        adRewardDay = d.string(forKey: "adRewardDay") ?? ""
        adRewardCount = d.integer(forKey: "adRewardCount")
        Audio.shared.sfxOn = sfxOn
        Audio.shared.musicOn = musicOn
        Haptics.on = hapticsOn
        #if DEBUG
        // launch with `-debugCoins N` to test the shop
        let extra = d.integer(forKey: "debugCoins")
        if extra > 0 { coins = extra }
        // `-debugOwned "kovboy,horoz"` and `-debugSkin kovboy` for shop screenshots
        if let list = d.string(forKey: "debugOwned") {
            owned.formUnion(list.split(separator: ",").map(String.init))
        }
        if let s = d.string(forKey: "debugSkin"), Skins.all.contains(where: { $0.id == s }) {
            owned.insert(s); selected = s
        }
        #endif
    }

    var skin: Skin { Skins.skin(selected) }

    private static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: .now)
    }

    /// Rewarded "+15 coins" ads left in the shop today.
    var shopAdsLeft: Int {
        adRewardDay == Self.today() ? max(0, Ads.Rules.shopRewardsPerDay - adRewardCount) : Ads.Rules.shopRewardsPerDay
    }

    func grantShopAdReward() {
        if adRewardDay != Self.today() { adRewardDay = Self.today(); adRewardCount = 0 }
        adRewardCount += 1
        coins += Ads.Rules.shopReward
    }

    func giftReady(at now: Date = .now) -> Bool { now.timeIntervalSince(lastGift) >= Self.giftInterval }
    func giftRemaining(at now: Date = .now) -> TimeInterval { max(0, Self.giftInterval - now.timeIntervalSince(lastGift)) }

    func claimGift() -> Int {
        let amount = [40, 50, 60, 75, 80, 100, 120].randomElement()!
        coins += amount
        lastGift = .now
        return amount
    }

    func buy(_ s: Skin) -> Bool {
        guard !owned.contains(s.id), coins >= s.price else { return false }
        coins -= s.price
        owned.insert(s.id)
        selected = s.id
        return true
    }

    var unownedSkins: [Skin] { Skins.all.filter { !owned.contains($0.id) } }

    /// Spends `eggPrice` and unlocks a random unowned skin, rarer ones less often.
    func crackEgg() -> Skin? {
        let pool = unownedSkins
        guard !pool.isEmpty, coins >= Self.eggPrice else { return nil }
        let weights = pool.map { s -> Double in
            switch s.rarity { case .common: return 5; case .rare: return 3; case .epic: return 1.6; case .legend: return 0.7 }
        }
        var r = Double.random(in: 0..<weights.reduce(0, +))
        var pick = pool[0]
        for (s, w) in zip(pool, weights) {
            if r < w { pick = s; break }
            r -= w
        }
        coins -= Self.eggPrice
        owned.insert(pick.id)
        return pick
    }
}
