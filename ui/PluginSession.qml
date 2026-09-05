pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Sites.js" as Sites
import "Keys.js" as KeyMap

QtObject {
    id: session
    // One non-map connection keeps the bar current, including on multiple
    // outputs. Visible maps have separate sockets for their tile rectangles.
    property Engine engine: Engine {}
    property Config config: Config {}
    property Theme theme: Theme {}
    property bool windowOpen: false
    property bool initialized: false
    property string treatment: Quickshell.env("OMASTORM_STYLE") || "GLYPHS"
    // The weak-return floor in dBZ, or null for every measured return
    // (DESIGN.md, weak-return floor); config.toml's weak_floor and the `w`
    // key change it, OMASTORM_WEAK outranks the file for captures.
    property var weakFloor: KeyMap.envFloor(Quickshell.env("OMASTORM_WEAK")) !== undefined ? KeyMap.envFloor(Quickshell.env("OMASTORM_WEAK")) : KeyMap.DEFAULT_FLOOR
    property string startupError: ""
    signal homeRequested()
    readonly property string homeSite: {
        if (config.homeSite) return config.homeSite;
        if (!config.location) return "";
        var best = "", distance = Infinity;
        for (var site of engine.sites) {
            var km = Sites.distanceKm(config.location.lat, config.location.lon, site.lat, site.lon);
            if (km < distance) { best = site.id; distance = km; }
        }
        return best;
    }
    function returnHome() {
        if (!engine.state || !config.ready) return;
        if (homeSite && (engine.state.site.id !== homeSite || engine.state.source !== "live")) {
            engine.send({type: "select_site", id: homeSite});
            homeRequested();
        }
    }
    function initialize() {
        if (initialized || !engine.state || !config.ready) return;
        initialized = true;
        if (!windowOpen || engine.state.source === "archived") returnHome();
        applyFollow();
    }
    function applyFollow() {
        if (engine.state && config.follow !== undefined && config.follow !== engine.state.site.follow)
            engine.send({type: "follow", enabled: config.follow});
    }
    function applyTreatment() {
        var errors = [], wanted = KeyMap.treatment(config.treatment, errors);
        if (!Quickshell.env("OMASTORM_STYLE") && wanted) treatment = wanted;
        if (KeyMap.envFloor(Quickshell.env("OMASTORM_WEAK")) === undefined) weakFloor = KeyMap.weakFloor(config.weakFloor, errors);
    }
    onHomeSiteChanged: if (initialized) returnHome()
    property Connections engineEvents: Connections {
        target: session.engine
        function onStateChanged() {
            if (!session.engine.state) session.initialized = false;
            else session.initialize();
        }
    }
    property Connections configEvents: Connections {
        target: session.config
        function onReadyChanged() { session.initialize(); }
        function onFollowChanged() { session.applyFollow(); }
        function onTreatmentChanged() { session.applyTreatment(); }
        function onWeakFloorChanged() { session.applyTreatment(); }
    }
    // argv, never shell interpolation: checkout paths may contain spaces.
    // Quickshell's process cwd is qrc:/qs-blackhole; bash refuses to start there.
    property Process bootstrap: Process {
        readonly property string root: Quickshell.env("OMASTORM_ROOT") || Quickshell.env("HOME") + "/.config/omarchy/plugins/com.omastorm.radar"
        command: ["bash", root + "/run.sh", "--ensure"]
        workingDirectory: Quickshell.env("HOME")
        running: true
        stderr: StdioCollector { onStreamFinished: session.startupError = text.trim() }
        onExited: (code, status) => { if (code === 0) session.startupError = ""; }
    }
    Component.onCompleted: applyTreatment()
}
