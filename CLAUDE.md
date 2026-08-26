# CLAUDE.md

This file gives Claude Code context about this project.

## Project Overview

Self-hosted n8n workflow automation running in Docker, with optional Cloudflare Tunnel for public HTTPS access. No public IP or port forwarding required. Cross-platform (macOS, Windows, Linux) via a single Python script.

## Repository Structure

```
docker-compose.yml          # n8n + runners services (reads from .env)
n8n-task-runners.json       # JS/Python runner config (mounted into runners container)
.env.sample                 # Environment variable template — copy to .env
scripts/
  launch.py                 # Cross-platform: setup/start/stop/restart/status/logs/tunnel (stdlib only)
docs/
  architecture.md           # Component diagram and data flow
  development.md            # Setup guide and daily commands
  cloudflare.md             # Cloudflare Tunnel detailed guide
  deployment.md             # Backups, auto-start, migration
.github/
  workflows/ci.yml          # Validates docker-compose and launch.py
```

## Development Commands

```bash
# First-time setup
setup:     python3 scripts/launch.py setup

# Start n8n + runners + tunnel, then tail n8n logs
dev:       python3 scripts/launch.py start

# Stop everything (n8n, runners, Cloudflare tunnel)
stop:      python3 scripts/launch.py stop

# Container + tunnel status and a health check
status:    python3 scripts/launch.py status

# Cloudflare tunnel only, in the foreground
tunnel:    python3 scripts/launch.py tunnel

# View n8n logs on demand
logs:      python3 scripts/launch.py logs

# Validate docker-compose and launch.py
lint:      python3 -m py_compile scripts/launch.py && docker compose config --quiet

# Update n8n to latest image
update:    docker compose pull && docker compose up -d
```

On Windows, invoke the same commands with `python` instead of `python3` (e.g. `python scripts\launch.py start`).

## Code Conventions

- Follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`
- Branch names: `feat/<slug>`, `fix/<slug>`, `chore/<slug>`
- All PRs target `main` and require at least one CODEOWNER approval

---

## Security And Secrets

- Never hardcode or commit credentials, tokens, secrets, passwords, API keys, certificates, or private keys.
- Store all real secrets only in local `.env` files.
- Keep `.env` untracked, and never add it to Git.
- Create and keep `.env.sample` files in Git as the placeholder template for each app or test setup.
- Use `.env.sample` to show required keys and safe placeholder values only.
- Do not put real secrets, tokens, or passwords in `.env.sample`.
- Use `.env.example` only if an existing app already depends on it, otherwise prefer `.env.sample`.
- Before every commit or push, inspect the staged diff and confirm no secret material is present.
- Never commit or push code automatically; those actions must always be performed manually by the user.
- Do not print secret values in logs, tests, docs, comments, or error messages.
- Fail fast if required environment variables are missing instead of falling back to hardcoded values.
- If a secret is found in code or history, remove it immediately and rotate it.
- Treat any file containing credentials as sensitive and exclude it from version control.

## Naming And Structure

- Use clear and appropriate naming conventions for files, variables, functions, and methods.
- Avoid long file names and long function names; choose names that are easy to understand and reference.
- Use lowercase file names, function names, and method names unless the existing codebase requires a different convention.

## Visual And Documentation

- Use appropriate color codes and simple, meaningful icons for status indicators.
- Write README files with a clear, attractive structure that gives a step-by-step guide to use, deploy, and understand the app.
- Keep README content practical and easy to scan so the app purpose and setup are obvious.

## Testing

<!-- Describe the testing strategy for this project: unit, integration, e2e. -->

- When needed, create test cases to quickly verify the written code.
- Use temporary credentials, tokens, and secrets for tests, and keep them in `.env` files only.
- Maintain test-specific secrets separately for each test case so they are isolated and not reused across cases.
- Store test reports in a dedicated folder inside the test directory, and keep that folder out of Git.
- Clean up every resource created during testing.
- When possible, run tests in a Docker container so the host environment stays clean and each run starts fresh.

## AI Assistance Notes

- Prefer editing existing files to creating new ones.
- Do not add abstractions or features beyond what the task requires.
- Do not add comments that explain WHAT the code does — only WHY when non-obvious.
- Check `docs/` before answering architecture questions.
- Never commit or push on behalf of the user — always leave that action to them.
- If in doubt about whether a value is sensitive, treat it as a secret and keep it out of the repository.
