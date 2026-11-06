# Third-party materials

ALPORA's original code and authored vector assets use the [MIT license](LICENSE).
Third-party materials retain their own licenses.

## Adwaita cursors

`assets/desktop-themes/alpine/Poly-Alpine-Cursors/cursors/` contains unmodified
Adwaita cursor artwork, with aliases for equivalent cursor names. These files
were copied from the system Adwaita theme by `scripts/build-desktop-theme`;
they are **not relicensed under MIT**.

- Attribution: **GNOME Project**, <https://www.gnome.org>.
- Upstream: <https://gitlab.gnome.org/GNOME/adwaita-icon-theme>.
- License: GNU LGPL version 3 or Creative Commons Attribution–ShareAlike 3.0,
  as specified in the included upstream notice.
- Notices and LGPL text: [licenses/adwaita](licenses/adwaita/).

Application icons inherited from installed system themes remain provided by
those packages. ALPORA's theme files name their fallbacks; this repository does
not bundle those complete third-party application icon sets or fonts.

## Landscape artwork and screenshots

The bundled landscape wallpapers were generated with OpenAI's image generation
tool. Prompts and provenance are recorded in `assets/wallpapers/prompts.json`
and [docs/artwork.md](docs/artwork.md). They are not photographs or a claim of
hand-painted authorship. No exclusive rights over generated artwork are asserted.

Images under `docs/media/` are real captures of the running desktop, except the
explicitly authored SVG brand banner. Visible third-party application names and
icons identify those applications; no affiliation or endorsement is implied.

## Downloaded Papirus and Bibata themes

The asset installer downloads pinned upstream releases into the user's data
directory. Papirus and Bibata retain their GPL-3.0 licenses, authors and notices;
they are not relicensed under MIT or represented as ALPORA-authored artwork.

- Papirus Development Team: <https://github.com/PapirusDevelopmentTeam/papirus-icon-theme>.
- Bibata / ful1e5: <https://github.com/ful1e5/Bibata_Cursor>.

See [installation details and version pins](docs/icons-and-cursor.md).
