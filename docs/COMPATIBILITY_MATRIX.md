# iSHARE Satellite Compatibility Matrix

This file is the source of truth for which component image versions are known to work together.

## Versioning Policy (Framework 2.2)

- Keep framework compatibility anchored on `2.2`.
- Publish **three tags** per component image build:
  - `v2.2` (rolling series tag)
  - `v2.2.<build_number>` (monotonic release tag)
  - `v2.2.<build_number>-sha-<short_sha>` (immutable traceable tag)
- For production deployment, prefer pinning to image digest (`@sha256:...`) and record that digest in this matrix.

## Known Compatible Baselines

### Baseline: `satellite-2.2-template-baseline` (current known-compatible setup)

This baseline is derived from the currently used deployment templates and script defaults in this repository.

| Component | Image | Version Source |
|---|---|---|
| App Middleware (`PR-MW`) | `isharefoundation/ishare-satellite-app-mw:v4.18` | `templates/docker-compose-mw-template.yaml` |
| HLF Middleware (`PR-MW-HLF`) | `isharefoundation/ishare-satellite-hlf-mw:v1.9` | `templates/docker-compose-mw-template.yaml` |
| UI (`PR-UI`) | `isharefoundation/ishare-satellite-ui:v3.0.2` | `templates/docker-compose-ui.yaml`, `templates/docker-compose-ui-acme.yaml` |
| Keycloak | `isharefoundation/ishare-satellite-keycloak:v22.0.1` | `scripts/keycloak.sh` default |
| PostgreSQL | `isharefoundation/postgressql:v14-alpine` | `templates/docker-compose-mw-template.yaml`, `scripts/keycloak.sh` default |
| NGINX proxy | `nginx:1.25.1-alpine` | `templates/docker-compose-ui.yaml` |
| Fabric Peer | `isharefoundation/fabric-peer:v2.5.4` | `templates/docker-compose-hlf-template.yaml` |
| CouchDB | `isharefoundation/couchdb:v3.3.2` | `templates/docker-compose-hlf-template.yaml` |

## Recommended Release Entry Format

When releasing a coordinated set, add a new section below this line and include exact digests.

### Baseline: `satellite-2.2.x` (example)

| Component | Tag | Digest |
|---|---|---|
| PR-MW | `isharefoundation/ishare-satellite-app-mw:v2.2.<n>` | `sha256:<digest>` |
| PR-MW-HLF | `isharefoundation/ishare-satellite-hlf-mw:v2.2.<n>` | `sha256:<digest>` |
| PR-UI | `isharefoundation/ishare-satellite-ui:v2.2.<n>` | `sha256:<digest>` |

## Change Control Rules

- Do not update one of `PR-MW`, `PR-MW-HLF`, or `PR-UI` in isolation in production without adding/testing a new matrix entry.
- Any change in Fabric CLI tooling or config shape in `PR-MW-HLF` requires a new matrix entry.
- Any API contract change between UI and middleware requires a new matrix entry.
