# Repository Guidelines

This document sets shared expectations for contributing to this repository. Keep changes small, well‑explained, and easy to review.

## Project Structure & Module Organization
- `src/` application code; subfolders by domain (e.g., `src/auth/`).
- `infra/` infrastructure as code (e.g., Terraform, Helm, Kustomize).
- `scripts/` developer utilities; keep POSIX‑sh compatible.
- `tests/` mirrors `src/` structure; one suite per module.
- `docs/` architecture notes and runbooks.
- `.github/workflows/` CI definitions.

Example: `src/service_a/`, `tests/service_a/`, `infra/environments/dev/`.

## Build, Test, and Development Commands
Prefer `make` targets when present; otherwise use scripts. Examples:
- `make setup` — install toolchain and pre‑commit hooks.
- `make dev` — run local dev server or watcher.
- `make build` — compile/package artifacts.
- `make test` — run unit tests with coverage.
- `make lint` / `make format` — static checks and auto‑formatting.
If no `Makefile`, look for equivalent in `scripts/` (e.g., `scripts/test.sh`).

## Coding Style & Naming Conventions
- Indentation: 2 spaces for YAML/JSON; 4 for Python; follow language defaults (e.g., `gofmt`, Prettier).
- Filenames: kebab‑case for docs/assets; snake_case for scripts; Go package dirs lower‑case no underscores; Classes use `PascalCase`.
- Tools (when applicable): `pre-commit`, `black`, `ruff`, `eslint + prettier`, `gofmt`, `shellcheck`.

## Testing Guidelines
- Tests live in `tests/…` mirroring `src/…`.
- Naming: Python `test_*.py`, Go `*_test.go`, JS/TS `*.test.ts`.
- Target ≥80% coverage for changed code; include negative/edge cases.
- Run locally with `make test` (or `scripts/test.sh`).

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`, `chore:`.
- Keep subject ≤72 chars; explain why in the body.
- Branch names: `type/short-topic` (e.g., `feat/authn-middleware`).
- PRs must include: clear description, linked issues (e.g., `Closes #123`), testing notes, and screenshots/logs for UX/ops changes. For infra, attach `terraform plan`/`kubectl diff` output.

## Security & Configuration Tips
- Never commit secrets; provide `*.example` files and use env vars/secret managers (e.g., SOPS, AWS Secrets Manager).
- Run `make lint` and `pre-commit run -a` before pushing.

## Agent‑Specific Instructions
- Follow this file’s scope rules; keep edits minimal and focused.
- Prefer `rg` for search, small patches via `apply_patch`, and reference paths explicitly (e.g., `src/module/file.ts:12`).
