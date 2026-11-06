# Contributing to ALPORA

ALPORA is the public project name. `poly-shell` remains the technical command,
Python module, service prefix and configuration namespace. Preserve existing
user data and compatibility when changing them.

## Development

Use an existing Hyprland environment matching the [installation baseline](docs/installation.md).
Install Python, Node.js, Quickshell and qmllint, then run:

```sh
./scripts/check
```

The check runs Python tests, JavaScript simulations and strict QML lint. It does
not establish compatibility with every GPU or physical device. Native `--live`
checks under `scripts/` move the real pointer or open windows; read each script
before using it and keep them out of unattended CI.

Use semantic colours from Session and the shared theme. Preserve theme/mode
independence, reduced motion, saved geometry and real device state. Follow
[the theme contract](docs/theme-design-contract.md) and `AGENTS.md`.

Keep changes focused. Include the concrete problem, resulting behaviour and
relevant checks in a pull request. Add meaningful regression coverage for state,
input or recovery bugs. Keep screenshot claims tied to the actual implementation.

## Bug reports

Include reproduction steps, expected/actual behaviour, distribution, Hyprland,
Quickshell and Qt versions, monitor scale and the component affected. Add a
relevant log excerpt with personal data removed. Screenshots are useful for
layout problems; device names and clipboard/history contents may be private.

## Assets

Include provenance and license notices for third-party material. Do not replace
upstream attribution with the project's MIT license. Generated art should be
identified as generated, and design proposals labelled as proposals.
