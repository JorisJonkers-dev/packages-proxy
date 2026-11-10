# packages-proxy

[git-pkgs/proxy](https://github.com/git-pkgs/proxy) at a pinned release, with the estate's own
patches applied, built as `ghcr.io/jorisjonkers-dev/packages-proxy`. The estate's package proxy
at packages.jorisjonkers.dev (estate `platform/packages/`) runs this image.

This repository holds no copy of upstream's source: `proxy/Dockerfile` fetches the release at
`UPSTREAM_COMMIT`, applies `proxy/patches/*.patch` in order, runs upstream's test suite on the
result, and builds the binary. Upstream is GPLv3, and so is this repository.

## Patches

| Patch | What it changes | Drop it when |
|---|---|---|
| `0001-npm-latest-by-semver-order.patch` | When cooldown removes the version npm's `dist-tags.latest` names, `latest` moves to the highest remaining version below it by semver order, skipping prereleases, instead of the most recently published one. Without it a 7-day cooldown pointed `latest` at a Windows-only prerelease of `@openai/codex`, a canary of `next`, and an 11.x backport of `pnpm`. | An upstream release picks the replacement `latest` by semver order. |

## Versions

`VERSION` is upstream's release followed by `-jj.<n>`, this repository's patch level on it, for
example `0.11.0-jj.1`. A merge that changes `VERSION` releases `v<VERSION>` and publishes the
image. Bump it with every change to the Dockerfile or the patches.

## Moving to a new upstream release

1. Set `UPSTREAM_COMMIT` in `proxy/Dockerfile` to the release's commit; the release must be at
   least 7 days old.
2. Check every patch against the release: drop the patches upstream now covers, and refresh the
   rest so they apply (`git apply --check`).
3. Set `VERSION` to `<release>-jj.1`, or to the upstream release alone if no patch is left, in
   which case estate can return to upstream's image.
4. After the release publishes, pin the new digest in estate's `images.lock.yml`.

## Checks

- `docker buildx build --target test proxy` applies the patches and runs upstream's suite.
- `scripts/smoke-test.sh <image>` runs the image as the estate does (uid 1000, read-only root,
  no capabilities) and checks that `next`'s `latest` is not a prerelease.
