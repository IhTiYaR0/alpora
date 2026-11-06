# Post-suspend desktop load — 2026-10-21

## Diagnosis

The reported session had resumed from s2idle at 12:52 after sleeping overnight.
At inspection, about 10 GiB RAM was available, swap was unused and CPU/memory/IO
pressure averages were zero. Quickshell RSS was about 570 MiB. The approximately
3 GiB service-cgroup reading includes launched applications and cached resources;
it is not Quickshell's RSS. Kernel logs showed successful amdgpu resume and no
GPU reset/timeout in the inspected period. Repeated Realtek Wi-Fi firmware
warnings were present, but no evidence tied them to desktop frame stalls.

Two initial quiet samples attributed about 60% graphics-engine time to Hyprland
and 0–0.1% to Quickshell. The closed launcher was still a mapped 1920×1080 layer
with compositor blur enabled. Temporarily disabling only its blur lowered the
Hyprland figure to about 31%; unmapping it lowered it to about 28% but broke fast
shortcut-following text input. Both experiments were reverted.

## Change

Keep the launcher mapped at 1×1 while closed, expanding its surface for the
existing reveal and shrinking only after closing finishes. The controls keep
their logical layout and prepared keyboard focus. Open-panel blur, palette,
rounding, display scale and device/power settings remain unchanged.

The shared logind monitor now also reports sleep preparation. Close temporary
bar panels and quick settings before suspend. PanelMotion bypasses its Behavior
while sleeping so surfaces and input grabs are released without waiting for an
animation deadline to complete after resume.

## Measurements and validation

Read-only 12-second samples with `scripts/check-render-load`:

| State | Mean GPU busy | Median GPU busy | Hyprland gfx-engine time |
| --- | ---: | ---: | ---: |
| Original fullscreen closed launcher | 61.6% | 99% | 59.86% |
| Final mapped 1×1 closed launcher | 22.5% | 0% | 28.03% |

These are short sequential samples on an interactive desktop, not a controlled
benchmark. Remaining GPU load is nonzero; this does not establish that all
post-suspend stutter has been eliminated or that suspend created the extra load.

Strict QML lint passes for modified components. The isolated real-QML test sends
sleep/wake messages, verifies the panel snaps shut during preparation and checks
immediate clock re-arming after wakeup. No physical suspend was forced.

Fast-input check: 11/12 passed with the final geometry in two runs. The first
US trial at a 2 ms key delay lost initial characters. A control run using the
original fullscreen implementation also failed that trial and passed the other
11; the pre-existing initial focus race remains unresolved. Completely unmapping
the launcher failed 12/12 and was rejected. Ordinary 5/10 ms trials and RU input
passed with the final mapped geometry.

Temporary before-change copies: `/tmp/poly-launcher-before-resume-perf.qml` and
`/tmp/poly-hypr-before-resume-perf.lua`. The Hyprland config was restored byte for
byte after the temporary blur comparison.

## Follow-up: the user still observed low FPS

The smaller closed surface reduced idle load but did not resolve the reported
problem. Further checks measured frames instead of treating GPU utilization as
FPS:

- A new independent Qt animation, including a larger 800×650 translucent window,
  produced about 60 frames/s with 17–18 ms p95 callbacks. Temporarily removing all
  Poly Shell visual surfaces did not materially change that result. Repeated
  workspace transitions during the independent probe also retained about 60 FPS.
- Actual launcher window frame callbacks during its 320 ms opening were mostly
  33–34 ms apart, with only 10–11 intermediate frames. Restarting only Poly Shell,
  preserving Telegram and other applications, did not change that result.
- A temporary performance power profile also retained 33 ms intervals and was
  restored to balanced. New compositor render scheduling improved them to about
  20–21 ms but was restored to its default false setting.
- Disabling only compositor blur, with the same launcher and animation, produced
  20 intermediate frames and predominantly 16–17 ms intervals in both trials.
  Blur was restored immediately after this comparison.

Final change: the three generated popup/launcher layer rules now use `xray = true`
with blur still enabled. This reuses wallpaper/background blur instead of blurring
the application contents beneath each panel. It changes what is sampled behind
the glass; it preserves theme colors, alpha, geometry and rounding. Existing bar
glass already used xray. Both the live config and the generated project rules were
updated, with a backed-up, idempotent upgrade path for the previous generated block.

After settling, two launcher captures contained 19 and 20 intermediate frames,
predominantly 16–17 ms apart. Quick settings captured 14 and 17 intermediate frames;
most intervals were also 16–17 ms, with one 31 ms gap in the first trial. Earlier
cold-cache trials still had occasional 29–43 ms gaps; this is not a guarantee of
perfect frame pacing under every workload.

Fourteen appearance tests passed, including migration from the previous uncached
rules. Hyprland reports no configuration errors. Debug overlay is off, balanced
power profile is restored, temporary shell-isolation edits were restored, and the
temporary service KillMode override was removed. The existing Telegram PID survived
the isolated shell restart. New gdbus monitors are active; orphaned diagnostic
monitors were terminated.

Persistent before-change backup:
`~/.local/state/poly-shell/backups/resume-blur-20261021-1329/hyprland.lua`.

These observations establish a reproducible blur-related panel FPS bottleneck in
the current resumed session. They do not establish why the user observes a
difference after suspend versus boot. No physical suspend/reboot comparison was
forced, and no kernel/driver/GPU clock settings were changed.
