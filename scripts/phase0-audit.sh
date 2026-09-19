#!/usr/bin/env bash
set -uo pipefail
BASE="/srv/mCore_dev_docs"
OUT="$BASE/docs/phase0"
EVID="$OUT/evidence"
D="$OUT/deliverables"
STAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p "$EVID" "$D" "$OUT/gates"
have(){ command -v "$1" >/dev/null 2>&1; }

DOMAINS=(
  meticulouscore.com meticulouscore.net meticulouscore.dev
  mcore360.com mcoreacademy.com mcoreai.com mcoreai.cloud mcoreai.dev
  mcorefabric.com mcoremesh.com mcoreshield.com mcorecare.com mcoreprime.com
  kotlinbrain.com shorbornoai.com shorborno.ai sorbornoai.com
  aminul-du.com 1of1.care
  rajshahionline.com rajshahionline.net rajshahionline.com.bd
  aiguru.com
)

echo "Phase 0 audit · $STAMP"

{ echo "# Environment · $STAMP"; echo; uname -a 2>/dev/null; echo;
  ip -brief addr 2>/dev/null; echo;
  (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | head -20; } \
  > "$EVID/00-environment.txt"

{ printf "domain\tstatus\texpiry\n"
  for d in "${DOMAINS[@]}"; do
    exp="" st="NOT-CHECKED"
    if have whois; then
      exp=$(whois "$d" 2>/dev/null | grep -Ei 'Registry Expiry|Expiry Date|Expiration' \
            | head -1 | awk -F: '{print $2}' | xargs 2>/dev/null)
      [ -n "$exp" ] && st="REPORTED" || st="NO-DATA"
    else st="WHOIS-MISSING"; fi
    printf "%s\t%s\t%s\n" "$d" "$st" "${exp:-unknown}"
  done; } > "$EVID/g01-g02-ownership-expiry.tsv"

{ printf "domain\tnameservers\n"
  for d in "${DOMAINS[@]}"; do
    ns=""; have dig && ns=$(dig +short NS "$d" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    printf "%s\t%s\n" "$d" "${ns:-none}"
  done; } > "$EVID/g03-nameservers.tsv"

{ printf "domain\tDS\tdnssec_ok\n"
  for d in "${DOMAINS[@]}"; do
    ds="" r="0"
    if have dig; then
      ds=$(dig +short DS "$d" 2>/dev/null | head -1)
      r=$(dig +dnssec +short "$d" 2>/dev/null | grep -c RRSIG)
    fi
    printf "%s\t%s\t%s\n" "$d" "${ds:-none}" "$r"
  done; } > "$EVID/g04-dnssec.tsv"

{ for d in "${DOMAINS[@]}"; do
    echo "### $d"
    if have dig; then
      for t in A AAAA MX TXT CAA; do
        v=$(dig +short "$t" "$d" 2>/dev/null | head -3 | tr '\n' '|')
        echo "  $t: ${v:-none}"
      done
    else echo "  dig not available"; fi
  done; } > "$EVID/g05-g06-records.txt"

{ for h in mcore360.com aminul-du.com; do
    echo "### $h"
    if have openssl; then
      timeout 6 openssl s_client -connect "$h:443" -servername "$h" </dev/null 2>/dev/null \
        | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "  no TLS"
    else echo "  openssl not available"; fi
  done; } > "$EVID/g10-tls.txt"

{ echo "# http://127.0.0.1:8787"
  if have curl; then
    curl -sI --max-time 4 "http://127.0.0.1:8787/" 2>/dev/null | head -10
    echo; curl -s --max-time 4 "http://127.0.0.1:8787/health" 2>/dev/null
  else echo "  curl not available"; fi; } > "$EVID/g15-origin-health.txt"

cat > "$OUT/gates/index.tsv" <<'TSV'
gate	label	evidence	status
G01	Domain ownership	g01-g02-ownership-expiry.tsv	RUN-REVIEW
G02	Registrar and expiry	g01-g02-ownership-expiry.tsv	RUN-REVIEW
G03	DNS delegation	g03-nameservers.tsv	RUN-REVIEW
G04	DNSSEC	g04-dnssec.tsv	RUN-REVIEW
G05	DNS record correctness	g05-g06-records.txt	RUN-REVIEW
G06	IPv4/IPv6	g05-g06-records.txt	RUN-REVIEW
G07	IPAM and overlap	(pending cloud exports)	NOT-VERIFIED
G08	Network routing	(pending cloud exports)	NOT-VERIFIED
G09	Firewall isolation	(pending local review)	NOT-VERIFIED
G10	TLS	g10-tls.txt	RUN-REVIEW
G11	Authentication	(pending)	NOT-VERIFIED
G12	Authorization	(pending)	NOT-VERIFIED
G13	Cloudflare configuration	(pending CF export)	NOT-VERIFIED
G14	Tunnel connectivity	(pending)	NOT-VERIFIED
G15	Origin health	g15-origin-health.txt	RUN-REVIEW
G16	Service persistence	(pending)	NOT-VERIFIED
G17	Observability	(pending)	NOT-VERIFIED
G18	Backup and recovery	(pending)	NOT-VERIFIED
G19	Rollback	(pending)	NOT-VERIFIED
G20	AIS acceptance	(pending sign-off)	NOT-VERIFIED
TSV

w(){ printf '# %s · %s\n\n%s\n' "$1" "$2" "$3" > "$D/$1-$2.md"; }
w 01 domain-portfolio-reconciliation "23 domains · see evidence/g01-g02-ownership-expiry.tsv"
w 02 domain-ownership-expiry-matrix "Source: evidence/g01-g02-ownership-expiry.tsv"
w 03 canonical-dns-architecture "g03-nameservers.tsv · g04-dnssec.tsv · g05-g06-records.txt"
w 04 ipam-prefix-plan "Requires cloud exports. No allocations in Phase 0."
w 05 multi-cloud-topology "Local + GCP + AWS + edge · approved links only"
w 06 identity-trust-zones "Public → Auth → App → Internal → Data → Mgmt → Evidence"
w 07 cloudflare-inventory "Awaiting read-only API export"
w 08 engine-change-sheet "127.0.0.1:8787 → CF Access+MFA → CF Tunnel · proposed"
w 09 machine-readable-registry "docs/registry/*.yaml"
w 10 provider-neutral-contracts "Adapters: CF · GCP · AWS · private · local"
w 11 security-threat-model "STRIDE · T1–T6 per master brief"
w 12 validation-negative-test-matrix "Per gate positive + negative case"
w 13 rollback-dr-plan "RTO/RPO required before Phase 2"
w 14 troubleshooting-runbook "12 scenarios · symptoms/dx/escalation/rollback/evidence"
w 15 gap-scope-risk-register "All OPEN items require AIS review"
w 16 ais-decision-approval-sheet "☐ Accept  ☐ Request evidence  ☐ Reject
Signature: ____________  Date: __________"

{ echo "# mCore 2050 — Phase 0 Summary"
  echo; echo "**Generated:** $STAMP"
  echo "**Authority:** AIS · Baseline: Golden Master v2.1.2"
  echo "**Mode:** READ-ONLY · Production verified: No"
  echo; echo "## Gate status"; echo; echo '```'
  cat "$OUT/gates/index.tsv"; echo '```'
  echo; echo "## Evidence"; ls -1 "$EVID" | sed 's/^/- /'
  echo; echo "## Deliverables"; ls -1 "$D" | sed 's/^/- /'
  echo; echo "## Constraints observed"
  echo "- No DNS / Cloudflare / firewall / IP / tunnel changes"
  echo "- No credential migration · No software install"
} > "$OUT/PHASE0-SUMMARY.md"

echo "Audit complete."
echo "  summary:     $OUT/PHASE0-SUMMARY.md"
echo "  gates:       $(wc -l < "$OUT/gates/index.tsv") lines"
echo "  evidence:    $(ls -1 "$EVID" | wc -l) files"
echo "  deliverables:$(ls -1 "$D" | wc -l) files"
