# Launchy

Launchy is a macOS launcher that recreates the full-screen Launchpad experience with a modern SwiftUI interface. It keeps your apps one keypress away, supports folders and search, and can live quietly in the background as a status-item daemon.

## Features

- Full-screen, translucent SwiftUI overlay with grid paging and smooth animations
- Automatic cataloging of apps from `/Applications`, `/System/Applications`, and `~/Applications`
- Folder creation, renaming, and drag-and-drop rearranging with the classic wiggle edit mode
- Incremental search across app names and bundle identifiers with type-to-focus passthrough
- Optional daemon mode that hides the Dock icon and keeps a menu bar item for quick relaunching
- Dedicated settings window for grid layout, scroll sensitivity, and background behavior
- Accessibility-aware keyboard monitor for instant search focus and ESC handling

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or the Swift 5.9 toolchain (command line tools installed)

## Quick Start

```sh
git clone https://github.com/lbenicio/launchy.git
cd launchy
make run
```

`make run` builds the debug binary and launches Launchy in-place. The first launch requests accessibility permissions so global keyboard shortcuts work as expected.

### Alternative workflows

- `swift run Launchy` – invoke with the Swift Package Manager directly
- `make build` / `make release` – compile debug or release artifacts
- `make bundle` – assemble a `.app` bundle under `.build/dist/Launchy.app`

## Configuration

Launchy stores user preferences via `AppSettings`:

- **Columns & Rows** – control the grid density
- **Scroll Sensitivity** – adjust how far the trackpad must scroll before paging
- **Run in background** – toggle daemon mode; when enabled, ESC hides Launchy and leaves the menu bar item active

Open the settings window from the menu bar item or with `Command + ,` while Launchy is active.

## Deployment

Automated release deployments are handled by `scripts/deploy` and surfaced through the Makefile:

```sh
make deploy                    # merges develop -> main, builds release, pushes
make deploy DEPLOY_ARGS="--dry-run"  # simulate without mutating the repo
```

The script enforces a clean working tree, performs fast-forward pulls, runs a release build, and pushes to the selected remote. See `scripts/deploy --help` for additional options (custom branches, skip tests, etc.).

## Development

Useful commands while contributing:

- `make test` – run the Swift test suite
- `make format` – apply `swiftformat` (if installed)
- `make lint` – run `swiftlint` (if installed)
- `make clean` – remove build and distribution artifacts

The codebase lives under `src/` and is organised into `Application`, `Domain`, `Infrastructure`, and `Interface` modules. Window configuration utilities and settings management reside in `src/Infrastructure`, while SwiftUI views live in `src/Interface`.

## Contributing

Issues and pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines and review the [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## License

Launchy is released under the terms of the [GPLv3 License](LICENSE.txt).
