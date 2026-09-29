# MCore Zero-Gap Manifest

Every artifact exists in **two synchronized formats**:

| Artifact | .md | .yaml |
|----------|-----|-------|
| Master Network Strategy | MASTER-NETWORK-STRATEGY.md | MASTER-NETWORK-STRATEGY.yaml |
| Failure Domains | FAILURE-DOMAINS.md | FAILURE-DOMAINS.yaml |
| IPAM | registry/ipam.md | registry/ipam.yaml |
| Networks | registry/networks.md | registry/networks.yaml |
| Providers | registry/providers.md | registry/providers.yaml |
| Services | registry/services.md | registry/services.yaml |
| Security Policy | policies/SECURITY-POLICY.md | policies/SECURITY-POLICY.yaml |
| Unknowns | UNKNOWNS.md | UNKNOWNS.yaml |

**Rule:** If either format is missing, the artifact is incomplete.
**Rule:** If formats disagree, zero-gap FAILS and a BLOCK is raised.
