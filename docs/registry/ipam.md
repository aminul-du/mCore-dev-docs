# MCore IPAM Plan

**Address space:** 10.0.0.0/16 · **Subdivision:** /20 · **Count:** 16

| CIDR | FD | Purpose |
|------|----|---------|
| 10.0.0.0/20 | FD-01 | Kernel/Host |
| 10.0.16.0/20 | FD-02 | Network/Tunnels |
| 10.0.32.0/20 | FD-03 | Rust/API |
| 10.0.48.0/20 | FD-04 | Python/AI |
| 10.0.64.0/20 | FD-05 | Frontend |
| 10.0.80.0/20 | FD-06 | CI/CD |
| 10.0.96.0/20 | FD-07 | Observability |
| 10.0.112.0/20 | FD-08 | Data/DB |
| 10.0.128.0/20 | FD-09 | Backup/DR |
| 10.0.144.0/20 | FD-10 | Agent/MCP |
| 10.0.160.0/20 | FD-11 | Secrets/Identity |
| 10.0.176.0/20 | FD-12 | DNS/Mesh |
| 10.0.192.0/20 | FD-13 | CDN/Edge |
| 10.0.208.0/20 | FD-14 | Web Vitals/UX |
| 10.0.224.0/20 | FD-15 | Governance/Harness |
| 10.0.240.0/20 | FD-00 | Fabric Control (RESERVED) |

**Rules:** No allocations outside this plan without exception record.
Control Plane CIDR is OUT OF SCOPE (separate cloud infrastructure).
