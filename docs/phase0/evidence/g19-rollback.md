# G19 · Rollback plan

| Change type | Rollback | Tested | Status |
|-------------|----------|--------|--------|
| Git push | `git revert` | N/A | AVAILABLE |
| DNS record | revert in registrar | No | NOT VERIFIED |
| CF Access policy | revert via CF | No | NOT VERIFIED |
| Tunnel config | recreate | No | NOT VERIFIED |
| Engine service | restart from backup | No | NOT VERIFIED |

**Every Phase 2+ change needs a tested rollback.**
