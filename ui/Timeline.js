.pragma library
// Frame ticks and up to three stubs for missing scan intervals.
function slots(frames) {
    var out = [], n = frames.length;
    if (!n) return out;
    var gaps = [];
    for (var i = 1; i < n; i++) gaps.push(Date.parse(frames[i].scanTime) - Date.parse(frames[i - 1].scanTime));
    var sorted = gaps.slice().sort((a, b) => a - b), median = sorted.length ? sorted[Math.floor(sorted.length / 2)] : 0;
    for (var j = 0; j < n; j++) {
        var missing = j > 0 && median > 0 ? Math.min(3, Math.round(gaps[j - 1] / median) - 1) : 0;
        for (var k = 0; k < missing; k++) out.push({ id: "", stub: true, partial: false });
        out.push({ id: frames[j].id, stub: false, partial: frames[j].status === "partial" });
    }
    return out;
}
