pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

// Lightweight internationalisation singleton.  Locale strings are shipped as
// flat JSON files under assets/locales/ and loaded once when the session state
// arrives (which carries ``settings.locale``).  Every QML component resolves
// user-visible text through ``I18n.tr("key")`` instead of inline literals.
//
// Fallback chain: requested locale → Russian → the key itself, so the UI
// always renders something readable.

Singleton {
    id: root

    // Current locale code, updated from Session.settings.locale.
    readonly property string locale: Session.loaded ? (Session.settings.locale || "en") : "en"

    // Current Qt.locale object for date/time formatting.
    readonly property var qtLocale: {
        const map = { "ru": "ru_RU", "vi": "vi_VN", "en": "en_US", "es": "es_ES" };
        return Qt.locale(map[root.locale] || "en_US");
    }

    // Merged string table (requested locale on top of English fallback).
    property var strings: ({})

    // Full path to the locales directory, resolved from the project root.
    readonly property string localesDir: {
        // POLY_SHELL_ROOT is set by the run script; fall back to a
        // path relative to the shell/ directory.
        const root = Quickshell.env("POLY_SHELL_ROOT") || "";
        return root ? root + "/assets/locales" : "";
    }

    // ── Public API ──────────────────────────────────────────────────────

    // Primary translation function.  Returns the localised string for *key*,
    // falling back to English baseline, then to the key itself.
    function tr(key: string): string {
        const value = root.strings[key];
        return value !== undefined ? value : key;
    }

    // Translation with placeholder substitution.  Replaces ``{name}`` tokens
    // in the translated string with values from *params*.
    function trWith(key: string, params: var): string {
        let value = root.strings[key];
        if (value === undefined) return key;
        if (params && typeof params === "object") {
            const keys = Object.keys(params);
            for (let i = 0; i < keys.length; i++)
                value = value.replace(new RegExp("\\{" + keys[i] + "\\}", "g"), String(params[keys[i]]));
        }
        return value;
    }

    // Access an array value (e.g. month names, weekday abbreviations).
    function trArray(key: string): var {
        const value = root.strings[key];
        return Array.isArray(value) ? value : [];
    }

    // Translates compound status string, splitting by ' · ' if present.
    function trStatus(value: var): string {
        const source = String(value || "");
        if (!source) return "";
        const direct = root.tr(source);
        if (direct !== source) return direct;
        if (!source.includes(" · ")) return source;
        return source.split(" · ").map(part => root.tr(part.trim())).join(" · ");
    }

    // Compatibility wrapper for hardware status translations.
    function trHardware(key: string, language: string): string {
        return root.tr(key);
    }

    // ── Loading ─────────────────────────────────────────────────────────

    onLocaleChanged: reload()
    Component.onCompleted: reload()

    function reload(): void {
        if (!root.localesDir) return;
        // Always load English as the universal baseline, then overlay requested locale.
        baseLoader.path = root.localesDir + "/en.json";
        baseLoader.reload();
    }

    FileView {
        id: baseLoader
        path: ""
        preload: false
        printErrors: false
        onLoaded: {
            try {
                root._baseStrings = JSON.parse(text());
            } catch (_) {
                root._baseStrings = {};
            }
            if (root.locale !== "en") {
                overlayLoader.path = root.localesDir + "/" + root.locale + ".json";
                overlayLoader.reload();
            } else {
                root.strings = root._baseStrings;
            }
        }
        onLoadFailed: {
            console.warn("I18n: cannot load English baseline locale from", path);
            root.strings = {};
        }
    }

    FileView {
        id: overlayLoader
        path: ""
        preload: false
        printErrors: false
        onLoaded: {
            try {
                const overlay = JSON.parse(text());
                const merged = Object.assign({}, root._baseStrings, overlay);
                root.strings = merged;
            } catch (_) {
                root.strings = root._baseStrings;
            }
        }
        onLoadFailed: {
            console.warn("I18n: cannot load locale", root.locale, "from", path, "; using English baseline");
            root.strings = root._baseStrings;
        }
    }

    // Internal: baseline strings before overlay.
    property var _baseStrings: ({})
}
