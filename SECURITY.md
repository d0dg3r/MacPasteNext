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

Out of scope for security reporting:

- General usage/support questions
- Feature requests
- UI/UX improvements without security impact

## Response Process

The project will:

1. Acknowledge the report
2. Validate and reproduce
3. Prepare a fix
4. Publish a patched release and advisory notes when appropriate

Target response timelines:

- Initial acknowledgment: within 72 hours
- Triage outcome (confirmed / needs-info / rejected): within 7 days
- Critical/high issues: prioritized for the next patch release

Severity guidance:

- Critical: remote code execution, privilege escalation, credential/key compromise
- High: meaningful local security bypass or sensitive data exposure
- Medium: limited-impact abuse paths requiring specific preconditions
- Low: hard-to-exploit or low-impact issues

## Scope Notes

This project is a local macOS utility app and does not run a backend service. Most security concerns are expected around:

- Local permission handling (Accessibility, automation behavior)
- Packaging/signing integrity
- Dependency or toolchain issues in release workflow
