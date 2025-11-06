# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-11-06

- chore: Add `scripts/sync_docs_to_wiki.sh` and `make wiki` target for GitHub Wiki syncing
- chore: Introduce CodeQL workflow with manual Swift 6.2 toolchain installation
- chore: Update release workflow to install Swift 6.2 directly on macOS runners
- fix: Harden changelog updater for macOS `awk` compatibility and preserve formatting

## [0.1.1] - 2025-11-04

- fix: Update release tagging message for clarity
- feat: Enhance release workflow with changelog verification and extraction
- feat: Add unit tests for AppItem and CatalogEntry functionality
- fix: Update .gitignore to include workflow files and ensure proper formatting
- fix: Add MERGE_FILTER_AUTHOR for dependabot in auto-merge workflow
- feat: Add linting and unit testing workflows for improved code quality
- feat: Enhance lint and unit test workflows with detailed logging and summary reports
- Refactor FolderOverlay view for improved readability and structure
- fix: Remove unnecessary nil initializations for optional properties
- fix: Update release workflow to ensure correct version handling and changelog updates
- fix: Update Swift toolchain setup in workflows to use correct action and parameter
- fix: Update Swift toolchain setup in workflows to use correct action
- chore: Update Swift toolchain version to 6.2 in workflows and Package.swift
- refactor: Simplify monitor installation and removal in KeyboardMonitor, AccessibilityPermission, IconStore, and ContentView
- chore: Remove obsolete lint and unit test workflows and related test files
- chore: Update workflow triggers in notifications.yml to reflect current workflows
- test: Add unit tests for various components and functionalities
- Refactor documentation and enhance structure
- chore: Remove obsolete technical guide from documentation
- chore: Add comprehensive technical guide for Launchy
- chore: Update README.md with additional badges for build status, version, license, and platform

## [0.1.0] - 2025-09-15

- Initial public release of Launchy with grid-based catalog browsing, folder editing, and keyboard navigation.
