App icon: the family-line replay loop around three voice bars, terracotta `#E07A50` on house ink `#16211C` (Perry, 2026-10-21).
Source of truth is `brand/marks/apps/retold.svg`; generate with `node scripts/gen-icons.mjs --app retold` in the brand repo and copy
`dist/icons/apps/retold/ios/AppIcon.appiconset/Icon-ios-marketing-1024x1024@1x.png` to `Retold/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
(1024x1024 RGB, no alpha; App Store rejects alpha).

The previous icon, a cream Georgia Bold "R" (#F9F0E3) over a gold waveform (#E9B96E) on brown #7B4B34, is kept for other branding
(for example iPhone Duo material). `_gen_icon.py` is the Pillow script that draws it (needs `C:/Windows/Fonts/georgiab.ttf`).
