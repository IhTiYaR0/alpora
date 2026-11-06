// Pure presentation rules; services supply observed state, never optimistic state.
const _i18n = (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n : {
    tr: function(key) {
        const fallback = {
            "network.ethernet": "Ethernet",
            "network.internet_full": "Есть интернет",
            "network.internet_none": "Нет интернета",
            "network.internet_limited": "Ограниченный доступ",
            "network.internet_portal": "Нужен вход в сеть",
            "network.internet_unknown": "Интернет не проверен",
            "wifi.unavailable": "Wi‑Fi недоступен",
            "wifi.hardware_off": "Wi‑Fi выключен аппаратно",
            "wifi.off": "Wi‑Fi выключен",
            "wifi.connecting": "Wi‑Fi · Подключение…",
            "wifi.disconnected": "Wi‑Fi · Нет подключения",
            "audio.no_device": "Звук · нет устройства",
        };
        return fallback[key] || key;
    },
    trWith: function(key, params) {
        if (key === "audio.muted") return "Без звука · " + (params ? params.percent : 0) + "%";
        if (key === "audio.volume") return "Громкость · " + (params ? params.percent : 0) + "%";
        return key;
    }
};

function network(data) {
    const wifi = wifiStatus(data);
    if (data.wiredConnected) return {kind: "wired", level: 3, busy: false,
        warning: limited(data.connectivity), label: _i18n.tr("network.ethernet") + " · " + internet(data.connectivity)};
    return wifi;
}
function limited(connectivity) { return ["None", "Limited", "Portal"].includes(connectivity); }
function internet(connectivity) {
    return ({Full: _i18n.tr("network.internet_full"), None: _i18n.tr("network.internet_none"), Limited: _i18n.tr("network.internet_limited"),
        Portal: _i18n.tr("network.internet_portal"), Unknown: _i18n.tr("network.internet_unknown")})[connectivity] || _i18n.tr("network.internet_unknown");
}
function wifiLevel(value) {
    const strength = Math.max(0, Math.min(1, Number(value) || 0));
    return strength >= .67 ? 3 : strength >= .34 ? 2 : strength > .05 ? 1 : 0;
}
function wifiStatus(data) {
    if (!data.wifiAvailable) return {kind: "wifi-unavailable", level: 0, busy: false, warning: false, label: _i18n.tr("wifi.unavailable")};
    if (!data.hardwareEnabled) return {kind: "wifi-off", level: 0, busy: false, warning: false, label: _i18n.tr("wifi.hardware_off")};
    if (!data.wifiEnabled) return {kind: "wifi-off", level: 0, busy: false, warning: false, label: _i18n.tr("wifi.off")};
    if (data.connecting) return {kind: "wifi-connecting", level: 0, busy: true, warning: false, label: _i18n.tr("wifi.connecting")};
    if (!data.connected) return {kind: "wifi-disconnected", level: 0, busy: false, warning: false, label: _i18n.tr("wifi.disconnected")};
    const strength = Math.max(0, Math.min(1, Number(data.strength) || 0));
    return {kind: "wifi", level: wifiLevel(strength),
        busy: false, warning: limited(data.connectivity),
        label: (data.name || "Wi‑Fi") + " · " + Math.round(strength * 100) + "% · " + internet(data.connectivity)};
}
function audio(available, muted, volume) {
    const percent = Math.max(0, Math.round((Number(volume) || 0) * 100));
    return {kind: !available ? "audio-unavailable" : muted || percent === 0 ? "muted" : "volume",
        level: !available || muted || percent === 0 ? 0 : percent < 35 ? 1 : percent < 70 ? 2 : 3,
        label: !available ? _i18n.tr("audio.no_device") : muted ? _i18n.trWith("audio.muted", {percent: percent}) : _i18n.trWith("audio.volume", {percent: percent})};
}
