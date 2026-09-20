# Threat Model (STRIDE)
T1 registrar hijack → lock + 2FA
T2 DNS spoof → DNSSEC
T3 tunnel hijack → rotate creds
T4 origin exposure → no public 8787
T5 credential leak → secret manager refs
T6 unauthorized API → CF Access + JWT
