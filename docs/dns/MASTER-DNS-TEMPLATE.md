# MCore Master DNS Template

Master template for all MCore zones.
Classification: PROPOSED until each zone verified.

## Design Principles
1. Split-horizon required for RFC1918
2. DNSSEC mandatory for public
3. IPv6 (AAAA) mandatory for public
4. CAA mandatory
5. SPF/DMARC mandatory
6. No hardcoded prod IPs
7. Failure-domain spread
8. Nameserver ownership verified

## Canonical Structure

## Zero-Gap Rules
Missing SOA/NS/DNSSEC/AAAA/CAA/SPF/DMARC → BLOCK
Private IP in public view → BLOCK
Single-FD concentration → REVIEW
