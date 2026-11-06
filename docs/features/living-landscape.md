# Living landscape

The immersive desktop uses the existing wallpaper as its interface. Enable or
disable **Живой пейзаж · интерактивные точки** in Settings → Widgets. It is disabled
by default. The toggle controls the entire interactive surface, including landmark
dots, hover menus, application search, glow and music reflection, and saves immediately. The setting is stored separately in `~/.config/poly-shell/landscape.json`.
Widget positions, individual visibility preferences and Work/Vibe are preserved.
The top bar and individually enabled desktop widgets remain visible in either mode.

## Interaction

- Hover the light landmark: a circular arc reveals brightness, the existing theme
  wheel, night light, settings and lock. Theme dots apply an existing theme using
  its saved automatic-color preference. Unsupported hardware controls are disabled.
- Hover the lake: control the current native MPRIS player. The title and artist
  are real; previous/play/next follow the player's capabilities. Without a player,
  the explanatory empty state appears and playback controls are disabled.
- Click the mountain landmark: favorites emerge along an arc. The search field
  filters installed desktop entries; Enter launches the first result, Escape
  closes. Icons use the current theme and share favorites with the existing dock.
- Leaving the active interaction area begins closing immediately, without a
  hover delay. The area includes the path between a landmark and its controls.
- Right-click the exposed desktop to open the existing theme wheel.
- The top bar remains visible on empty workspaces and does not require edge hover.
  Ordinary widgets keep their configured visibility and positions alongside the
  landscape controls. Existing keyboard shortcuts are unchanged.

The native surface is on the Bottom layer, behind application windows. It owns
desktop right-click input while enabled; the old desktop input surface is disabled
to avoid competing fullscreen Bottom surfaces. Both desktop input surfaces exclude
the configured rectangles of enabled widgets so remapping either surface cannot
intercept widget clicks. These exclusions follow monitor and layout changes.
No overlay input grab is used.
Search obtains keyboard focus on demand after a click. Opening previews by hover
does not request keyboard focus. Existing top panels, overview, sleep and theme
application close the landscape controls.

## Themes and coordinates

`shell/logic/LandscapeGeometry.js` describes independent light, peak and music landmarks
for Alpine, Moon Lake, Forest Mist, Warm Desert, Northern Lights, Rose Sunset and
Timeline. Coordinates follow the original 1672 × 941 images through aspect-cover
cropping, including ultrawide and portrait outputs. Menus are kept within screen
bounds and scale independently of Work/Vibe. All surfaces, strokes, text, glows and
effects use the live semantic palette, including intermediate Timeline palettes.

Forest uses a patch of light in the mist; Northern Lights uses the aurora. Desert
uses a dune for music and does not invent a water reflection. Timeline adjusts its
light landmark/label for the lighting frame. Unknown imported/future themes receive
neutral usable landmarks and no assumed water; exact object placement requires a
new scene entry after inspecting that artwork.

## Reflection and motion

The reflection samples the actual music controls and waveform using
`ShaderEffectSource`. A baked Qt shader mirrors them, adds bounded horizontal
water distortion, tapers the banks and fades with depth. Reflection patches are
placed within the open-water region of each supported artwork. This is a local
water patch, not full-image semantic water segmentation. Different aspect ratios
keep controls usable but cannot preserve every original shoreline composition.

The waveform is a decorative animation driven by actual playback state, **not a
measurement of the audio spectrum**. Music phase advances only while its menu is
open and a player is playing. There is no idle animation timer or desktop polling.
Reduced motion stops the waveform and ripple motion and removes UI transitions.
Glow and reflection remain as static visual treatments. Build the reflection
shader with `scripts/build-shaders` after editing its GLSL source.

## Validation

`scripts/check` includes screen-crop, menu-boundary and reflection-policy tests and
strict QML lint. `scripts/check-living-landscape --live` exercises real search,
Foot launch, application occlusion, persistent bar visibility and MPRIS playback; it requires an
existing player and restores desktop/layout/playback state. Live verification on eDP-1 covers the three landmarks and pointer
exit in all seven themes, actual search and app launch, playback, persistent bar visibility,
application occlusion and normal widget configuration. Multiple physical displays and
alternative GPU drivers are not physically tested.

Actual implementation captures: [appearance](../assets/reference/living-landscape-alpine-light.png),
[music and reflection](../assets/reference/living-landscape-alpine-music.png),
[applications](../assets/reference/living-landscape-alpine-apps.png).

IPC: `landscape.status`, `landscape.enable BOOL`, `landscape.toggle` and
`landscape-SCREEN.status/show light|music|apps/close`.
