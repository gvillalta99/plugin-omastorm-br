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
    property int colorScheme: 2 // 0: Black and White, 1: Original, 2: Universal Blue, 3: TITAN, 4: The Weather Channel, 5: Meteored, 6: NEXRAD L3, 7: Rainbow, 8: Dark Sky
    property bool smooth: true
    property bool snow: true

    readonly property var schemes: [
        { id: 0, name: "Preto e Branco", colors: ["#202020", "#505050", "#808080", "#b0b0b0", "#e0e0e0", "#ffffff"] },
        { id: 1, name: "Original RV", colors: ["#00ECEC", "#01A0F6", "#0000F6", "#00FF00", "#00C800", "#009000", "#FFFF00", "#E7C000", "#FF9000", "#FF0000", "#D60000", "#C00000", "#FF00F0", "#9600B4"] },
        { id: 2, name: "Universal Blue", colors: ["#34465f", "#426b88", "#4098a5", "#51b897", "#85c76b", "#cadb6b", "#f0cd61", "#eda24c", "#e67349", "#d84c64", "#b55096", "#e2b4df"] },
        { id: 3, name: "TITAN", colors: ["#0000F6", "#01A0F6", "#00ECEC", "#00FF00", "#00C800", "#009000", "#FFFF00", "#E7C000", "#FF9000", "#FF0000", "#D60000", "#C00000", "#FF00F0", "#9600B4"] },
        { id: 4, name: "The Weather Channel", colors: ["#2d699b", "#27878d", "#4fa752", "#84c338", "#d9dc36", "#e8a72a", "#d95123", "#b92925", "#8c1b3f", "#6f1b4d"] },
        { id: 5, name: "Meteored", colors: ["#1e8bc3", "#2abb9b", "#2ecc71", "#f1c40f", "#f39c12", "#e67e22", "#d35400", "#e74c3c", "#c0392b", "#8e44ad"] },
        { id: 6, name: "NEXRAD Level 3", colors: ["#04e9e7", "#019ff4", "#0300f4", "#02fd02", "#01c501", "#008e00", "#fdfa02", "#e5bc00", "#fd9500", "#fd0000", "#d40000", "#bc0000", "#f800fd", "#9854c6", "#fdfdfd"] },
        { id: 7, name: "Rainbow", colors: ["#641a80", "#982d80", "#cd4071", "#f1605d", "#fd8835", "#fcae12", "#fed34c", "#fcfdbf"] },
        { id: 8, name: "Dark Sky", colors: ["#355C7D", "#6C5B7B", "#C06C84", "#F67280", "#F8B195"] }
    ]

    readonly property string currentSchemeName: {
        var s = schemes.find(x => x.id === colorScheme);
        return s ? s.name : "Custom";
    }

    readonly property var currentColors: {
        var s = schemes.find(x => x.id === colorScheme);
        return s ? s.colors : ["#34465f", "#426b88", "#4098a5", "#51b897", "#85c76b", "#cadb6b", "#f0cd61", "#eda24c", "#e67349", "#d84c64", "#b55096", "#e2b4df"];
    }

    function nextColorScheme() {
        var ids = schemes.map(x => x.id);
        var currIdx = ids.indexOf(colorScheme);
        var nextIdx = (currIdx + 1) % ids.length;
        setColorScheme(ids[nextIdx]);
    }

    function setColorScheme(id) {
        colorScheme = id;
        if (PluginSession && PluginSession.config) {
            PluginSession.config.palette = id;
        }
    }

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
        xhr.open("GET", "https://api.rainviewer.com/public/weather-maps.json?_t=" + Date.now());
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
                        var wasAtNewest = (rv.currentIndex === -1 || rv.currentIndex >= rv.frames.length - 1);
                        rv.frames = all;
                        if (all.length > 0) {
                            if (wasAtNewest || rv.currentIndex < 0 || rv.currentIndex >= all.length) {
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
        interval: 120000 // 2 minutes
        running: true
        repeat: true
        onTriggered: rv.refresh()
    }

    Component.onCompleted: refresh()
}
