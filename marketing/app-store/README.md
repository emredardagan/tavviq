# App Store görselleri

App Store Connect'te hangi klasör hangi yuvaya yüklenir:

| App Store Connect yuvası | Klasör | Boyut |
| --- | --- | --- |
| **iPhone with Dynamic Island (medium display)**, zorunlu | `screenshots/<dil>/6.3` | 1206×2622 |
| iPhone with Dynamic Island (large display) | `screenshots/<dil>/6.9` | 1320×2868 |
| iPhone with Face ID (large display) | `screenshots/<dil>/6.5` | 1284×2778 |
| App Preview (tüm iPhone yuvaları) | `preview/tavviq-preview-6.9.mp4` | 886×1920 |

Bir yuva yalnızca kendi boyutlarını kabul eder. Örneğin 6.9" görselleri zorunlu (medium) yuvaya yüklemek boyut hatası verir ve "asset best practices" sayfasına yönlendirir.

- **Görseller:** PNG, 8-bit RGB, sRGB, alfa kanalı yok. Dil başına 7 adet (`tr`, `en`).
- **Video:** H.264 High Profile 4.0, 30 fps, yaklaşık 10 Mbps; ses stereo AAC 256 kbps, 44.1 kHz; 25.4 sn. Apple sesi 256 kbps AAC istiyor; `make_preview.swift` sesi bu yüzden son adımda yeniden kodluyor.

## Yeniden üretmek

1. Debug derlemeyi iPhone 17 Pro Max simülatörüne kur.
2. Oyun içi kareler ve video için otomatik oynayan demo modunu aç:
   ```bash
   xcrun simctl io booted recordVideo --codec=h264 raw.mov
   ```
   ```bash
   xcrun simctl launch booted com.emredardagan.tavviq -noAds YES -demo YES -demoSeconds 23
   ```
3. Mağaza ekranları için: `-noAds YES -debugCoins 1250 -debugOwned "civciv,kovboy,horoz,ninja,parti,havali" -debugSkin kral`
4. Ham kareleri (`home`, `play`, `autumn`, `neon`, `shop`, `egg`, `record` adlı 1320×2868 PNG'ler) bir klasöre koy ve görselleri üret:
   ```bash
   swift tools/make_screenshots.swift <ham-klasör> marketing/app-store/screenshots
   ```
5. Videoyu kes, boyutlandır ve müziği ekle (müzik stereo olmalı):
   ```bash
   afconvert -f m4af -d aac -c 2 -b 256000 Tavviq/Resources/Sounds/music.m4a music-stereo.m4a
   ```
   ```bash
   swift tools/make_preview.swift raw.mov music-stereo.m4a marketing/app-store/preview/tavviq-preview-6.9.mp4 2.4-4.8 4.8-16 25.5-37.3
   ```
6. Var olan bir videonun yalnızca sesini düzeltmek için:
   ```bash
   swift tools/make_preview.swift --fix-audio eski.mp4 yeni.mp4
   ```

Başlıklar ve renkler `tools/make_screenshots.swift` içindeki `slides` listesinde.
