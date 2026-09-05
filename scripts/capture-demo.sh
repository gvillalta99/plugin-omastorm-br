#!/usr/bin/env bash
# One continuous take of the engine-backed window per theme, plus same-camera
# treatment stills at home. Isolated daemon on the archived fixture; no
# system edits. Requires desktop OpenGL, Ruby, and FFmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p review
export OMASTORM_ARCHIVE=${OMASTORM_ARCHIVE:-$PWD/data/raw/KTLX20130520_201643_V06.gz} # the archived scan the checks assume
export OMASTORM_ROOT="$PWD"
demo_dir="$PWD/target/demo-capture"
scratch=$(mktemp -d /tmp/omastorm-demo.XXXXXX)
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_CACHE_HOME="$scratch/cache"
export OMASTORM_CONFIG="$demo_dir/none.toml"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME" "$demo_dir/shaders" docs/media
: > "$OMASTORM_CONFIG"
cleanup() { target/debug/omastorm-engine stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
cp ui/Theme.qml ui/Engine.qml ui/RadarMark.qml ui/RadarMap.qml ui/SitePicker.qml ui/Sites.js ui/KeysSheet.qml ui/Keys.js ui/Timeline.js ui/Config.qml ui/Toml.js "$demo_dir/"
cp ui/shaders/*.qsb "$demo_dir/shaders/"
ruby - "$demo_dir" <<'RUBY'
dir = ARGV.fetch(0)
s = File.read('ui/RadarWindow.qml').sub('Item {', 'ShellRoot {')
harness = <<'QML'
    Timer { interval: 500; running: true; repeat: true; onTriggered: if (app.scan && app.scan.scanTime) { running = false; waitTiles.start(); } }
    Timer { id: waitTiles; interval: 4000; onTriggered: demo.advance() }
    QtObject {
        id: demo
        property int still: 0
        property int frame: 0
        property bool filming: false
        function advance() {
            if (!app.scan || engine.error) throw new Error("Engine not ready: " + engine.error);
            if (!filming) {
                app.treatment = ["GLYPHS", "PIXELS", "STIPPLE"][still];
                map.reset();
                settle.start();
                return;
            }
            // One camera path; treatments change in place rather than resetting.
            app.treatment = frame < 120 ? "GLYPHS" : frame < 240 ? "PIXELS" : "STIPPLE";
            var t = frame / 359;
            var travel = Math.pow(Math.sin(Math.PI * t), 2);
            map.span = 210 - 95 * travel;
            map.look(map.siteMx + (-5 + 26 * travel) / map.kmPerUnit,
                     map.siteMy - (15 + 12 * travel) / map.kmPerUnit);
            settle.start();
        }
        function capture() {
            surface.grabToImage(result => {
                if (!filming) {
                    var names = ["glyphs", "pixels", "stipple"];
                    var path = Quickshell.env("OMASTORM_DEMO_STILLS") + "/" + names[still] + ".png";
                    if (!result.saveToFile(path)) throw new Error("Failed to save " + path);
                    still++;
                    if (still === 3) filming = true;
                    advance();
                    return;
                }
                var path = Quickshell.env("OMASTORM_DEMO_FRAMES") + "/" + String(frame).padStart(4, "0") + ".png";
                if (!result.saveToFile(path)) throw new Error("Failed to save " + path);
                frame++;
                if (frame === 360) { console.log("DEMO_CAPTURE_PASSED"); Qt.quit(); }
                else advance();
            });
        }
    }
    Timer { id: settle; interval: 32; onTriggered: demo.capture() }
QML
s.sub!('    id: app', "    id: app\n" + harness)
File.write(File.join(dir,'shell.qml'),s)
RUBY
export OMASTORM_QML="$demo_dir/shell.qml"
export OMASTORM_WIDTH=1200 OMASTORM_HEIGHT=800
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic
export QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl
export OMASTORM_USER_SHELL="$demo_dir/user.toml"
printf '[font]\nbase-size = 12\n' > "$OMASTORM_USER_SHELL"
unset OMASTORM_CAPTURE
for theme in dark light; do
  rm -rf "$demo_dir/$theme/frames" "$demo_dir/$theme/stills"
  mkdir -p "$demo_dir/$theme/frames" "$demo_dir/$theme/stills"
  if [[ "$theme" == dark ]]; then
    printf 'background = "#1a1b26"\nforeground = "#a9b1d6"\naccent = "#7aa2f7"\n' > "$demo_dir/$theme/colors.toml"
  else
    printf 'background = "#f5f1e8"\nforeground = "#343a48"\naccent = "#365ba8"\n' > "$demo_dir/$theme/colors.toml"
  fi
  OMASTORM_THEME_DIR="$demo_dir/$theme" \
    OMASTORM_DEMO_FRAMES="$demo_dir/$theme/frames" \
    OMASTORM_DEMO_STILLS="$demo_dir/$theme/stills" \
    timeout 600 bash run.sh > "$demo_dir/$theme/capture.log" 2>&1
  rg -q DEMO_CAPTURE_PASSED "$demo_dir/$theme/capture.log"
  cp "$demo_dir/$theme/stills/glyphs.png" "docs/media/$theme-glyphs.png"
  cp "$demo_dir/$theme/stills/pixels.png" "docs/media/$theme-pixels.png"
  cp "$demo_dir/$theme/stills/stipple.png" "docs/media/$theme-stipple.png"
  ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$demo_dir/$theme/frames/%04d.png" \
    -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -movflags +faststart "$demo_dir/$theme.mp4"
done
printf "file '%s/dark.mp4'\nfile '%s/light.mp4'\n" "$demo_dir" "$demo_dir" > "$demo_dir/concat.txt"
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$demo_dir/concat.txt" \
  -c copy -movflags +faststart docs/media/omastorm-demo.mp4
# Short animated README preview: Glyphs in each theme, full demo linked beside it.
ffmpeg -hide_banner -loglevel error -y -i docs/media/omastorm-demo.mp4 \
  -filter_complex "[0:v]select='lt(t,4)+between(t,12,16)',setpts=N/30/TB,fps=8,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff:max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 docs/media/omastorm-preview.gif
ffprobe -v error -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_frames:format=duration,size \
  -of json docs/media/omastorm-demo.mp4 > review/demo-validation.json
echo 'docs/media/omastorm-demo.mp4 · omastorm-preview.gif · {dark,light}-{glyphs,pixels,stipple}.png'
