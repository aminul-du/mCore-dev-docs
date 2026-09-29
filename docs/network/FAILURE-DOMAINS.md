# MCore Failure Domains

| ID | Domain | CIDR | Function |
|----|--------|------|----------|
| FD-00 | Network/Fabric Control | 10.0.240.0/20 | Routing/fabric (RESERVED) |
| FD-01 | Kernel/Host | 10.0.0.0/20 | Host platform |
| FD-02 | Network/Tunnels | 10.0.16.0/20 | Tunnels/NAT |
| FD-03 | Rust/API | 10.0.32.0/20 | API fabric |
| FD-04 | Python/AI | 10.0.48.0/20 | AI/SMART |
| FD-05 | Frontend | 10.0.64.0/20 | UX/application |
| FD-06 | CI/CD | 10.0.80.0/20 | Delivery |
| FD-07 | Observability | 10.0.96.0/20 | Telemetry |
| FD-08 | Data/DB | 10.0.112.0/20 | Database |
| FD-09 | Backup/DR | 10.0.128.0/20 | Backup |
| FD-10 | Agent/MCP | 10.0.144.0/20 | Agents/tools |
| FD-11 | Secrets/Identity | 10.0.160.0/20 | Identity/secrets |
| FD-12 | DNS/Mesh | 10.0.176.0/20 | DNS/discovery |
| FD-13 | CDN/Edge | 10.0.192.0/20 | Ingress/edge |
| FD-14 | Web Vitals/UX | 10.0.208.0/20 | RUM/UX |
| FD-15 | Governance/Harness | 10.0.224.0/20 | Policy/evidence |

Full failure/detection/recovery matrix: see FAILURE-DOMAINS.yaml.

**FD-00 note:** `10.0.240.0/20` is intentionally reserved (highest /20) for
Edge fabric control. Not a typo. Not a placement error.
