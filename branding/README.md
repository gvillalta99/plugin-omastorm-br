# Omastorm branding

Status 2026-09-06: **the mark is chosen, provisionally.** Typography is open.

![The omastorm mark](mark.png)

## The mark

A miniature of the app view, framed like the window:

- a 1 px rounded-corner frame,
- two thin range rings, the inner at 6 and the outer at 11 grid units,
- the site crosshair at the center,
- one squall line running southwest to northeast just off the site, drawn in the
  Glyphs density treatment the app uses (100 / 78 / 44 / 22 % from core to
  fringe) in the app's reflectivity colors: red, yellow, green, teal.

Colors were sampled from the running app in the warm dark theme. Ground
`#2d2626`, foreground `#e7d6d3`, accent coral `#f18b6d`. The one-color versions
carry the storm as opacity steps only, so they inherit any theme foreground.

Two grids. The 31 px grid is the master and is used at 128 px and above. A 16 px
grid, built the same way with one ring and a 2 px site, is used at 64, 48, 32,
and 16 px, where 31 would scale unevenly. Both come from one script:

```
python3 branding/mark.py     # regenerates mark/ and mark.png
```

`mark/` holds the exports: SVG per treatment (`app`, `app-light`, `mono-dark`,
`mono-light`, `accent`) for both grids, a transparent `mono` SVG for each grid,
and PNGs at 512, 256, 128 from the 31 grid and 64, 48, 32, 16 from the 16 grid.

Known limits. 512, 256, and 128 px PNGs from the 31 grid have cells of uneven
width by one device pixel, invisible at 512 and faint at 128. If the mark ships
in a place where that matters, export at 496 or 248 instead, which are exact
multiples. The 16 px version reads as a framed ring with a diagonal return; the
crosshair and density steps do not survive that size.

## Lockup

In the app header the mark replaces the diamond glyph before `OMASTORM`, at
16 px beside 14 px letter-spaced JetBrains Mono, as shown on the sheet. No
wordmark font has been chosen; the sheet uses the app's UI font.

## Decisions that shaped it

- The mark should look like the product, not like a generic radar or a mascot.
  Rings, crosshair, dashed nominal ring, and stipple storms are all things the
  real view draws. Photo-realistic or arcade storm shapes were rejected.
- Storm placement follows real motion: squall lines lie southwest to northeast
  and move east or southeast. Random placement read as random.
- Not RadarScope. No hook echo on a circular scope; the square frame, pixel
  rings, and density storm keep this its own thing.
- Rings must be visible at icon size. The app's 30 % ring opacity vanishes
  below 64 px, so the mark uses 50 %.
- Ring weights and storm shape variations were tried (tapered line, bow echo,
  compact cell, heavier inner or outer ring, three rings). The plain version was
  kept for now.

## Next

1. Live with the mark in the header and as the launcher icon for a while.
2. Choose a wordmark font and verify its license, or keep the UI font.
3. If the mark survives, cut a 24 px grid for tray sizes between 16 and 32.
