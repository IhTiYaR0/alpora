.pragma library

// Fit a monitor into a thumbnail, retaining its logical coordinate system.
function monitorBox(monitor) {
    const m = monitor || {};
    const rotated = Number(m.transform || 0) % 2 === 1;
    const scale = Math.max(0.1, Number(m.scale || 1));
    return {x: Number(m.x || 0), y: Number(m.y || 0),
        width: Math.max(1, Number((rotated ? m.height : m.width) || 1920) / scale),
        height: Math.max(1, Number((rotated ? m.width : m.height) || 1080) / scale)};
}

function windowBox(client, monitor, width, height) {
    const m = monitorBox(monitor);
    const scale = Math.min(width / m.width, height / m.height);
    const at = client.at || [m.x, m.y], size = client.size || [m.width, m.height];
    const left = Math.max(0, Math.min(m.width, at[0] - m.x));
    const top = Math.max(0, Math.min(m.height, at[1] - m.y));
    const right = Math.max(left, Math.min(m.width, at[0] - m.x + size[0]));
    const bottom = Math.max(top, Math.min(m.height, at[1] - m.y + size[1]));
    return {x: (width - m.width * scale) / 2 + left * scale,
        y: (height - m.height * scale) / 2 + top * scale,
        width: (right - left) * scale, height: (bottom - top) * scale};
}

function workspaceSelector(workspace) {
    if (!workspace || !Number.isInteger(workspace.id) || workspace.id === 0
            || String(workspace.name).startsWith("special:")) return null;
    return workspace.id > 0 ? String(workspace.id) : "name:" + workspace.name;
}

// Lua accepts JSON's ordinary quoted strings, but not JSON's \u control escapes.
function luaString(value) {
    return '"' + String(value).replace(/[\\"\x00-\x1f\x7f]/g, ch => {
        if (ch === '"' || ch === '\\') return '\\' + ch;
        return '\\' + ch.charCodeAt(0).toString().padStart(3, '0');
    }) + '"';
}

function dispatch(action, workspace, address, lua) {
    const selector = workspaceSelector(workspace);
    if (selector === null) return "";
    if (action === "workspace") return lua
        ? "hl.dsp.focus({ workspace = " + luaString(selector) + " })"
        : "workspace " + selector;
    if (!/^0x[0-9a-f]+$/i.test(address || "")) return "";
    if (action === "focus") return lua
        ? "hl.dsp.focus({ window = " + luaString("address:" + address) + " })"
        : "focuswindow address:" + address;
    if (action === "move") return lua
        ? "hl.dsp.window.move({ workspace = " + luaString(selector) + ", window = " + luaString("address:" + address) + ", follow = false })"
        : "movetoworkspacesilent " + selector + ",address:" + address;
    return "";
}
