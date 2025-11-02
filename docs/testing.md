# Testing Handbook

This guide describes how Launchy is validated across macOS and Linux CI environments, how the test target is organised, and best practices for contributing new automated coverage.

## Overview

Launchy ships with a single XCTest target, `LaunchyTests`, which mirrors the production source tree. Every Swift file under `src/` has at least one corresponding test file under `tests/`. The suite focuses on three pillars:

1. **Deterministic unit coverage** for stores, models, and infrastructure helpers.
2. **Hostability checks** for SwiftUI views and AppKit bridges to ensure they can be embedded safely at runtime.
3. **Regression safety** for persistence, keyboard monitoring, and accessibility permission flows.

## Running Tests

### macOS

```bash
swift test
# or
make test
```text

`swift test` uses the toolchain declared in `Package.swift` (Swift 6.2). When running inside Xcode, ensure the command-line tools match the Swift version to avoid build mismatches.

### Linux & GitHub Actions

Unit tests run on Ubuntu 22.04 via `.github/workflows/unit-tests.yml`. The workflow:

1. Installs required signing keys for the Swift toolchain.
2. Downloads and verifies the Swift 6.2 tarball for `ubuntu22.04`.
3. Executes `make test`.

You can reproduce the job locally with [`act`](https://github.com/nektos/act):

```bash
act -j tests --container-architecture linux/amd64
```

Allow the first run to complete the toolchain download (the archive is cached for subsequent runs).

### Focused Execution

Use XCTest filtering to run specific files or test cases:

```bash
swift test --filter AppCatalogStoreTests/testDismissPresentedFolderOrClearSearchClearsPresentedFolder
```

This is helpful when iterating on a single feature without running the full suite.

## Test Layout

```text
Tests/
├── Application/
│   ├── AppCatalogStoreTests.swift
│   └── AppSettingsTests.swift
├── Domain/
│   └── ModelsTests.swift
├── Infrastructure/
│   ├── configurators/WindowConfiguratorTests.swift
│   ├── loaders/AppCatalogLoaderTests.swift
│   ├── managers/SettingsWindowManagerTests.swift
│   ├── monitors/KeyboardMonitorTests.swift
│   ├── permissions/AccessibilityPermissionTests.swift
│   ├── persistence/LayoutPersistenceTests.swift
│   └── stores/IconStoreTests.swift
├── Interface/
│   ├── App/LaunchyAppTests.swift
│   └── Views/
│       ├── AppIconViewTests.swift
│       ├── ContentViewTests.swift
│       ├── FolderOverlayTests.swift
│       ├── GridMetricsTests.swift
│       ├── SettingsViewTests.swift
│       └── components/VisualEffectViewTests.swift
└── XCTestManifests.swift (generated for Linux)
```

Key conventions:

- Each test file targets a single production file or closely related group.
- Utility methods (e.g., temporary directory helpers) live inside the test files that need them to keep the suite isolated.
- When asynchronous work is involved, tests use `@MainActor` and the new `async` XCTest APIs where appropriate.

## Writing New Tests

1. **Mirror the structure**: place the new test under `tests/<Module>/...` matching the source location.
2. **Use deterministic data**: avoid network or file system dependencies outside temporary directories created within the test.
3. **Leverage debug helpers**: components like `KeyboardMonitor` and `AccessibilityPermission` expose `#if DEBUG` APIs (`resetForTesting`, etc.) specifically for tests. Avoid using them in production code.
4. **Cover both success and failure paths**: ensure tests assert behaviour when operations succeed and when inputs are invalid or unavailable.
5. **Keep UI tests lightweight**: hosting a SwiftUI view should rely on `NSHostingController` and avoid adding long-running animations. Most view tests simply instantiate and lay out the view hierarchy to catch runtime crashes.

## Linux Considerations

- Avoid using APIs that are macOS-only within tests that run on Linux. If a test must rely on AppKit, wrap it in `#if os(macOS)` or keep it focused on macOS-specific files.
- Ensure new tests build under SwiftPM without Xcode—SPM has stricter module visibility rules.
- Update `tests/XCTestManifests.swift` when adding new test cases so Linux discovery stays in sync (run `swift test --generate-linuxmain` if needed).

## Debugging Failures

- Re-run with `swift test --verbose` to see build commands and captured output.
- Use `swift test --enable-code-coverage` when investigating missing coverage locally.
- For flaky behaviour, add logging guarded by `#if DEBUG` in the production code and remove it once resolved.

## Pull Request Checklist

- [ ] All new logic includes targeted unit tests.
- [ ] `swift test` passes locally on macOS.
- [ ] `act -j tests` succeeds (optional but recommended before opening PRs).
- [ ] Test files follow the same naming and module conventions as the production code.

Maintaining strong automated coverage keeps Launchy reliable across macOS releases and Linux CI environments. Reach out via issues or pull requests if additional testing utilities would be helpful.
