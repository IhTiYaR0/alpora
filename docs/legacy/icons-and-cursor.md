# ALPORA icons and cursor

The application icon foundation is **Papirus Dark**, with original ALPORA folder
and terminal overlays in the six landscape palettes. Application brands stay
recognisable. Missing icons fall back through Adwaita and hicolor. MacTahoe is
no longer required for the default appearance.

The cursor is **Bibata Modern Ice**, 24 px. It uses the upstream XCursor set,
including animated wait/progress, text, grab and resize cursors. The installer
sets GTK preferences, XCURSOR environment and the compositor cursor. Hyprcursor
rendering is disabled for this XCursor-only set; no invalid Hyprcursor manifest
is generated. The cursor stays neutral across themes rather than changing
visibility or size as palettes change.

## Install and apply separately

```sh
./bin/poly-shell assets install
./bin/poly-shell assets apply
```

`install` downloads pinned releases and checks SHA-256 before extraction. Safe
tar extraction rejects escaping paths/links and special files; archive size is
bounded. Existing unrelated theme paths are preserved. Versioned upstream
content lives in `$XDG_DATA_HOME/alpora/desktop-assets`, default
`~/.local/share/alpora/desktop-assets`. Icon search links live under `icons` in
that same data directory. Repo-owned overlays remain symlinks into the checkout.

`apply` backs up affected GTK INI files, Hyprland configuration and the previous
GSettings values. It preserves unrelated INI settings, writes a marked cursor
block and applies the current icon/GTK theme preference. Failure restores files
and preferences, then reloads the restored compositor configuration if needed.
A manually edited managed block is preserved with an error.

Backups and their exact path manifests are under
`~/.local/state/poly-shell/backups/desktop-assets-*`. They also record previous
GSettings values. Use those specific backups for recovery; upstream asset
installation does not delete unrelated themes. Already running applications
that cache icons/cursors may need reopening. New sessions read the persistent
cursor block. The theme switcher continues to select the per-landscape overlay.

The old bundled `Poly-Alpine-Cursors` directory remains historical Adwaita content;
it is no longer the selected cursor and is not rebuilt by the theme generator.

## Versions and attribution

- [Bibata Cursor](https://github.com/ful1e5/Bibata_Cursor), v2.0.7, Modern Ice.
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme), 20260801.

Release URLs, checksums and license metadata are in
`poly_shell/desktop_assets.py`; original upstream notices remain in extracted
sources. Neither upstream project is relicensed under ALPORA's MIT license.

## Local validation — 22 October 2026

GTK icon lookup checked Firefox, VS Code, Kitty, Nautilus, folders and a generic
fallback across all six themes. Application lookups resolve into Papirus; folder
icons remain theme-specific. Binary XCursor checks cover 12 roles, valid sizes
and in-bounds hotspots, including the 24 px size and animated cursors.
Repeated installation reuses verified assets. Corrupt downloads, unsafe archives,
foreign theme paths, preserved settings, modified blocks and rollback are tested.
The live compositor reports the Bibata cursor and no configuration errors.
