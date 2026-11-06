.pragma library

// Coordinates are measured against the original 1672 × 941 artwork, before
// PreserveAspectCrop. A future/imported theme gets usable neutral landmarks.
const scenes = {
    "alpine": { light: [0.806, 0.538], peak: [0.118, 0.196], music: [0.51, 0.675], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.sun") : "Sun" },
    "moon-lake": { light: [0.795, 0.182], peak: [0.249, 0.115], music: [0.60, 0.77], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.moon") : "Moon" },
    "forest-mist": { light: [0.264, 0.232], peak: [0.558, 0.100], music: [0.59, 0.79], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.light_in_mist") : "Light in mist" },
    "warm-desert": { light: [0.207, 0.276], peak: [0.546, 0.185], music: [0.61, 0.68], water: false, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.sun") : "Sun" },
    "northern-lights": { light: [0.704, 0.174], peak: [0.417, 0.279], music: [0.61, 0.77], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.aurora") : "Aurora" },
    "rose-sunset": { light: [0.850, 0.387], peak: [0.242, 0.270], music: [0.64, 0.67], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.sun") : "Sun" },
    "timeline": { light: [0.806, 0.538], peak: [0.118, 0.196], music: [0.51, 0.675], water: true, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.light") : "Light" }
};
function scene(id, minute) {
    const base = scenes[id] || { light: [0.79, 0.32], peak: [0.26, 0.28], music: [0.54, 0.70], water: false, name: (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.theme") : "Theme" };
    const value = { light: base.light.slice(), peak: base.peak.slice(), music: base.music.slice(), water: base.water, name: base.name };
    if (id === "timeline") {
        // Timeline reuses the Alpine composition. The night moon is lower and
        // farther right; other frames have no visible celestial disc.
        if (minute < 165 || minute >= 1350) { value.light = [0.81, 0.538]; value.name = (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.moon") : "Moon"; }
        else if (minute >= 1020 && minute < 1200) value.name = (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.sun") : "Sun";
        else { value.light = [0.78, 0.30]; value.name = (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr("landscape.time_of_day") : "Time of day"; }
    }
    return value;
}
function fitPoint(point, width, height) {
    const scale = Math.max(width / 1672, height / 941);
    return { x: (width - 1672 * scale) / 2 + point[0] * 1672 * scale,
             y: (height - 941 * scale) / 2 + point[1] * 941 * scale };
}
function clamp(value, low, high) { return Math.max(low, Math.min(Math.max(low, high), value)); }
function layout(id, minute, width, height) {
    const s = scene(id, minute);
    const scale = clamp(Math.min(width / 1920, height / 1080), 0.72, 1.35);
    const light = fitPoint(s.light, width, height);
    const peak = fitPoint(s.peak, width, height);
    const music = fitPoint(s.music, width, height);
    // Keep the full radial hit area on screen even on portrait/ultrawide crops.
    light.x = clamp(light.x, 185 * scale, width - 185 * scale);
    light.y = clamp(light.y, 200 * scale, height - 200 * scale);
    peak.x = clamp(peak.x, 250 * scale, width - 250 * scale);
    peak.y = clamp(peak.y, 240 * scale, height - 180 * scale);
    music.x = clamp(music.x, 250 * scale, width - 250 * scale);
    music.y = clamp(music.y, 200 * scale, height - 160 * scale);
    return {light: light, peak: peak, music: music, scale: scale, water: s.water, name: s.name};
}
