.pragma library

function _tr(k, fallback) { return (typeof I18n !== "undefined" && I18n && typeof I18n.tr === "function") ? I18n.tr(k) : fallback; }

// Bounded, deterministic behavior. No shell commands, input hooks or polling.
function random(state) {
    state.seed = (Math.imul(state.seed, 1664525) + 1013904223) >>> 0;
    return state.seed / 4294967296;
}
function create(seed) {
    return {seed: (seed || 1) >>> 0, activity: "greet", age: 0, duration: 3,
        position: 0.32, destination: 0.32, direction: 1, phase: 0, actions: 0};
}
function react(state, activity) {
    const next = Object.assign({}, state);
    next.activity = activity; next.age = 0; next.duration = activity === "dance" ? 7 : 3.6;
    next.actions += 1;
    return next;
}
function choose(state, context) {
    const candidates = context.lively
        ? ["walk", "walk", "look", "stretch", "service", "catch", "balance", "sit"]
        : ["look", "sit", "service", "nap", "walk"];
    if (context.music) candidates.push("dance", "dance");
    if (context.charging) candidates.push("charge");
    if (context.lowBattery) candidates.push("nap", "nap");
    const available = candidates.filter(name => name !== state.activity);
    const action = available[Math.floor(random(state) * available.length)];
    state.activity = action; state.age = 0; state.actions += 1;
    state.duration = (context.lively ? 3 : 5) + random(state) * 4;
    if (action === "walk") {
        // A genuinely different destination, even at either end of the rail.
        const offset = 0.25 + random(state) * 0.45;
        state.destination = state.position > 0.5 ? Math.max(0, state.position - offset) : Math.min(1, state.position + offset);
        state.direction = state.destination >= state.position ? 1 : -1;
        state.duration = Math.abs(state.destination - state.position) / (context.lively ? 0.10 : 0.055) + 0.4;
    }
}
function step(previous, elapsed, context) {
    const state = Object.assign({}, previous);
    const dt = Math.max(0, Math.min(0.1, elapsed));
    state.age += dt; state.phase = (state.phase + dt) % 3600;
    // Pausing the real player releases the dance immediately.
    if ((state.activity === "dance" && !context.music) || (state.activity === "charge" && !context.charging)) state.age = state.duration;
    if (state.age >= state.duration) choose(state, context);
    if (state.activity === "walk") {
        const distance = (context.lively ? 0.10 : 0.055) * dt;
        const delta = state.destination - state.position;
        state.position += Math.sign(delta) * Math.min(Math.abs(delta), distance);
    }
    state.position = Math.max(0, Math.min(1, state.position));
    return state;
}
function labels() {
    return {walk:_tr("companion.act.walk","Гуляет"), look:_tr("companion.act.look","Наблюдает"), stretch:_tr("companion.act.stretch","Разминает шарниры"), service:_tr("companion.act.service","Проверяет механизмы"), catch:_tr("companion.act.catch","Ловит искры"), balance:_tr("companion.act.balance","Держит равновесие"), sit:_tr("companion.act.sit","Отдыхает"), nap:_tr("companion.act.nap","Дремлет"), dance:_tr("companion.act.dance","Танцует под музыку"), charge:_tr("companion.act.charge","Заряжается"), greet:_tr("companion.act.greet","Приветствует тебя")};
}
