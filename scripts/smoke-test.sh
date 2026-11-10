#!/usr/bin/env bash
# Starts the image restricted (uid 1000, a read-only root, every capability dropped), with only
# /data and /tmp writable, as the estate runs it. Then checks two things against npm: the proxy
# serves, and a cooldown that holds back a package's latest moves latest to a stable version, not
# to a prerelease (patches/0001).
# Usage: scripts/smoke-test.sh <packages-proxy-image>
set -euo pipefail

name=smoke-packages-proxy
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

config=$(mktemp)
cat >"$config" <<'YAML'
listen: ":8080"
storage:
  url: "file:///data/artifacts"
database:
  driver: "sqlite"
  path: "/data/proxy.db"
cooldown:
  default: "7d"
YAML
chmod 644 "$config"

docker run -d --name "$name" --read-only --cap-drop ALL --user 1000:1000 \
  --tmpfs '/data:uid=1000,gid=1000,mode=0700' --tmpfs '/tmp:uid=1000,gid=1000,mode=1777' \
  -v "$config:/etc/proxy/config.yaml:ro" -p 127.0.0.1:18080:8080 \
  "$1" serve -config /etc/proxy/config.yaml >/dev/null

served=false
for _ in $(seq 1 30); do
  if curl -fsS -m 3 http://127.0.0.1:18080/health >/dev/null 2>&1; then served=true; break; fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]; then
    docker logs "$name" 2>&1 | tail -30
    echo "the proxy exited before it served" >&2
    exit 1
  fi
  sleep 2
done
[ "$served" = true ] || { docker logs "$name" 2>&1 | tail -30; echo "the proxy never served" >&2; exit 1; }

# next publishes canaries daily and a stable release every few weeks, so a 7-day cooldown that
# holds back its latest leaves canaries newer than every eligible stable release.
latest=$(curl -fsS -m 60 http://127.0.0.1:18080/npm/next | python3 -c 'import json,sys; print(json.load(sys.stdin)["dist-tags"]["latest"])')
case "$latest" in
  *-*) echo "next's latest is the prerelease $latest" >&2; exit 1 ;;
  "") echo "next has no latest" >&2; exit 1 ;;
esac
echo "next's latest is $latest"

others=$(docker top "$name" -eo pid,uid | tail -n +2 | awk '$2 != 1000')
[ -z "$others" ] || { echo "the proxy runs a process as another uid: $others" >&2; exit 1; }
echo "smoke test passed"
