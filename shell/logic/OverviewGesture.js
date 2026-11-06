.pragma library

function parse(data) {
    const fields = data.split(",");
    if (fields.length !== 8 || fields[0] !== "poly-overview-swipe" || fields[1] !== "v1") return null;
    if (!/^[a-zA-Z0-9_-]{1,80}$/.test(fields[2]) || !["start", "update", "finish"].includes(fields[3])) return null;
    const direction = Number(fields[4]), distance = Number(fields[5]), time = Number(fields[6]);
    if (![1, -1].includes(direction) || !Number.isFinite(distance) || Math.abs(distance) > 360
            || !Number.isInteger(time) || time < 0 || !["0", "1"].includes(fields[7])) return null;
    return {id: fields[2], phase: fields[3], direction: direction, distance: distance, time: time, cancelled: fields[7] === "1"};
}

function progress(origin, distance) { return Math.max(0, Math.min(1, origin + distance / 300)); }

function destination(value, velocity, idleMs, cancelled, wasOpen) {
    if (cancelled) return wasOpen ? 1 : 0;
    // A flick may finish the transition; holding still discards old momentum.
    const projected = value + (idleMs <= 120 ? velocity * 140 : 0);
    return projected >= 0.5 ? 1 : 0;
}
