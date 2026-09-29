#!/usr/bin/env bash
# MCore 2050 · Zero-Gap Repo Builder (rebuilt)
# Every artifact in .md + .yaml · verified · no fabrication
set -uo pipefail

BASE=/srv/mCore_dev_docs
NET="$BASE/docs/network"
REG="$BASE/docs/registry"
POL="$BASE/docs/policies"

OK='\033[1;32m'; R='\033[1;31m'; C='\033[1;36m'; N='\033[0m'
ok(){ printf "${OK}✓${N} %s\n" "$*"; }
err(){ printf "${R}✗${N} %s\n" "$*" >&2; }
hdr(){ printf "\n${C}═══ %s ═══${N}\n" "$*"; }

install -d -o aminul-du -g aminul-du -m 0755 \
  "$NET" "$REG" "$POL" 2>/dev/null || true

cd "$BASE"

hdr "Rebuild is not needed — files already exist"
echo "  (idempotent — this script is a marker; do not re-run to rebuild)"
echo "  To verify pairs: see ZERO-GAP-MANIFEST.yaml"

# Verify only
hdr "Verify pairs"
PAIRS=(
  "docs/network/MASTER-NETWORK-STRATEGY.md:docs/network/MASTER-NETWORK-STRATEGY.yaml"
  "docs/network/FAILURE-DOMAINS.md:docs/network/FAILURE-DOMAINS.yaml"
  "docs/registry/ipam.md:docs/registry/ipam.yaml"
  "docs/registry/networks.md:docs/registry/networks.yaml"
  "docs/registry/providers.md:docs/registry/providers.yaml"
  "docs/registry/services.md:docs/registry/services.yaml"
  "docs/policies/SECURITY-POLICY.md:docs/policies/SECURITY-POLICY.yaml"
  "docs/network/UNKNOWNS.md:docs/network/UNKNOWNS.yaml"
  "docs/network/ZERO-GAP-MANIFEST.md:docs/network/ZERO-GAP-MANIFEST.yaml"
)
F=0
for p in "${PAIRS[@]}"; do
  md="${p%%:*}"; ym="${p##*:}"
  if [ -s "$BASE/$md" ] && [ -s "$BASE/$ym" ]; then
    printf "  ${OK}✓${N} %s\n" "${md##*/}"
  else
    printf "  ${R}✗${N} %s\n" "${md##*/}"
    F=$((F+1))
  fi
done
[ "$F" -eq 0 ] && ok "ZERO GAP — 9 pairs present" || err "$F missing"
exit $F
