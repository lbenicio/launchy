# Security Policy

We take the security of Launchy seriously. This policy outlines the supported versions of the project and the process for reporting potential vulnerabilities.

## Supported Versions

Security fixes are applied to the following branches:

| Version/Branch | Supported |
| -------------- | --------- |
| `main`         | Yes       |
| `develop`      | Best effort (active development) |

If you are running Launchy from another branch or from a tagged pre-release, please rebase onto `main` or `develop` to receive the latest patches.

## Reporting a Vulnerability

1. **Do not** disclose security issues publicly before they are fixed.
2. Submit a private report using GitHub's ["Report a vulnerability"](https://github.com/lbenicio/launchy/security/advisories/new) workflow, or email `security@lbenicio.dev`.
3. Include as much detail as possible:
   - A clear description of the issue.
   - Steps to reproduce.
   - Affected versions or commit SHAs.
   - Any available mitigation or workaround ideas.

We acknowledge receipt within 3 business days. If you do not hear back in that window, please follow up via email.

## Disclosure Policy

- You will receive updates about the investigation status and expected timelines.
- Once a fix is ready, we will coordinate a public disclosure that credits the reporter (unless anonymity is requested).
- Security advisories will be published in the repository and, when applicable, referenced in release notes.

## Hardening Checklist

To help reduce attack surface in production builds:

- Build with the latest Xcode command-line tools (`xcode-select --install`).
- Enable macOS code signing and notarization for distributed binaries.
- Restrict accessibility permissions to Launchy only if global key monitoring is required.
- Keep the `scripts/deploy` workflow under the control of trusted maintainers.

Thank you for helping keep Launchy and its users safe.
