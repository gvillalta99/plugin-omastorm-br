pragma Singleton
import QtQuick

QtObject {
    id: rv

    property string host: "https://tilecache.rainviewer.com"
    property var frames: []
    property int currentIndex: -1
    property var currentFrame: currentIndex >= 0 && currentIndex < frames.length ? frames[currentIndex] : null
    property bool loading: false
    property string error: ""
    property bool playing: false
    property int colorScheme: 2 // 1: Original, 2: Universal Blue, 3: TITAN, 4: The Weather Channel
    property bool smooth: true
    property bool snow: true

    readonly property string currentPath: currentFrame ? currentFrame.path : ""
    readonly property int currentTime: currentFrame ? currentFrame.time : 0

    // Tile URL helper for OpenStreetMap / Mercator z/x/y
    function tileUrl(z, x, y) {
        if (!currentPath || !host) return "";
        var smoothFlag = smooth ? "1" : "0";
        var snowFlag = snow ? "1" : "0";
        // host + path + /size/z/x/y/colorScheme/smooth_snow.png
        return host + currentPath + "/512/" + z + "/" + x + "/" + y + "/" + colorScheme + "/" + smoothFlag + "_" + snowFlag + ".png";
    }

    function step(delta) {
        if (!frames.length) return;
        var next = currentIndex + delta;
        if (next < 0) next = 0;
        if (next >= frames.length) next = frames.length - 1;
        currentIndex = next;
    }

    function jump(toEnd) {
        if (!frames.length) return;
        currentIndex = toEnd ? frames.length - 1 : 0;
    }

    function seek(time) {
        var idx = frames.findIndex(f => f.time === time);
        if (idx >= 0) currentIndex = idx;
    }

    function togglePlay() {
        playing = !playing;
    }

    property Timer playTimer: Timer {
        interval: 650
        running: rv.playing && rv.frames.length > 1
        repeat: true
        onTriggered: {
            if (rv.currentIndex >= rv.frames.length - 1) {
                rv.currentIndex = 0;
            } else {
                rv.currentIndex++;
            }
        }
    }

    function refresh() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.rainviewer.com/public/weather-maps.json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.host) rv.host = data.host;
                        var past = data.radar && data.radar.past ? data.radar.past : [];
                        var nowcast = data.radar && data.radar.nowcast ? data.radar.nowcast : [];
                        var all = past.concat(nowcast);
                        rv.frames = all;
                        if (all.length > 0) {
                            if (rv.currentIndex < 0 || rv.currentIndex >= all.length - 1) {
                                rv.currentIndex = all.length - 1;
                            }
                        }
                        rv.error = "";
                    } catch (e) {
                        rv.error = "Failed to parse RainViewer API: " + e;
                    }
                } else {
                    rv.error = "RainViewer HTTP " + xhr.status;
                }
            }
        };
        xhr.send();
    }

    property Timer refreshTimer: Timer {
        interval: 300000 // 5 minutes
        running: true
        repeat: true
        onTriggered: rv.refresh()
    }

    Component.onCompleted: refresh()
}
