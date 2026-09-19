#!/usr/bin/env bash
# mCore · all-in-one deploy (idempotent)
set -uo pipefail
BASE="/srv/mCore_dev_docs"; ORG="aminul-du"; REPO="mCore-dev-docs"
MCORE_DIR="/srv/mcore"; ENGINE_SVC="mcore-local-engine"
PAGES_URL="https://$ORG.github.io/$REPO/"
UID_DU=$(id -u aminul-du)
B='\033[1;34m'; C='\033[1;36m'; OK='\033[1;32m'; N='\033[0m'
ok(){ printf "${OK}✓${N} %s\n" "$*"; }
hdr(){ printf "\n${C}═══ %s ═══${N}\n" "$*"; }
as_du(){ sudo -u aminul-du -H bash -lc "$1"; }
FAIL=0

hdr "1. Preflight"
[ -d "$BASE/.git" ] && ok "docs repo" || { echo "✗ docs repo"; FAIL=$((FAIL+1)); }

hdr "2. Push docs"
PENDING=$(as_du "cd $BASE && git rev-list --count origin/main..HEAD 2>/dev/null" || echo 0)
if [ "$PENDING" = "0" ]; then ok "in sync"; else
  as_du "cd $BASE && git push origin main 2>&1 | tail -2" && ok "pushed" || FAIL=$((FAIL+1))
fi

hdr "3. Pages"
sudo -u aminul-du -H gh api "/repos/$ORG/$REPO/pages" >/dev/null 2>&1 || \
  sudo -u aminul-du -H gh api -X POST "/repos/$ORG/$REPO/pages" \
    -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1
sudo -u aminul-du -H gh api -X POST "/repos/$ORG/$REPO/pages/builds" >/dev/null 2>&1
ok "build triggered"

hdr "4. Push mCore"
if [ -d "$MCORE_DIR/.git" ]; then
  MP=$(as_du "cd $MCORE_DIR && git rev-list --count origin/main..HEAD 2>/dev/null" || echo 0)
  [ "$MP" = "0" ] && ok "in sync" || as_du "cd $MCORE_DIR && git push origin main" && ok "pushed"
fi

hdr "5. Engine"
sudo -u aminul-du XDG_RUNTIME_DIR="/run/user/$UID_DU" systemctl --user restart "$ENGINE_SVC" 2>/dev/null && ok "restarted" || true

hdr "6. Verify"
for u in "" "phase0/PHASE0-SUMMARY.md" "phase0/gates/index.tsv" "robots.txt"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "${PAGES_URL}${u}")
  [ "$code" = "200" ] && ok "${u:-/} → $code" || echo "  ✗ ${u:-/} → $code"
done
TREE=$(find "$BASE/docs/phase0/evidence" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$TREE" -eq 21 ] && ok "evidence: 21/21" || echo "  ! evidence: $TREE/21"

echo
[ "$FAIL" -eq 0 ] && printf "${OK}✓ ALL GREEN${N}\n" || printf "${C}! $FAIL issue(s)${N}\n"
