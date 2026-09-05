import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        implicitWidth: 600; implicitHeight: 420; color: "#101820"
        RadarMap {
            id: map
            anchors.fill: parent
            theme: ({font: "monospace", foreground: "#eeeeee", accent: "#5599ee", background: "#101820"})
            tileRoot: Qt.resolvedUrl(".").toString() + "/"
            scan: ({site: {lat: 35.33306, lon: -97.27748}, palette: [], rays: 1, gates: 1, firstGateM: 0, gateSpacingM: 250, elevationDeg: 0})
        }
    }
    property int stage: 0
    property var nextRect
    function check(ok, message) { if (!ok) throw new Error(message); }
    function announce(rect, path, skipLast) {
        for (var y = rect.y0; y <= rect.y1; y++)
            for (var x = rect.x0; x <= rect.x1; x++) {
                if (skipLast && x === rect.x1 && y === rect.y1) continue;
                map.tileReady({z: rect.z, x: x, y: y, set: path === "old.png" ? "osm" : "ne", path: path,
                    labels: [{name: "Small", lat: 35.4, lon: -97.4, class: "town", rank: 8},
                             {name: "Important", lat: 35.4, lon: -97.4, class: "city", rank: 1}]});
            }
    }
    Timer {
        interval: 350; repeat: true; running: true
        onTriggered: {
            try {
                if (stage === 0) { map.requestTiles(); announce(map.request, "old.png", false); }
                if (stage === 1) {
                    check(map.places.length === 2 && map.places[0].name === "Important", "Labels not ranked/deduplicated");
                    check(map.osmOnScreen, "Missing displayed attribution");
                    map.zoom(map.span / 2);
                }
                if (stage === 2) {
                    nextRect = map.request;
                    check(map.displayedLevel !== nextRect.z, "Dropped old level before arrival");
                    map.grabToImage(r => r.saveToFile(Quickshell.env("OMASTORM_REVIEW") + "/zoom-held-before.png"));
                    announce(nextRect, "new.png", true);
                }
                if (stage === 3) {
                    check(map.displayedLevel !== nextRect.z && map.osmOnScreen, "Partial rectangle replaced old level");
                    map.grabToImage(r => r.saveToFile(Quickshell.env("OMASTORM_REVIEW") + "/zoom-held-partial.png"));
                }
                if (stage === 4) {
                    announce(nextRect, "new.png", false);
                    check(map.displayedLevel !== nextRect.z, "Swapped on announcement before image readiness");
                }
                if (stage === 5) {
                    check(map.displayedLevel === nextRect.z && !map.osmOnScreen, "Completed rectangle did not swap attribution and level");
                    var count = Object.keys(map.tiles).length;
                    check(count === (nextRect.x1-nextRect.x0+1)*(nextRect.y1-nextRect.y0+1), "Old tiles retained");
                    announce({z: 0, x0: 0, x1: 0, y0: 0, y1: 0}, "old.png", false);
                    check(Object.keys(map.tiles).length === count, "Stale reply retained");
                    map.grabToImage(r => r.saveToFile(Quickshell.env("OMASTORM_REVIEW") + "/zoom-ready.png"));
                }
                if (stage === 6) {
                    map.zoom(map.span / 2);
                }
                if (stage === 7) {
                    var abandoned = map.request;
                    announce(abandoned, "old.png", true);
                    // Reverse before the intermediate level finishes loading.
                    map.zoom(map.span * 2);
                    map.requestTiles();
                    announce(abandoned, "old.png", false);
                    check(map.displayedLevel === nextRect.z, "Rapid reversal lost the complete level");
                    check(Object.keys(map.tiles).every(k => Number(k.split("/")[0]) === nextRect.z), "Abandoned level retained");
                }
                if (stage === 8) { console.log("MAP_TILES_PASSED"); Qt.quit(); }
                stage++;
            } catch (e) { console.error(e); Qt.quit(); }
        }
    }
}
