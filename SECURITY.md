# Security Policy

## Supported Versions

Security fixes are provided for:

- The latest release (`main` and newest tag)

Older tags may not receive patches.

## Reporting a Vulnerability

Please do not open public issues for security problems.

Use one of these channels instead:

- GitHub Security Advisory (preferred)
- Private contact via GitHub to the maintainer

Include:

- Clear description of the issue
- Steps to reproduce
- Impact and affected versions
- Any suggested mitigation

## Response Process

The project will:

1. Acknowledge the report
2. Validate and reproduce
3. Prepare a fix
4. Publish a patched release and advisory notes when appropriate

## Scope Notes

This project is a local macOS utility app and does not run a backend service. Most security concerns are expected around:

- Local permission handling (Accessibility, automation behavior)
- Packaging/signing integrity
- Dependency or toolchain issues in release workflow
