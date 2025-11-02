# Contributing to Launchy

We are excited that you want to improve Launchy! This document explains how to set up your development environment, follow the project conventions, and submit effective pull requests.

## Expectations

- Treat maintainers and community members with respect. The [Code of Conduct](CODE_OF_CONDUCT.md) applies to all interactions.
- Prefer opening an issue or discussion for sizable changes before submitting code.
- Keep pull requests focused. Small, cohesive changes are easier to review and merge.
- Document non-obvious logic with succinct comments.

## Getting Started

### Prerequisites

- macOS 13 Ventura (or newer)
- Xcode 15 / Swift 5.9 command-line tools (`xcode-select --install`)
- Optional: Homebrew (`https://brew.sh`) for installing lint/format tools

### Repository Setup

```sh
git clone https://github.com/lbenicio/launchy.git
cd launchy
make build
```

Helpful Makefile targets:

- `make run` – launch Launchy in debug mode
- `make test` – execute the unit test suite
- `make format` – run `swiftformat` over the `src/` tree (needs Homebrew install)
- `make lint` – run `swiftlint` if available
- `make clean` – delete build and distribution artifacts

The SwiftUI app code resides in `src/Interface`, shared logic in `src/Application` and `src/Domain`, and system integrations in `src/Infrastructure`.

## Branching & Workflow

1. Branch from `develop`: `git checkout -b feature/short-description`
2. Sync frequently: `git pull --rebase origin develop`
3. Commit with clear messages that describe _why_ the change exists
4. Push to your fork (or to the shared repo if you have access)

We recommend enabling pre-commit hooks or aliases for formatting, but they are optional as long as the CI checks pass.

## Coding Standards

- Follow Swift API Design Guidelines and Apple Human Interface Guidelines
- Keep UI code declarative and avoid business logic inside views when possible
- Ensure new features are accessible (keyboard support, VoiceOver-friendly labels)
- Avoid force unwraps unless they are logically guaranteed
- Include unit tests for new business logic and adjust existing tests when behavior changes

### Style Tools

- `swiftformat` is the authoritative formatter. Run `make format` prior to opening a PR.
- `swiftlint` surfaces common anti-patterns. Resolve or justify any warnings.
- For shell scripts, keep them POSIX/Bash compatible and documented with `usage` output.

## Testing

- Execute `make test` or `swift test` locally
- When UI or lifecycle behavior changes, document manual verification steps in your PR
- CI will run `swift build` and the test suite; make sure it passes before requesting review

## Submitting a Pull Request

1. Push your branch and open a PR against `develop`
2. Fill in the pull request template: describe the change, rationale, and testing
3. Add screenshots or screen recordings for UI updates
4. Respond promptly to review feedback; update your branch with additional commits or amend as needed
5. Once approved, a maintainer will merge the PR. Delete your branch afterwards to keep the repo tidy.

## Release Management

Maintainers promote builds with `scripts/deploy` (exposed via `make deploy`). The workflow merges `develop` into `main`, runs a release build, and pushes to the configured remote:

```sh
make deploy
make deploy DEPLOY_ARGS="--dry-run"  # safe rehearsal
```

## Reporting Issues

- Open an issue for bugs, feature requests, or questions
- Provide steps to reproduce, expected vs. actual behavior, and environment details
- Attach screenshots or logs where helpful

## Getting Help

If you are stuck or unsure about anything, open an issue or discussion and we will assist. We are grateful for every contribution—thank you for helping make Launchy better!
