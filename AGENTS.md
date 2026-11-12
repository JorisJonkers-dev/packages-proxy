# Agents

Guidance for any coding agent working in this repository.

The repository's agent contract is [CLAUDE.md](CLAUDE.md). The estate-wide conventions (labels, traps) are in the [estate contract](https://github.com/JorisJonkers-dev/workspace/blob/main/CLAUDE.md); read both before non-trivial changes.

This repository builds git-pkgs/proxy at a pinned release with the estate's patches (`proxy/patches`) applied; `proxy/Dockerfile` does the build. Never send anything upstream. Bump `VERSION` with every change that alters the image.

## Build and test

- `scripts/smoke-test.sh packages-proxy:ci` starts the built image restricted and checks it serves (see `.github/workflows/ci.yml`).
- CI also runs shellcheck over `scripts/*.sh` and actionlint over the workflows.
