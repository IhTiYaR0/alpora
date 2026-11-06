.pragma library

function segment(minute, stops) {
    if (!stops || stops.length < 2) return {lower: 0, upper: 0, blend: 0};
    const value = Math.max(0, Math.min(1440, minute));
    let lower = stops.length - 1;
    for (let i = 0; i < stops.length - 1; ++i) {
        if (value < stops[i + 1].minute) { lower = i; break; }
    }
    const upper = (lower + 1) % stops.length;
    const start = stops[lower].minute, end = upper === 0 ? 1440 : stops[upper].minute;
    const t = Math.max(0, Math.min(1, (value - start) / (end - start)));
    return {lower: lower, upper: upper, blend: t * t * (3 - 2 * t)};
}

function format(minute) {
    const value = Math.round(Math.max(0, Math.min(1440, minute)));
    return String(Math.floor(value / 60)).padStart(2, "0") + ":" + String(value % 60).padStart(2, "0");
}

function palette(minute, stops) {
    const s = segment(minute, stops);
    if (!stops || !stops[s.lower] || !stops[s.lower].palette) return null;
    const a = stops[s.lower].palette, b = stops[s.upper].palette;
    const result = {};
    for (const key of Object.keys(a)) {
        let color = "#";
        for (const i of [1, 3, 5]) {
            const value = Math.round(parseInt(a[key].slice(i,i+2),16) * (1-s.blend) + parseInt(b[key].slice(i,i+2),16) * s.blend);
            color += value.toString(16).padStart(2, "0");
        }
        result[key] = color;
    }
    return result;
}
