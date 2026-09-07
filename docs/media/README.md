# README media

The pictures the README shows are not in the repository. The plugin is a full
clone of this repository, so media travels as assets on the plugin's GitHub
Release (`v<version>`), and the README links to them by URL.

Regenerate from a working desktop OpenGL session:

```sh
bash scripts/capture-readme.sh   # window-live.png, popover.png (live KTLX)
bash scripts/capture-demo.sh     # omastorm-demo.mp4, omastorm-preview.gif, six treatment stills
bash scripts/capture-demo-live.sh   # omastorm-live-demo.mp4: one live take on KJAX, 1280×720, for the announcement
```

Both write into this directory, which is ignored except for this file. They
use isolated daemons and example theme files and change no desktop or system
configuration. FFmpeg is required; the demo also needs Ruby for its temporary
harness. The video is encoded at 30 fps and is not a latency measurement.

- `omastorm-demo.mp4`: 24 s, H.264, no audio. One continuous camera path per
  theme (dark 0–12 s, light 12–24 s), Glyphs then Pixels then Stipple.
- `omastorm-preview.gif`: a short Glyphs preview cut from the video.
- `{dark,light}-{glyphs,pixels,stipple}.png`: same-camera stills at the home
  view.
- `window-live.png`, `popover.png`: live KTLX with the actual scan time.

The demo and stills are **archived KTLX, 2013-05-20**, labeled ARCHIVED in the
window. Publish with `gh release upload v<version> docs/media/*` and keep the
README URLs pointing at that tag.

Radar: NOAA NEXRAD. Map: © OpenStreetMap contributors
([ODbL](https://opendatacommons.org/licenses/odbl/1-0/)); Natural Earth, public
domain.
