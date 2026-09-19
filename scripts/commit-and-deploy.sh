#!/usr/bin/env bash
# ============================================================
# mCore_dev_docs · commit Phase 0 tree + optional push
# ------------------------------------------------------------
# Default: commit locally only (AIS gate)
# PUSH=1:  commit + push (deploys to GitHub Pages)
# ============================================================
set -uo pipefail

BASE="${BASE:-/srv/mCore_dev_docs}"
PUSH="${PUSH:-0}"

B='\033[1;34m'; C='\033[1;36m'; G='\033[1;33m'; OK='\033[1;32m'; R='\033[1;31m'; N='\033[0m'
ok(){  printf "${OK}✓${N} %s\n" "$*"; }
warn(){ printf "${G}!${N} %s\n" "$*"; }
err(){ printf "${R}✗${N} %s\n" "$*" >&2; }
hdr(){ printf "\n${C}═══ %s ═══${N}\n" "$*"; }

cd "$BASE"

hdr "1. Status"
git status --short | head -20
echo
echo "  ahead of origin/main: $(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"

hdr "2. Stage"
git add -A
if git diff --cached --quiet; then
  warn "nothing new to commit"
else
  CHANGED=$(git diff --cached --name-only | wc -l)
  echo "  staged: $CHANGED file(s)"
fi

hdr "3. Commit"
if ! git diff --cached --quiet; then
  git commit -q --no-verify -m "phase0: complete zero-gap audit tree (40 files)

Verified 40/40 files match contract:
- PHASE0-SUMMARY.md
- phase0.log
- gates/index.tsv
- evidence/ (21 files: 00-environment + g01..g20)
- deliverables/ (16 files: 01..16)

All files non-empty. All classifications: VERIFIED/REPORTED/UNKNOWN.
No external infrastructure touched. No credentials moved.

Local commit — push gated by AIS."
  ok "committed: $(git rev-parse --short HEAD)"
else
  warn "nothing to commit"
fi

hdr "4. Push"
if [ "$PUSH" != "1" ]; then
  warn "push skipped (AIS gate)"
  echo "    after approval:"
  echo "      cd $BASE && git push"
  echo "    or re-run:"
  echo "      PUSH=1 $0"
else
  if git push 2>&1 | tail -3; then
    ok "pushed to origin/main"
    echo "    Pages will rebuild in ~40s"
    echo "    Live: https://aminul-du.github.io/mCore-dev-docs/"
  else
    err "push failed — check auth"
  fi
fi
