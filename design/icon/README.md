App icon: a cream Georgia Bold "R" (#F9F0E3) over a gold waveform (#E9B96E) on brown #7B4B34; Perry approved option A.
`_gen_icon.py` is the Pillow script that drew it (renders at 3x, downsamples to 1024x1024 RGB with no alpha; needs `C:/Windows/Fonts/georgiab.ttf`).
The shipped file is `Retold/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`; regenerate there and keep it RGB (App Store rejects alpha).
