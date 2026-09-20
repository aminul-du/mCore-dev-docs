#!/usr/bin/env bash
# MCore 2050 — Master Deployment Orchestrator
set -uo pipefail

ROOT="${MCORE_ROOT:-/srv/mCore_dev_docs}"
PHASE1="$ROOT/docs/phase1"
PLANS="$PHASE1/plans"
EVID="$PHASE1/evidence"
REG="$ROOT/docs/registry"
STATE="$ROOT/.mcore-state"
LOGDIR="$ROOT/logs"
APPROVALS="$ROOT/approvals"

mkdir -p "$PHASE1" "$PLANS" "$EVID" "$REG" "$STATE" "$LOGDIR" "$APPROVALS"
chmod 700 "$APPROVALS" 2>/dev/null || true

B='\033[1;34m'; C='\033[1;36m'; OK='\033[1;32m'; G='\033[1;33m'; R='\033[1;31m'; N='\033[0m'
log(){ printf "${B}▸${N} %s\n" "$*"; }
ok(){  printf "${OK}✓${N} %s\n" "$*"; }
warn(){ printf "${G}!${N} %s\n" "$*"; }
err(){ printf "${R}✗${N} %s\n" "$*" >&2; }
hdr(){ printf "\n${C}═══ %s ═══${N}\n" "$*"; }
die(){ err "$*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

preflight(){
  hdr "Preflight"
  local missing=()
  for t in git bash curl python3 jq; do have "$t" || missing+=("$t"); done
  have dig     || warn "dig missing"
  have whois   || warn "whois missing"
  have openssl || warn "openssl missing"
  have gh      || warn "gh missing"
  if [ ${#missing[@]} -gt 0 ]; then
    err "missing required: ${missing[*]}"
    return 1
  fi
  ok "required tools present"
  [ -d "$REG" ]   || die "registry dir missing: $REG"
  [ -w "$STATE" ] || die "state not writable: $STATE"
  ok "registry + state ok"
  return 0
}

cmd_audit(){
  hdr "Audit (read-only)"
  preflight || return 1
  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ)
  local out="$EVID/audit-$ts.json"

  python3 - "$out" <<'PY'
import json, sys, shutil, socket, platform
tools = {}
for t in ["git","bash","curl","python3","jq","dig","whois","openssl","gh"]:
    tools[t] = shutil.which(t) is not None
d = {
    "timestamp": sys.argv[1],
    "host": socket.gethostname(),
    "kernel": platform.release(),
    "tools": tools,
}
json.dump(d, open(sys.argv[1] if sys.argv[1].endswith(".json") else sys.argv[1], "w"), indent=2)
print("  wrote", sys.argv[1])
PY
  ok "audit: $out"

  # DNS audit
  local dnsout="$EVID/dns-audit-$ts.tsv"
  printf "domain\tns\ta\tdnssec\n" > "$dnsout"
  if [ -f "$REG/domains.yaml" ]; then
    while IFS= read -r domain; do
      [ -z "$domain" ] && continue
      ns=$(have dig && dig +short NS "$domain" 2>/dev/null | head -1 || echo -)
      a=$(have dig && dig +short A "$domain" 2>/dev/null | head -1 || echo -)
      ds=$(have dig && dig +short DS "$domain" 2>/dev/null | head -1 || echo -)
      printf "%s\t%s\t%s\t%s\n" "$domain" "${ns:--}" "${a:--}" "${ds:--}" >> "$dnsout"
    done < <(grep -oE 'domain: [a-z0-9.-]+' "$REG/domains.yaml" 2>/dev/null | awk '{print $2}')
  fi
  ok "dns audit: $dnsout"
  echo "$ts" > "$STATE/last-audit"
  return 0
}

cmd_plan(){
  hdr "Plan"
  preflight || return 1
  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ)
  local pid="PLAN-$ts"
  local plan="$PLANS/$pid.json"
  local nd=0
  [ -f "$REG/domains.yaml" ] && nd=$(grep -c 'domain:' "$REG/domains.yaml" 2>/dev/null || echo 0)

  cat > "$plan" <<JSON
{
  "plan_id": "$pid",
  "created": "$ts",
  "authority": "AIS",
  "baseline": "Golden Master v2.1.2",
  "requires_approval": true,
  "domains_count": $nd,
  "phases": [
    {"phase":1,"name":"Canonical architecture","mode":"design-only","destructive":false,"requires_credentials":[],"rollback":"git revert"},
    {"phase":2,"name":"Secure vertical slice","mode":"implement","destructive":false,"requires_credentials":["cloudflare_api_token","cf_account_id","cf_zone_mcore360"],"rollback":"delete_tunnel+revert_dns+revert_access"},
    {"phase":3,"name":"Product onboarding","mode":"implement","destructive":false,"requires_credentials":["per_product"],"rollback":"per_product"},
    {"phase":4,"name":"Multi-cloud connectivity","mode":"implement","destructive":false,"requires_credentials":["gcp_service_account","aws_iam_role"],"rollback":"delete_links"},
    {"phase":5,"name":"Intelligent operations","mode":"incremental","destructive":false,"requires_credentials":[],"rollback":"disable_features"}
  ],
  "constraints": {
    "no_automatic_git_push": true,
    "no_destructive_defaults": true,
    "srv_mcore_out_of_scope": true,
    "preserve_fastapi_doget_engine": true,
    "no_public_port_8787": true
  }
}
JSON
  echo "$pid" > "$STATE/last-plan"
  ok "plan written: $plan"
  echo "  plan_id = $pid"
  return 0
}

cmd_validate(){
  hdr "Validate"
  preflight || return 1
  local pid="${PLAN_ID:-$(cat "$STATE/last-plan" 2>/dev/null || echo "")}"
  [ -n "$pid" ] || die "no plan — run: $0 plan"
  [ -f "$PLANS/$pid.json" ] || die "plan missing: $PLANS/$pid.json"
  ok "plan: $pid"
  for f in domains dns ipam networks providers services; do
    if [ -f "$REG/$f.yaml" ]; then ok "registry: $f.yaml"
    else warn "registry missing: $f.yaml"; fi
  done
  if [ -f "$APPROVALS/$pid.approved" ]; then
    ok "approval present: $pid"
  else
    warn "approval MISSING: $pid — deploy will fail closed"
  fi
  return 0
}

cmd_deploy(){
  local ap=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --approved-plan) ap="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [ -n "$ap" ] || die "usage: $0 deploy --approved-plan PLAN_ID"
  hdr "Deploy — $ap"
  preflight || die "preflight failed"
  [ -f "$PLANS/$ap.json" ] || die "plan missing"
  [ -f "$APPROVALS/$ap.approved" ] || die "APPROVAL MISSING — refusing to execute"
  local scope; scope=$(grep -E '^SCOPE=' "$APPROVALS/$ap.approved" | cut -d= -f2-)
  [ -n "$scope" ] || die "SCOPE missing in approval"
  ok "scope: $scope"

  local phases
  case "$scope" in
    phase1_only)     phases="1" ;;
    phases_1_2)      phases="1 2" ;;
    phases_1_2_3)    phases="1 2 3" ;;
    phases_1_2_3_4)  phases="1 2 3 4" ;;
    all_approved)    phases="1 2 3 4 5" ;;
    *) die "unknown scope: $scope" ;;
  esac
  echo "  phases: $phases"

  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ)
  local did="DEP-$ts"
  echo "$did" > "$STATE/last-deploy"

  for ph in $phases; do
    hdr "Phase $ph"
    case "$ph" in
      1) phase1_apply || return 1 ;;
      2) phase2_apply || return 1 ;;
      3) phase3_apply || return 1 ;;
      4) phase4_apply || return 1 ;;
      5) phase5_apply || return 1 ;;
    esac
  done
  ok "deployment $did complete"
  return 0
}

