#!/usr/bin/env bash
# Vendor the multi-platform skills into this repository's .claude/ directory.
#
# For cloud sessions, which start from a fresh clone and load nothing from your
# machine: plugins installed locally do not follow you there, but anything
# committed under .claude/ does. Running this once makes the skills available in
# this repo forever, including on a phone.
#
#   curl -fsSL https://raw.githubusercontent.com/tougenrip/multi-platform/main/bootstrap.sh | bash
#
# Safe to re-run: it replaces the vendored copy and touches nothing else.
set -euo pipefail

REPO="${MP_REPO:-tougenrip/multi-platform}"
REF="${MP_REF:-main}"
BASE="https://raw.githubusercontent.com/${REPO}/${REF}"

# Land in the repository root when run from a subdirectory, and tolerate a
# directory that is not a git repo yet: an empty cloud workspace is the point.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

SKILLS="init apptest build build-test"
FILES="
skills/init/SKILL.md
skills/init/references/backend-supabase.md
skills/init/references/backend-postgres-minio.md
skills/init/scripts/preflight.sh
skills/apptest/SKILL.md
skills/apptest/assets/apptest.yml
skills/build/SKILL.md
skills/build/assets/build.yml
skills/build-test/SKILL.md
skills/build-test/assets/build-test.yml
agents/stack-installer.md
"

echo "Vendoring multi-platform into ${ROOT}/.claude"

rm -rf .claude/skills/init .claude/skills/apptest .claude/skills/build .claude/skills/build-test
mkdir -p .claude/skills .claude/agents

fail=0
for f in $FILES; do
  dest=".claude/${f}"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL "${BASE}/${f}" -o "$dest"; then
    printf '  %s\n' "$dest"
  else
    printf '  FAILED %s\n' "$f" >&2
    fail=1
  fi
done
chmod +x .claude/skills/init/scripts/preflight.sh 2>/dev/null || true

if [ "$fail" -ne 0 ]; then
  echo
  echo "Some files did not download. Nothing was committed; re-run when the" >&2
  echo "network settles, or check that ${REPO}@${REF} is public." >&2
  exit 1
fi

# Record what was vendored, because a copy drifts and the version is the only
# way to know how far behind it is.
VER="$(curl -fsSL "${BASE}/.claude-plugin/plugin.json" | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -1)"
cat > .claude/skills/VENDORED.md <<EOM
Vendored from https://github.com/${REPO} at version ${VER:-unknown} (ref ${REF}).

These are copies, not a plugin install: a cloud session clones this repository
and loads what is under .claude/, while a locally installed plugin never reaches
it. That is why they live here.

Because they are copies they go stale. Re-run to update:

  curl -fsSL ${BASE}/bootstrap.sh | bash

Skills vendored this way are project-scoped, so they are /init and /apptest
rather than /multi-platform:init. If you also have the plugin installed locally,
both exist and the namespaced ones are the plugin's.
EOM

echo
echo "Done. Vendored version ${VER:-unknown}."
echo "Skills: ${SKILLS}"
echo
echo "Next:"
echo "  1. /reload-plugins        (or start a new session) to pick them up"
echo "  2. git add .claude && git commit -m 'vendor multi-platform skills'"
echo "     Committing is what makes them available in future cloud sessions."
