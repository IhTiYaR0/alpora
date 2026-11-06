# Artwork and design references

Generated with the built-in image generation tool; UI icons and polygon geometry are
native authored SVG/QML, not cropped bitmap controls.

- `assets/reference/top-panel-approved.png`: initial approved top panel reference.
- `assets/reference/quick-settings-approved.png`: final approved reference, with three
  independent volume, brightness and microphone rows. This is a design target, not a
  screenshot of running software.
- `assets/wallpapers/alpine-dawn.png`: generated static wallpaper, 1672×941 px. Swaybg
  fills the monitor. It is not a 4K source.

Final reference prompt: preserve the approved charcoal/sage/peach low-poly desktop,
mountain header, faceted tiles, bar size and wallpaper; add a third microphone row
below volume and brightness, a blue-green input slider, 80% value, device label and
mute control; remove the previous isolated microphone button and extend only the
popup down enough to fit the additional row.

Wallpaper prompt: standalone low-poly stylized alpine peak on the left, desaturated
mountain ridges, tranquil lake, peach sunrise on the right; preserve the approved
reference's mood, with no interface, text or watermark.

Runtime controls display actual system state and use the user's logical pixel scale;
mockup percentages, network name and clock are not hardcoded into the shell.

## Top bar and organizer revision

- `assets/reference/top-bar-approved-v2.png`: selected restrained bar concept with a
  single-line mountain clock inset. The reference's sample tray icons are not shipped
  as fake running applications. Native SVG and QML implement the actual controls.
- `assets/reference/day-panel-approved.png`: selected My Day concept. Actual events
  and tasks are supplied by the user; no mock event records are preloaded.

## Wallpaper collection

Five additional landscapes were generated with the built-in image_gen tool and
visually reviewed. Workspace assets and exact prompts are recorded in
`assets/wallpapers/prompts.json`. Alpine Dawn is the existing approved wallpaper.
The settings gallery uses the actual assets, not crops of a UI mockup. Named theme
icons and clock frames are derived from existing repository-owned SVG vectors.