phase1_apply(){
  log "phase 1: design-only artifacts"
  mkdir -p "$PHASE1/policies" "$PHASE1/testing"
  [ -f "$PHASE1/policies/trust-zones.md" ] || cat > "$PHASE1/policies/trust-zones.md" <<'MD'
# Trust Zones
Public → Auth → App → Internal → Data → Management → Evidence
MD
  [ -f "$PHASE1/policies/threat-model.md" ] || cat > "$PHASE1/policies/threat-model.md" <<'MD'
# Threat Model (STRIDE)
T1 registrar hijack → lock + 2FA
T2 DNS spoof → DNSSEC
T3 tunnel hijack → rotate creds
T4 origin exposure → no public 8787
T5 credential leak → secret manager refs
T6 unauthorized API → CF Access + JWT
MD
  [ -f "$PHASE1/testing/negative-matrix.md" ] || cat > "$PHASE1/testing/negative-matrix.md" <<'MD'
# Negative Test Matrix
/status unauthenticated → 401
/backups unauthenticated → 403
/manifest unauthenticated → 401
/dashboard unauthenticated → 401
:8787 from internet → refused
MD
  ok "phase 1 written"
  return 0
}

phase2_apply(){
  : "${CLOUDFLARE_API_TOKEN:?CF token required}"
  err "phase 2 requires AIS-scoped Cloudflare API calls — not auto-executed"
  return 1
}
phase3_apply(){ err "phase 3 requires per-product AIS approval"; return 1; }
phase4_apply(){ err "phase 4 requires GCP/AWS creds + justified links"; return 1; }
phase5_apply(){ err "phase 5 incremental — separate track"; return 1; }

