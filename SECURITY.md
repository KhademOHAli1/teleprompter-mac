# Security

Security fixes are accepted for the latest source release. This project does not promise a response time or provide a hosted service.

For a sensitive issue, use the repository's **Security → Report a vulnerability** feature when private vulnerability reporting is enabled. If it is unavailable, open a minimal issue asking the maintainers for a private reporting route; do not include credentials, private recordings, transcripts or exploit details in that issue.

Useful details include the version, macOS/Xcode version, provider, a neutral reproduction, and the expected versus observed behavior.

API keys are supplied by the user. They are held in memory or explicitly stored in macOS Keychain. Never commit a key or add one to CI. If a key has been exposed, revoke it with its provider before sharing a report.

Privacy behavior and data locations are described in [Privacy](docs/PRIVACY.md). The source checker is a limited safeguard, not a comprehensive security audit.
