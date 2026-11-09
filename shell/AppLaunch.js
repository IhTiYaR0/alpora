// Pure rules for starting user applications in their own systemd unit, named
// app-<launcher>-<AppID>@<RANDOM>.service (systemd.io/DESKTOP_ENVIRONMENTS).
// A dash separates the name's fields, so neither launcher nor AppID may hold one.

function hex(byte) { return "\\x" + (byte < 16 ? "0" : "") + byte.toString(16); }
function utf8(codePoint) {
    if (codePoint < 0x80) return [codePoint];
    if (codePoint < 0x800) return [0xc0 | codePoint >> 6, 0x80 | codePoint & 63];
    if (codePoint < 0x10000) return [0xe0 | codePoint >> 12, 0x80 | codePoint >> 6 & 63, 0x80 | codePoint & 63];
    return [0xf0 | codePoint >> 18, 0x80 | codePoint >> 12 & 63, 0x80 | codePoint >> 6 & 63, 0x80 | codePoint & 63];
}

// systemd-escape's rule: keep A-Z a-z 0-9 : _ . and write every other byte as \xNN.
// Unlike systemd-escape, "/" becomes \x2f rather than "-", which would split the AppID.
function escapeId(id) {
    let result = "";
    let first = true;
    for (const character of String(id)) {
        if (/[A-Za-z0-9:_.]/.test(character) && !(first && character === "."))
            result += character;
        else
            result += utf8(character.codePointAt(0)).map(hex).join("");
        first = false;
    }
    return result;
}

// Spec: without an application ID, use basename(argv[0]), which must not contain "-".
function fallbackId(argv) {
    const program = argv && argv.length ? String(argv[0]) : "";
    const name = program.slice(program.lastIndexOf("/") + 1).replace(/-/g, "_");
    return name || "command";
}

function unitName(launcher, appId, random) {
    return "app-" + launcher + "-" + escapeId(appId) + "@" + random + ".service";
}

// ExitType=cgroup keeps the unit, and the app, alive after a launcher that
// forks the real application and exits (systemd 250 or later). Apps go to
// app.slice unless a slice is given (session.slice for the lock screen).
function command(launcher, appId, argv, random, workingDirectory, slice) {
    const id = appId || fallbackId(argv);
    const result = ["systemd-run", "--user", "--slice=" + (slice || "app.slice"), "--collect", "--quiet",
        "--service-type=exec", "-p", "ExitType=cgroup"];
    if (workingDirectory) result.push("--working-directory=" + workingDirectory);
    result.push("--unit=" + unitName(launcher, id, random), "--");
    return result.concat(argv);
}
