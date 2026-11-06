# Clock refresh after suspend

All bar clocks, desktop clock widgets and calendar views use the shared
`ClockState` minute clock. A single system-bus logind monitor listens for
`PrepareForSleep(false)` and immediately re-arms the native SystemClock from
wall time. This avoids waiting for a deadline left over from before suspend.
The focus timer also recalculates its remaining duration and restarts its tick
on wakeup; an expired timer reloads its saved state.

The monitor also reports sleep preparation. Temporary panels close immediately
before suspend; see `resume-performance-2026-10-21.md` for surface lifecycle and
performance measurements.

No system time, timezone, NTP settings, theme or display geometry is changed.
The clock monitor retries after an unexpected exit. `gdbus` is already a shell
dependency for notification monitoring.

Diagnosis on 2026-10-21: system clock synchronized, NTP active, Asia/Almaty;
the journal recorded suspend from 01:12 until 12:52. The previous UI clocks
had no explicit resume refresh. Related upstream report:
https://github.com/quickshell-mirror/quickshell/issues/559

Validation: QML lint for changed components; isolated offscreen test pauses
the native clock, supplies logind sleep/wake signals and verifies immediate
re-arming and current wall time; organizer tests cover saved timer deadlines.
Live `quickshell ipc --path shell call clock status` reports clock/system time
and whether the sleep monitor is running. `clock refresh` manually re-arms it.
A physical suspend/resume cycle was not forced during development.
