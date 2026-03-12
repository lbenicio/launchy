# Contributing to Launchy

Welcome to Launchy! We appreciate your interest in contributing to this macOS Launchpad replacement. Whether you're fixing a bug, improving documentation, or building a new feature, this guide will help you get started.

## Prerequisites

- **macOS 14+** (Sonoma or later)
- **Swift 6.2 toolchain** (ships with Xcode 26 or can be installed via [swiftly](https://github.com/swiftlang/swiftly))

## Getting Started

```bash
# Clone the repository
git clone https://github.com/your-username/launchy.git
cd launchy

# Build the project
make build

# Run in debug mode
make run

# Run the test suite
make test
```

## Development Workflow

The `Makefile` exposes the most common tasks:

| Command      | Description                                              |
| ------------ | -------------------------------------------------------- |
| `make fmt`   | Format code with **swift-format** (config in `.swift-format`) |
| `make lint`  | Check formatting without modifying files                 |
| `make test`  | Run the test suite                                       |
| `make build` | Release build                                            |
| `make run`   | Run in debug mode                                        |

Please run `make fmt` and `make lint` before submitting a pull request.

## Testing

Tests live in the `tests/` directory and mirror the structure of `src/`. A few conventions to be aware of:

- **`StubFileManager` pattern** — Tests that touch persistence or the filesystem use a stub file manager so they never read from or write to the real disk. If you add new service-level tests, follow this pattern to keep the suite fast and deterministic.
- **`@MainActor`** — View-model tests run on the main actor to match production threading.
- **`XCTestCase`** — All test classes inherit from `XCTestCase`.

## Project Structure

```
src/
├── App/          # App entry point, AppDelegate, global hotkey
├── Extensions/   # Array helpers
├── Models/       # AppIcon, LaunchyItem, LaunchyFolder, GridSettings, etc.
├── Services/     # Data persistence, app discovery, icon caching, settings
├── ViewModels/   # LaunchyViewModel, DragCoordinator
└── Views/        # SwiftUI views and components
tests/            # Unit tests mirroring src/ structure
```

## Pull Requests

1. Fill out the **PR template** when you open a pull request.
2. **Link relevant issues** (e.g., `Closes #42`).
3. **Include screenshots or screen recordings** for any UI changes.
4. Keep PRs focused — one logical change per PR makes reviews faster.

## Roadmap

See [`TODO.md`](TODO.md) for current priorities and planned features. If you want to pick something up, leave a comment on the corresponding issue (or open one) so we can avoid duplicate work.

## Code of Conduct

This project follows the guidelines described in [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Please read it before participating.