cmd_verify(){
  hdr "Verify"
  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ)
  local out="$EVID/verify-$ts.txt"
  {
    echo "# Verify $ts"
    echo
    echo "## Public (positive)"
    for u in \
      "https://aminul-du.github.io/mCore-dev-docs/" \
      "https://aminul-du.github.io/mCore-dev-docs/phase0/PHASE0-SUMMARY.md"; do
      c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$u" || echo 000)
      echo "  $u → $c"
    done
    echo
    echo "## Local engine"
    c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8787/health" || echo 000)
    echo "  /health → $c"
    echo
    echo "## productionVerified: false"
  } > "$out"
  ok "verify: $out"
  cat "$out"
  return 0
}

cmd_status(){
  hdr "Status"
  echo "  root:        $ROOT"
  echo "  last audit:  $(cat "$STATE/last-audit"  2>/dev/null || echo —)"
  echo "  last plan:   $(cat "$STATE/last-plan"   2>/dev/null || echo —)"
  echo "  last deploy: $(cat "$STATE/last-deploy" 2>/dev/null || echo —)"
  echo
  echo "  plans:";     ls -1 "$PLANS"     2>/dev/null | sed 's/^/    /' || echo "    (none)"
  echo "  approvals:"; ls -1 "$APPROVALS" 2>/dev/null | sed 's/^/    /' || echo "    (none)"
  echo
  echo "  productionVerified: false"
  return 0
}

cmd_rollback(){
  local did=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --deployment) did="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [ -n "$did" ] || die "usage: $0 rollback --deployment DEPLOYMENT_ID"
  hdr "Rollback — $did"
  warn "phases 2–5 not executed; nothing to roll back"
  warn "phase 1 rollback = git revert"
  return 1
}

case "${1:-}" in
  audit)     cmd_audit ;;
  plan)      cmd_plan ;;
  validate)  cmd_validate ;;
  deploy)    shift; cmd_deploy "$@" ;;
  verify)    cmd_verify ;;
  status)    cmd_status ;;
  rollback)  shift; cmd_rollback "$@" ;;
  ""|-h|--help)
    cat <<USAGE
MCore 2050 — Master Deployment Orchestrator

  $0 audit
  $0 plan
  $0 validate
  $0 deploy --approved-plan PLAN_ID
  $0 verify
  $0 status
  $0 rollback --deployment DEPLOYMENT_ID
USAGE
    ;;
  *) die "unknown command: $1 (try --help)" ;;
esac
