# MCore Failure Domains

| ID | Domain | CIDR | Function |
|----|--------|------|----------|
| FD-00 | Network/Fabric Control | 10.0.240.0/20 | Reserved |
| FD-01 | Kernel/Host | 10.0.0.0/20 | Host platform |
| FD-02 | Network/Tunnels | 10.0.16.0/20 | Tunnels/NAT |
| FD-03 | Rust/API | 10.0.32.0/20 | API fabric |
| FD-04 | Python/AI | 10.0.48.0/20 | AI/SMART |
| FD-05 | Frontend | 10.0.64.0/20 | UX |
| FD-06 | CI/CD | 10.0.80.0/20 | Delivery |
| FD-07 | Observability | 10.0.96.0/20 | Telemetry |
| FD-08 | Data/DB | 10.0.112.0/20 | Database |
| FD-09 | Backup/DR | 10.0.128.0/20 | Backup |
| FD-10 | Agent/MCP | 10.0.144.0/20 | Agents |
| FD-11 | Secrets/Identity | 10.0.160.0/20 | Identity |
| FD-12 | DNS/Mesh | 10.0.176.0/20 | DNS/SD |
| FD-13 | CDN/Edge | 10.0.192.0/20 | Ingress |
| FD-14 | Web Vitals/UX | 10.0.208.0/20 | RUM |
| FD-15 | Governance/Harness | 10.0.224.0/20 | Policy |

FD-00 intentionally reserved (highest /20).
