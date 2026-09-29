#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ZONES="$DIR/zones"
OK='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; C='\033[1;36m'; N='\033[0m'
[ -d "$ZONES" ] || { echo "no zones dir"; exit 1; }
found=0
for zone in "$ZONES"/*.zone; do
  [ -f "$zone" ] || continue
  found=1
  printf "\n${C}=== %s ===${N}\n" "$(basename "$zone")"
  okc=0; failc=0
  check(){ if grep -qE "$2" "$zone"; then printf "  ${OK}✓${N} %s\n" "$1"; okc=$((okc+1)); else printf "  ${R}✗${N} %s\n" "$1"; failc=$((failc+1)); fi; }
  warn_if(){ grep -qE "$2" "$zone" && printf "  ${Y}!${N} %s\n" "$1"; }
  check "SOA" 'IN\s+SOA'
  check "NS (>=2)" 'IN\s+NS'
  check "CAA" 'IN\s+CAA'
  check "SPF" 'v=spf1'
  check "DMARC" 'v=DMARC1'
  warn_if "RFC1918 present" '10\.[0-9]+\.[0-9]+\.[0-9]+'
  warn_if "Single-FD concentration" '10\.0\.48\.'
  printf "  ---\n  ok=%d fail=%d\n" "$okc" "$failc"
done
[ "$found" -eq 0 ] && echo "no .zone files found"
exit 0
