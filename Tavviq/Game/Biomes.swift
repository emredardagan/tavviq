import SceneKit

enum RiverStyle { case logs, ice, boats }

struct Biome {
    let name: String
    let sub: String
    let grass: (UInt32, UInt32)
    let road: UInt32
    let water: UInt32
    let sky: UInt32
    let sun: UInt32
    let sunIntensity: CGFloat
    let ambient: UInt32
    let ambientIntensity: CGFloat
    let river: RiverStyle
    let night: Bool
    let carColors: [UInt32]
    let mascotLine: String
}

enum Biomes {
    static let zoneLength = 40

    static let all: [Biome] = [
        Biome(name: "Güneşli Çayır", sub: "Her şeyin başladığı yer",
              grass: (0x9ad65c, 0x8fcc53), road: 0x545966, water: 0x4cc4ff, sky: 0x8fd8ff,
              sun: 0xfff3dc, sunIntensity: 1350, ambient: 0xb6cff2, ambientIntensity: 520,
              river: .logs, night: false,
              carColors: [0xff5a4e, 0x3d8bff, 0xffc93c, 0x8a5cff, 0x2fc99a, 0xff8a3d, 0xf4f4f4],
              mascotLine: "Çayır kokusu! Bir de egzoz."),
        Biome(name: "Sonbahar Ormanı", sub: "Yapraklar düşüyor, sen düşme",
              grass: (0xe8b552, 0xdda848), road: 0x5b5560, water: 0x3fb3e8, sky: 0xffd9a8,
              sun: 0xffe2b8, sunIntensity: 1300, ambient: 0xe8c9a8, ambientIntensity: 520,
              river: .logs, night: false,
              carColors: [0xb5452f, 0x2f6b4f, 0xe39a2d, 0x6b3f2a, 0xf2e6c9],
              mascotLine: "Balkabağı mevsimi geldi!"),
        Biome(name: "Karlı Geçit", sub: "Brrr! Göl buz tuttu",
              grass: (0xf3f7fc, 0xe7eef7), road: 0x5f6573, water: 0x7fd0f2, sky: 0xcfe6ff,
              sun: 0xf3f8ff, sunIntensity: 1250, ambient: 0xc7d8f0, ambientIntensity: 600,
              river: .ice, night: false,
              carColors: [0xe63946, 0x1d3557, 0x2a9d8f, 0xf1faee, 0x457b9d],
              mascotLine: "Tüylerim dondu! Hızlı zıpla!"),
        Biome(name: "Altın Kumsal", sub: "Dalga sesi, korna sesi",
              grass: (0xf7e3a6, 0xf0d896), road: 0x5d5f68, water: 0x2fd3e0, sky: 0x9ef0ff,
              sun: 0xfff6e0, sunIntensity: 1400, ambient: 0xbfe8ef, ambientIntensity: 520,
              river: .boats, night: false,
              carColors: [0xff6fa3, 0x2fc9d8, 0xffd23c, 0xff8a3d, 0xffffff],
              mascotLine: "Kumsal! Ben güneş kremini unuttum."),
        Biome(name: "Kaktüs Kanyonu", sub: "Sıcak, kuru ve dikenli",
              grass: (0xeaa96b, 0xe09f61), road: 0x62574f, water: 0x41b8d8, sky: 0xffcf9a,
              sun: 0xffe6c4, sunIntensity: 1400, ambient: 0xe9b995, ambientIntensity: 500,
              river: .logs, night: false,
              carColors: [0xc94f2c, 0x3b6e8f, 0xe8c547, 0x7a4a2f, 0xece0c8],
              mascotLine: "Kaktüslere sarılma. Tecrübeyle sabit."),
        Biome(name: "Neon Şehir", sub: "Şehir hiç uyumaz",
              grass: (0x7d8296, 0x747a8e), road: 0x30333f, water: 0x2a5fc9, sky: 0x1f2350,
              sun: 0x9fb2ff, sunIntensity: 650, ambient: 0x6a6fc4, ambientIntensity: 520,
              river: .boats, night: true,
              carColors: [0xffd23c, 0xffd23c, 0xff3d8b, 0x3cf0ff, 0x2f3542, 0xffffff],
              mascotLine: "Şehrin ışıkları! Ve bir sürü taksi."),
    ]

    /// Debug only: launch with `-debugZone N` to start in zone N.
    #if DEBUG
    static let debugOffset = UserDefaults.standard.integer(forKey: "debugZone")
    #else
    static let debugOffset = 0
    #endif

    static func index(forLane lane: Int) -> Int {
        ((lane < 0 ? 0 : lane / zoneLength) + debugOffset) % all.count
    }

    static func biome(forLane lane: Int) -> Biome { all[index(forLane: lane)] }
}
