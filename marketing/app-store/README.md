# App Store görselleri

| Klasör | İçerik |
| --- | --- |
| `screenshots/tr/6.9`, `screenshots/en/6.9` | 7 ekran görüntüsü, 1320×2868 (iPhone 6.9"), PNG, alfasız |
| `screenshots/tr/6.5`, `screenshots/en/6.5` | Aynı set, 1284×2778 (iPhone 6.5") |
| `preview/tavviq-preview-6.9.mp4` | App Preview: 886×1920, 30 fps, H.264, stereo AAC, 25.4 sn |

App Store Connect'te 6.9" seti yeterli; 6.5" isteğe bağlı. Önizleme videosu 6.9" ve 6.5" ekranlar için aynı dosyayla yüklenebilir.

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

Başlıklar ve renkler `tools/make_screenshots.swift` içindeki `slides` listesinde.
