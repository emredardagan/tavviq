# Tavviq

Native iOS (SwiftUI + SceneKit) yol geçme oyunu. Eski three.js tabanlı Paw Crossing'in yerine yazıldı: WebView yok, her şey Metal üzerinde native render ediliyor.

## Çalıştırma

`Tavviq.xcodeproj` dosyasını Xcode ile aç, bir iPhone simülatörü seç ve Run'a bas. Gerçek cihaz için target ayarlarında **Signing & Capabilities → Team** seç.

Komut satırından:

```bash
tools/run_sim.sh <simulator-udid>
```

## Yapı

| Klasör | İçerik |
| --- | --- |
| `Tavviq/Game` | Oyun motoru: `GameController` (SceneKit render döngüsü, zıplama, çarpışma, kamera, ölüm animasyonları), `World` (şerit üretimi, her zaman geçilebilir bir yol garantisi), `WorldModels` (koddan üretilen voxel modeller), `Skins`, `Biomes` |
| `Tavviq/UI` | SwiftUI ekranlar: ana menü, HUD, oyun sonu, Kümes (mağaza), sürpriz yumurta, günlük hediye, ayarlar, maskot **Gıdık** |
| `Tavviq/Audio` | AVAudioEngine ile düşük gecikmeli efektler, döngüsel müzik, haptikler |
| `Tavviq/Resources/Sounds` | `tools/build_audio.sh` ile sentezlenen sesler |
| `tools` | Ses sentezleyici, ikon çizici, simülatör build scripti |

## Performans

- Tüm modeller paylaşılan geometri ve materyallerle kuruluyor; prototipler bir kez `flattenedClone` ile birleştirilip `clone()` ediliyor.
- Lambert ışıklandırma, tek yönlü gölgeli ışık, ortografik kamera, 60 fps.
- Oyun mantığı SceneKit'in render thread'inde çalışıyor; arayüz yalnızca değer değişince ana thread'e haber veriyor.

## Debug parametreleri (yalnızca geliştirme)

- `-debugZone N`: N. biyomdan başla (0 çayır, 1 sonbahar, 2 kar, 3 kumsal, 4 kanyon, 5 neon şehir)
- `-debugCoins N`: açılışta jeton sayısını N yap (yalnızca DEBUG derleme)

```bash
xcrun simctl launch booted com.emredardagan.tavviq -debugZone 5 -debugCoins 1000
```

## Sesleri yeniden üretmek

```bash
tools/build_audio.sh
```

## Reklamlar (AdMob)

Google Mobile Ads 13.x + User Messaging Platform 3.x, Swift Package Manager ile ekli. Tüm reklam kodu [Ads.swift](Tavviq/Ads/Ads.swift) içinde.

| Yer | Tür | Kural |
| --- | --- | --- |
| Oyun sonu: **Devam Et** | Ödüllü | Turda 1 kez, skor ≥ 10; son güvenli çimende 2.5 sn dokunulmazlıkla dirilir |
| Oyun sonu: **2× Jeton** | Ödüllü | Turda 1 kez, o turda jeton toplandıysa |
| Kümes: **Bedava Jeton** | Ödüllü | +15 jeton, günde en fazla 5 |
| Oyun sonu → Tekrar / Menü | Geçiş | İlk 3 turda yok; sonra 3 turda bir, en az 120 sn arayla; o ekranda ödüllü izlendiyse atlanır |

Koşu sırasında asla reklam çıkmaz. Reklam açıkken oyun sesi kısılır. Kurallar `Ads.Rules` içinde.

Tavviq bir çocuk oyunu: her reklam isteği `tagForChildDirectedTreatment` ve `tagForUnderAgeOfConsent` ile işaretlenir, içerik derecesi G ile sınırlıdır. Kişiselleştirilmiş reklam, IDFA, ATT izni ve UMP onay formu yoktur.

### Yayından önce

1. AdMob'da iOS uygulaması ve iki reklam birimi (Ödüllü, Geçiş) oluştur.
2. Proje ayarlarında **Release** yapılandırmasındaki `GAD_APP_ID` değerini gerçek uygulama kimliğiyle değiştir (şu an Google'ın test kimliği).
3. `Ads.Units` içindeki `#else` dalına gerçek reklam birimi kimliklerini yaz.
4. AdMob → Privacy & messaging: GDPR mesajı (ve istersen IDFA açıklaması) oluştur.
5. AdMob'da maksimum içerik derecesini **G** yap, hassas kategorileri engelle. Kod tarafında `maxAdContentRating = .general` zaten ayarlı.
6. `app-ads.txt` dosyasını geliştirici web sitende yayınla.
