#!/usr/bin/env bash
# ============================================================
# mCore_dev_docs · Phase 0 tree contract — ZERO GAP
# ------------------------------------------------------------
# Guarantees exactly this tree exists with non-empty content:
#   docs/phase0/
#   ├── PHASE0-SUMMARY.md
#   ├── phase0.log
#   ├── gates/index.tsv
#   ├── evidence/  (21 files: 00 + g01..g20)
#   └── deliverables/  (16 files)
#
# Modes:
#   ./verify-tree-zero-gap.sh          # ensure + verify
#   ./verify-tree-zero-gap.sh verify   # verify only (no writes)
# ============================================================
set -uo pipefail

MODE="${1:-ensure}"
BASE="${BASE:-/srv/mCore_dev_docs}"
OUT="$BASE/docs/phase0"
EVID="$OUT/evidence"
GATES="$OUT/gates"
DELIV="$OUT/deliverables"
LOG="$OUT/phase0.log"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

B='\033[1;34m'; C='\033[1;36m'; G='\033[1;33m'; OK='\033[1;32m'; R='\033[1;31m'; N='\033[0m'
log(){ printf "${B}▸${N} %s\n" "$*"; }
ok(){  printf "${OK}✓${N} %s\n" "$*"; }
warn(){ printf "${G}!${N} %s\n" "$*"; }
err(){ printf "${R}✗${N} %s\n" "$*" >&2; }
hdr(){ printf "\n${C}═══ %s ═══${N}\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

# ---------- Contract manifest ----------
EVID_FILES=(
  "00-environment.txt"
  "g01-domain-ownership.txt"
  "g02-registrar-expiry.tsv"
  "g03-dns-delegation.tsv"
  "g04-dnssec.tsv"
  "g05-dns-records.txt"
  "g06-ip-families.tsv"
  "g07-ipam-overlap.txt"
  "g08-network-routing.txt"
  "g09-firewall-isolation.txt"
  "g10-tls.txt"
  "g11-authentication.txt"
  "g12-authorization.md"
  "g13-cloudflare.md"
  "g14-tunnel.txt"
  "g15-origin-health.txt"
  "g16-service-persistence.md"
  "g17-observability.md"
  "g18-backup-recovery.md"
  "g19-rollback.md"
  "g20-ais-acceptance.md"
)
DELIV_FILES=(
  "01-domain-portfolio-reconciliation.md"
  "02-domain-ownership-expiry-matrix.md"
  "03-canonical-dns-architecture.md"
  "04-ipam-prefix-plan.md"
  "05-multi-cloud-topology.md"
  "06-identity-trust-zones.md"
  "07-cloudflare-inventory.md"
  "08-engine-change-sheet.md"
  "09-machine-readable-registry.md"
  "10-provider-neutral-contracts.md"
  "11-security-threat-model.md"
  "12-validation-negative-test-matrix.md"
  "13-rollback-dr-plan.md"
  "14-troubleshooting-runbook.md"
  "15-gap-scope-risk-register.md"
  "16-ais-decision-approval-sheet.md"
)

DOMAINS=(
  meticulouscore.com meticulouscore.net meticulouscore.dev
  mcore360.com mcoreacademy.com mcoreai.com mcoreai.cloud mcoreai.dev
  mcorefabric.com mcoremesh.com mcoreshield.com mcorecare.com mcoreprime.com
  kotlinbrain.com shorbornoai.com shorborno.ai sorbornoai.com
  aminul-du.com 1of1.care
  rajshahionline.com rajshahionline.net rajshahionline.com.bd
  aiguru.com
)

# ════════════════════════════════════════════════════════════
# ENSURE — write every file if missing or empty
# ════════════════════════════════════════════════════════════
ensure_tree(){
  hdr "Ensure tree · $OUT"
  mkdir -p "$EVID" "$GATES" "$DELIV"
  touch "$LOG"

  # ---- phase0.log ----
  [ -s "$LOG" ] || echo "# Phase 0 audit trail · $STAMP" > "$LOG"

  # ---- 00-environment.txt ----
  if [ ! -s "$EVID/00-environment.txt" ]; then
    {
      echo "# Environment snapshot · $STAMP"
      echo "hostname: $(hostname 2>/dev/null || echo unknown)"
      echo "user:     $(whoami)"
      echo "kernel:   $(uname -a 2>/dev/null || echo unknown)"
      echo
      echo "## Local interfaces (read-only)"
      ip -brief addr 2>/dev/null || echo "(ip unavailable)"
      echo
      echo "## Listening ports (read-only)"
      (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | head -30 || echo "(ss/netstat unavailable)"
    } > "$EVID/00-environment.txt"
  fi

  # ---- G01 domain ownership ----
  if [ ! -s "$EVID/g01-domain-ownership.txt" ]; then
    {
      echo "# G01 · Domain ownership (whois)"
      echo "# Timestamp: $STAMP"
      echo
      for d in "${DOMAINS[@]}"; do
        echo "### $d"
        if have whois; then
          whois "$d" 2>/dev/null \
            | grep -Ei 'Registrar:|Registrant|Creation Date|Registry Expiry|Name Server|Status:' \
            | head -20 || echo "  (no whois data)"
        else
          echo "  whois unavailable — UNKNOWN"
        fi
        echo
      done
    } > "$EVID/g01-domain-ownership.txt"
  fi

  # ---- G02 registrar + expiry ----
  if [ ! -s "$EVID/g02-registrar-expiry.tsv" ]; then
    {
      printf "domain\tstatus\texpiry\tsource\n"
      for d in "${DOMAINS[@]}"; do
        exp="" st="UNKNOWN"
        if have whois; then
          exp=$(whois "$d" 2>/dev/null \
            | grep -Ei 'Registry Expiry Date|Expiry Date|Expiration Date' \
            | head -1 | awk -F: '{print $2}' | xargs 2>/dev/null)
          [ -n "$exp" ] && st="REPORTED"
        fi
        printf "%s\t%s\t%s\twhois\n" "$d" "$st" "${exp:-unknown}"
      done
    } > "$EVID/g02-registrar-expiry.tsv"
  fi

  # ---- G03 DNS delegation ----
  if [ ! -s "$EVID/g03-dns-delegation.tsv" ]; then
    {
      printf "domain\tstatus\tnameservers\n"
      for d in "${DOMAINS[@]}"; do
        ns="" st="UNKNOWN"
        if have dig; then
          ns=$(dig +short NS "$d" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
          [ -n "$ns" ] && st="REPORTED"
        fi
        printf "%s\t%s\t%s\n" "$d" "$st" "${ns:-none}"
      done
    } > "$EVID/g03-dns-delegation.tsv"
  fi

  # ---- G04 DNSSEC ----
  if [ ! -s "$EVID/g04-dnssec.tsv" ]; then
    {
      printf "domain\tstatus\tds_present\tdnssec_ok\n"
      for d in "${DOMAINS[@]}"; do
        ds="" r="0" st="UNKNOWN"
        if have dig; then
          ds=$(dig +short DS "$d" 2>/dev/null | head -1)
          r=$(dig +dnssec +short "$d" 2>/dev/null | grep -c RRSIG || true)
          if [ -n "$ds" ] || [ "${r:-0}" -gt 0 ]; then
            st="REPORTED-ENABLED"; else st="NOT-DETECTED"
          fi
        fi
        printf "%s\t%s\t%s\t%s\n" "$d" "$st" "${ds:-none}" "${r:-0}"
      done
    } > "$EVID/g04-dnssec.tsv"
  fi

  # ---- G05 DNS records ----
  if [ ! -s "$EVID/g05-dns-records.txt" ]; then
    {
      echo "# G05 · DNS records (A/AAAA/CNAME/MX/TXT/CAA)"
      echo "# Timestamp: $STAMP"
      echo
      for d in "${DOMAINS[@]}"; do
        echo "### $d"
        if have dig; then
          for t in A AAAA CNAME MX TXT CAA; do
            ans=$(dig +short "$t" "$d" 2>/dev/null | head -5 | tr '\n' '|')
            echo "  $t: ${ans:-none}"
          done
        else
          echo "  dig unavailable — UNKNOWN"
        fi
        echo
      done
    } > "$EVID/g05-dns-records.txt"
  fi

  # ---- G06 IP families ----
  if [ ! -s "$EVID/g06-ip-families.tsv" ]; then
    {
      printf "domain\tipv4\tipv6\tstatus\n"
      for d in "${DOMAINS[@]}"; do
        v4="" v6="" st="UNKNOWN"
        if have dig; then
          v4=$(dig +short A "$d" 2>/dev/null | head -1)
          v6=$(dig +short AAAA "$d" 2>/dev/null | head -1)
          [ -n "$v4" ] || [ -n "$v6" ] && st="REPORTED"
        fi
        printf "%s\t%s\t%s\t%s\n" "$d" "${v4:-none}" "${v6:-none}" "$st"
      done
    } > "$EVID/g06-ip-families.tsv"
  fi

  # ---- G07 IPAM / overlap ----
  if [ ! -s "$EVID/g07-ipam-overlap.txt" ]; then
    {
      echo "# G07 · IPAM and overlap (local observation)"
      echo "# Timestamp: $STAMP"
      echo
      ip -brief addr 2>/dev/null || echo "(ip unavailable)"
      echo
      ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}' || true
      ip -o -6 addr show 2>/dev/null | awk '{print $2, $4}' || true
      echo
      echo "# Production IPAM requires cloud exports — status: UNKNOWN"
    } > "$EVID/g07-ipam-overlap.txt"
  fi

  # ---- G08 network routing ----
  if [ ! -s "$EVID/g08-network-routing.txt" ]; then
    {
      echo "# G08 · Local routing (read-only)"
      echo "# Timestamp: $STAMP"
      echo
      ip route 2>/dev/null || echo "(ip route unavailable)"
      echo
      echo "# Multi-cloud routing requires cloud exports — status: UNKNOWN"
    } > "$EVID/g08-network-routing.txt"
  fi

  # ---- G09 firewall isolation ----
  if [ ! -s "$EVID/g09-firewall-isolation.txt" ]; then
    {
      echo "# G09 · Firewall isolation (local read-only)"
      echo "# Timestamp: $STAMP"
      echo
      have ufw         && ufw status 2>/dev/null | head -20 || true
      have firewall-cmd && firewall-cmd --list-all 2>/dev/null | head -20 || true
      have iptables    && iptables -S 2>/dev/null | head -20 || true
      have nft         && nft list ruleset 2>/dev/null | head -20 || true
      echo
      echo "# Local listening ports:"
      (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | head -30 || true
      echo
      echo "# Cloud firewall requires cloud exports — status: UNKNOWN"
    } > "$EVID/g09-firewall-isolation.txt"
  fi

  # ---- G10 TLS ----
  if [ ! -s "$EVID/g10-tls.txt" ]; then
    {
      echo "# G10 · TLS probe (read-only)"
      echo "# Timestamp: $STAMP"
      echo
      for h in engine.mcore360.com mcore360.com meticulouscore.com; do
        echo "### $h"
        if have openssl; then
          timeout 8 openssl s_client -connect "$h:443" -servername "$h" </dev/null 2>/dev/null \
            | openssl x509 -noout -subject -issuer -dates 2>/dev/null \
            || echo "  no TLS response"
        else
          echo "  openssl unavailable"
        fi
        echo
      done
    } > "$EVID/g10-tls.txt"
  fi

  # ---- G11 authentication ----
  if [ ! -s "$EVID/g11-authentication.txt" ]; then
    {
      echo "# G11 · Authentication probe (headers only)"
      echo "# Timestamp: $STAMP"
      echo
      if have curl; then
        curl -sI --max-time 8 "https://engine.mcore360.com" 2>/dev/null | head -20 \
          || echo "  no response"
      else
        echo "  curl unavailable"
      fi
      echo
      echo "# Looking for: cf-access-*, cf-ray, www-authenticate"
      echo "# Status: UNKNOWN — pending Cloudflare Access review"
    } > "$EVID/g11-authentication.txt"
  fi

  # ---- G12 authorization (MD template) ----
  if [ ! -s "$EVID/g12-authorization.md" ]; then
    cat > "$EVID/g12-authorization.md" <<'MD'
# G12 · Authorization

| Policy | Scope | Enforced by | Status |
|--------|-------|-------------|--------|
| Access to `/status` | Auth required | Cloudflare Access | NOT VERIFIED |
| Access to `/backups` | Denied | Cloudflare Access | NOT VERIFIED |
| Access to `/manifest` | Auth required | Cloudflare Access | NOT VERIFIED |
| Access to `/dashboard` | Auth required | Cloudflare Access | NOT VERIFIED |

**Verification requires:** CF Access policy review + probe with/without credentials.
MD
  fi

  # ---- G13 Cloudflare ----
  if [ ! -s "$EVID/g13-cloudflare.md" ]; then
    cat > "$EVID/g13-cloudflare.md" <<'MD'
# G13 · Cloudflare configuration inventory

| Zone | Account | Proxy | DNSSEC | Access | Tunnel | Status |
|------|---------|-------|--------|--------|--------|--------|
| mcore360.com | TBD | TBD | TBD | TBD | TBD | NOT VERIFIED |
| meticulouscore.com | TBD | TBD | TBD | TBD | TBD | NOT VERIFIED |
| (all 23) | TBD | TBD | TBD | TBD | TBD | NOT VERIFIED |

**Requires:** read-only Cloudflare export. No config changes in Phase 0.
MD
  fi

  # ---- G14 tunnel ----
  if [ ! -s "$EVID/g14-tunnel.txt" ]; then
    {
      echo "# G14 · Tunnel connectivity probe"
      echo "# Timestamp: $STAMP"
      echo
      have dig && { echo "A record:"; dig +short A engine.mcore360.com 2>/dev/null; }
      echo
      have curl && {
        echo "HEAD response:"
        curl -sI --max-time 8 "https://engine.mcore360.com" 2>/dev/null | head -15 \
          || echo "  no response"
      }
      echo
      echo "# Status: NOT VERIFIED — requires Cloudflare tunnel status export."
    } > "$EVID/g14-tunnel.txt"
  fi

  # ---- G15 origin health ----
  if [ ! -s "$EVID/g15-origin-health.txt" ]; then
    {
      echo "# G15 · Origin health (local probe)"
      echo "# Timestamp: $STAMP"
      echo
      have curl && {
        echo "HEAD http://127.0.0.1:8787/"
        curl -sI --max-time 5 "http://127.0.0.1:8787/" 2>/dev/null | head -10 \
          || echo "  no response"
      }
      echo
      echo "Listening check:"
      (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | grep -E ':8787\b' \
        || echo "  port 8787 not listening"
    } > "$EVID/g15-origin-health.txt"
  fi

  # ---- G16 service persistence ----
  if [ ! -s "$EVID/g16-service-persistence.md" ]; then
    cat > "$EVID/g16-service-persistence.md" <<'MD'
# G16 · Service persistence

| Question | Answer | Status |
|----------|--------|--------|
| Auto-start on boot? | TBD | NOT VERIFIED |
| systemd/supervisor unit? | TBD | NOT VERIFIED |
| WSL user service auto-start? | TBD | NOT VERIFIED |
| Health check registered? | TBD | NOT VERIFIED |
| Restart policy defined? | TBD | NOT VERIFIED |

**Do NOT modify service config in Phase 0.**
MD
  fi

  # ---- G17 observability ----
  if [ ! -s "$EVID/g17-observability.md" ]; then
    cat > "$EVID/g17-observability.md" <<'MD'
# G17 · Observability

| Signal | Source | Retention | Status |
|--------|--------|-----------|--------|
| DNS health | TBD | TBD | NOT VERIFIED |
| TLS health | TBD | TBD | NOT VERIFIED |
| Tunnel status | Cloudflare | TBD | NOT VERIFIED |
| Service health | doGet | TBD | NOT VERIFIED |
| Network reachability | TBD | TBD | NOT VERIFIED |
| Error rates | TBD | TBD | NOT VERIFIED |
| Firewall denials | TBD | TBD | NOT VERIFIED |
| Route drift | TBD | TBD | NOT VERIFIED |
| Deployment events | Git | ∞ | AVAILABLE |

**Do not expose internal topology via public status endpoints.**
MD
  fi

  # ---- G18 backup / recovery ----
  if [ ! -s "$EVID/g18-backup-recovery.md" ]; then
    cat > "$EVID/g18-backup-recovery.md" <<'MD'
# G18 · Backup and recovery

| Asset | Method | Frequency | Off-site | Restore tested | Status |
|-------|--------|-----------|----------|----------------|--------|
| Git repos | GitHub | continuous | yes | N/A | AVAILABLE |
| DNS zone files | TBD | TBD | TBD | TBD | NOT VERIFIED |
| Cloudflare config | TBD | TBD | TBD | TBD | NOT VERIFIED |
| Engine config | TBD | TBD | TBD | TBD | NOT VERIFIED |
| Credentials | password manager | TBD | TBD | TBD | NOT VERIFIED |

**RTO/RPO must be defined before Phase 2.**
MD
  fi

  # ---- G19 rollback ----
  if [ ! -s "$EVID/g19-rollback.md" ]; then
    cat > "$EVID/g19-rollback.md" <<'MD'
# G19 · Rollback plan

| Change type | Rollback | Tested | Status |
|-------------|----------|--------|--------|
| Git push | `git revert` | N/A | AVAILABLE |
| DNS record | revert in registrar | No | NOT VERIFIED |
| CF Access policy | revert via CF | No | NOT VERIFIED |
| Tunnel config | recreate | No | NOT VERIFIED |
| Engine service | restart from backup | No | NOT VERIFIED |

**Every Phase 2+ change needs a tested rollback.**
MD
  fi

  # ---- G20 AIS acceptance ----
  if [ ! -s "$EVID/g20-ais-acceptance.md" ]; then
    cat > "$EVID/g20-ais-acceptance.md" <<'MD'
# G20 · AIS acceptance sheet

| # | Deliverable | Produced | Reviewed | Accepted |
|---|-------------|----------|----------|----------|
| 01 | Domain portfolio reconciliation | ☐ | ☐ | ☐ |
| 02 | Ownership & expiry matrix | ☐ | ☐ | ☐ |
| 03 | Canonical DNS architecture | ☐ | ☐ | ☐ |
| 04 | IPAM prefix plan | ☐ | ☐ | ☐ |
| 05 | Multi-cloud topology | ☐ | ☐ | ☐ |
| 06 | Identity & trust zones | ☐ | ☐ | ☐ |
| 07 | Cloudflare inventory | ☐ | ☐ | ☐ |
| 08 | Engine change sheet | ☐ | ☐ | ☐ |
| 09 | Machine-readable registry | ☐ | ☐ | ☐ |
| 10 | Provider-neutral contracts | ☐ | ☐ | ☐ |
| 11 | Security threat model | ☐ | ☐ | ☐ |
| 12 | Validation & negative tests | ☐ | ☐ | ☐ |
| 13 | Rollback & DR plan | ☐ | ☐ | ☐ |
| 14 | Troubleshooting runbook | ☐ | ☐ | ☐ |
| 15 | Gap / scope / risk register | ☐ | ☐ | ☐ |
| 16 | AIS decision sheet | ☐ | ☐ | ☐ |

**Signature:** ________________  **Date:** __________
MD
  fi

  # ---- gates/index.tsv ----
  if [ ! -s "$GATES/index.tsv" ]; then
    cat > "$GATES/index.tsv" <<'TSV'
gate	label	evidence	status
G01	Domain ownership	g01-domain-ownership.txt	RUN-REVIEW
G02	Registrar and expiry	g02-registrar-expiry.tsv	RUN-REVIEW
G03	DNS delegation	g03-dns-delegation.tsv	RUN-REVIEW
G04	DNSSEC	g04-dnssec.tsv	RUN-REVIEW
G05	DNS record correctness	g05-dns-records.txt	RUN-REVIEW
G06	IPv4/IPv6	g06-ip-families.tsv	RUN-REVIEW
G07	IPAM and overlap	g07-ipam-overlap.txt	RUN-REVIEW
G08	Network routing	g08-network-routing.txt	RUN-REVIEW
G09	Firewall isolation	g09-firewall-isolation.txt	RUN-REVIEW
G10	TLS	g10-tls.txt	RUN-REVIEW
G11	Authentication	g11-authentication.txt	RUN-REVIEW
G12	Authorization	g12-authorization.md	RUN-REVIEW
G13	Cloudflare configuration	g13-cloudflare.md	RUN-REVIEW
G14	Tunnel connectivity	g14-tunnel.txt	RUN-REVIEW
G15	Origin health	g15-origin-health.txt	RUN-REVIEW
G16	Service persistence	g16-service-persistence.md	RUN-REVIEW
G17	Observability	g17-observability.md	RUN-REVIEW
G18	Backup and recovery	g18-backup-recovery.md	RUN-REVIEW
G19	Rollback	g19-rollback.md	RUN-REVIEW
G20	AIS acceptance	g20-ais-acceptance.md	RUN-REVIEW
TSV
  fi

  # ---- 16 deliverables ----
  write_deliv(){ # $1=file  $2=title  $3=body
    local f="$DELIV/$1"
    [ -s "$f" ] && return 0
    printf '# %s\n\n%s\n' "$2" "$3" > "$f"
  }

  write_deliv "01-domain-portfolio-reconciliation.md" \
    "01 · Domain Portfolio Reconciliation" \
    "23 domains · reconciliation matrix. Evidence: evidence/g01-domain-ownership.txt"

  write_deliv "02-domain-ownership-expiry-matrix.md" \
    "02 · Domain Ownership & Expiry Matrix" \
    "Source: evidence/g02-registrar-expiry.tsv — all values REPORTED until verified."

  write_deliv "03-canonical-dns-architecture.md" \
    "03 · Canonical DNS Architecture" \
    "Sources: g03-dns-delegation.tsv · g04-dnssec.tsv · g05-dns-records.txt · g06-ip-families.tsv"

  write_deliv "04-ipam-prefix-plan.md" \
    "04 · IPAM & Prefix Allocation Plan" \
    "Requires cloud exports (GCP/AWS). No allocations in Phase 0."

  write_deliv "05-multi-cloud-topology.md" \
    "05 · Multi-Cloud Network Topology" \
    "Local + GCP + AWS + edge. Approved links only. No full-mesh by default."

  write_deliv "06-identity-trust-zones.md" \
    "06 · Identity & Trust Zones" \
    "Public Edge → Auth Access → Application → Internal → Data → Management → Evidence"

  write_deliv "07-cloudflare-inventory.md" \
    "07 · Cloudflare Inventory" \
    "Awaiting read-only Cloudflare export. Constraint: no config changes in Phase 0."

  write_deliv "08-engine-change-sheet.md" \
    "08 · engine.mcore360.com Change Sheet" \
    "PROPOSED: 127.0.0.1:8787 → CF Access + MFA → CF Tunnel. Requires AIS approval."

  write_deliv "09-machine-readable-registry.md" \
    "09 · Machine-Readable Registry" \
    "docs/registry/*.yaml — extend existing Golden Master, do not fork."

  write_deliv "10-provider-neutral-contracts.md" \
    "10 · Provider-Neutral Deployment Contracts" \
    "Adapters: Cloudflare · GCP · AWS · private · local. No adapter owns intent."

  write_deliv "11-security-threat-model.md" \
    "11 · Security Threat Model" \
    "STRIDE analysis. T1–T6 in master brief §11. Never store credentials in registry/Git."

  write_deliv "12-validation-negative-test-matrix.md" \
    "12 · Validation & Negative-Test Matrix" \
    "Per gate: positive + negative cases. A proposed config is not a passed test."

  write_deliv "13-rollback-dr-plan.md" \
    "13 · Rollback & Disaster Recovery Plan" \
    "Per-change rollback + RTO/RPO. Both required before Phase 2."

  write_deliv "14-troubleshooting-runbook.md" \
    "14 · Troubleshooting Runbook" \
    "12 scenarios. Each: symptoms · diagnostics · expected · escalation · rollback · evidence."

  write_deliv "15-gap-scope-risk-register.md" \
    "15 · Gap / Scope / Risk Register" \
    "All OPEN items require AIS review. Gap closes with evidence. Risk closes with verified mitigation."

  write_deliv "16-ais-decision-approval-sheet.md" \
    "16 · AIS Decision & Approval Sheet" \
    "☐ Accept Phase 0   ☐ Request additional evidence   ☐ Reject

Signature: ____________   Date: __________

☐ I confirm no infrastructure changes were executed during Phase 0."

  # ---- PHASE0-SUMMARY.md ----
  if [ ! -s "$OUT/PHASE0-SUMMARY.md" ]; then
    {
      echo "# MCore 2050 — Phase 0 Summary"
      echo
      echo "**Generated:** $STAMP"
      echo "**Authority:** AIS · **Baseline:** Golden Master v2.1.2"
      echo "**Mode:** READ-ONLY · **Production verified:** No"
      echo
      echo "## Gates"
      echo '```'
      cat "$GATES/index.tsv"
      echo '```'
      echo
      echo "## Evidence"
      ls -1 "$EVID" 2>/dev/null | sed 's/^/- /'
      echo
      echo "## Deliverables"
      ls -1 "$DELIV" 2>/dev/null | sed 's/^/- /'
      echo
      echo "## Constraints observed"
      echo "- No DNS / Cloudflare / firewall change"
      echo "- No IP allocation"
      echo "- No tunnel creation"
      echo "- No credential migration"
      echo "- No software install"
      echo
      echo "> STOP after Phase 0. Return to AIS for Phase 1 approval."
    } > "$OUT/PHASE0-SUMMARY.md"
  fi
}

# ════════════════════════════════════════════════════════════
# VERIFY — assert every contract file exists and is non-empty
# ════════════════════════════════════════════════════════════
verify_tree(){
  hdr "Verify tree · $OUT"
  local fail=0 total=0

  check(){
    total=$((total+1))
    if [ -s "$1" ]; then
      local sz; sz=$(stat -c '%s' "$1" 2>/dev/null || echo 0)
      printf "  ${OK}✓${N} %-48s %6s bytes\n" "$(basename "$1")" "$sz"
    else
      printf "  ${R}✗${N} %-48s MISSING or EMPTY\n" "$(basename "$1")"
      fail=$((fail+1))
    fi
  }

  # top level
  check "$OUT/PHASE0-SUMMARY.md"
  check "$OUT/phase0.log"
  check "$GATES/index.tsv"

  # evidence (21 files)
  for f in "${EVID_FILES[@]}"; do check "$EVID/$f"; done

  # deliverables (16 files)
  for f in "${DELIV_FILES[@]}"; do check "$DELIV/$f"; done

  echo
  echo "  ─────────────────────────────────────────────"
  echo "  Total:  $total"
  echo "  Passed: $((total - fail))"
  echo "  Failed: $fail"
  echo "  ─────────────────────────────────────────────"

  if [ "$fail" -eq 0 ]; then
    ok "ZERO GAP — tree matches contract exactly"
    return 0
  else
    err "$fail file(s) missing or empty"
    return 1
  fi
}

# ════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════
case "$MODE" in
  ensure)
    ensure_tree
    echo
    verify_tree
    ;;
  verify)
    verify_tree
    ;;
  *)
    err "Usage: $0 [ensure|verify]"
    exit 1
    ;;
esac

echo
printf "${C}═══════════════════════════════════════════════════${N}\n"
echo "  Tree: $OUT"
echo "  Log:  $LOG"
printf "${C}═══════════════════════════════════════════════════${N}\n"
