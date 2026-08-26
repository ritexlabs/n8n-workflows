# Security Policy

## Reporting a Vulnerability

If you find a security issue in this repository (scripts, Docker configuration, or
CI), please report it privately rather than opening a public issue:

- Use GitHub's [private vulnerability reporting](../../security/advisories/new) for this repository, or
- Open a draft security advisory under the **Security** tab.

Please do not include real secrets, tokens, or credentials in a report — describe
the issue and, if needed, share redacted examples.

## Scope

This repository provides Docker Compose configuration and helper scripts for
self-hosting n8n. It does not host any shared/multi-tenant service — each user runs
their own instance. Vulnerabilities in n8n itself should be reported upstream to the
[n8n project](https://github.com/n8n-io/n8n/security).

## Supported Versions

Only the `main` branch is maintained. There are no maintained release branches.

## Hardening Notes

See [docs/deployment.md](../docs/deployment.md#production-checklist) for the
production readiness checklist covering secrets, network exposure, and backups.
