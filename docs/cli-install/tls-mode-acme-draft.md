# TLS Mode Draft: Manual vs ACME Automation

This draft describes how to add optional automated TLS provisioning and renewal to `scripts/install-server.sh` while preserving the current manual certificate flow.

## Goals

- Keep current deployments working unchanged (`manual` mode).
- Add an opt-in `acme` mode that:
  - issues certs automatically,
  - renews certs automatically,
  - serves `UIHostName`, `MiddlewareHostName`, and `KeycloakHostName` over HTTPS,
  - keeps existing app deployment scripts mostly intact.
- Fail early with actionable messages when ACME prerequisites are not met.

## Non-Goals

- Replacing business app containers (`ishare_ui`, `middleware-ishare_mw-1`, `keycloak`).
- Requiring wildcard certs in ACME mode.
- Changing HLF/JWT signing material behavior.

## High-Level Approach

Introduce a `TLS_MODE` selector:

- `TLS_MODE=manual` (default):
  - requires `ssl/tls.crt` + `ssl/tls.key` (current behavior).
- `TLS_MODE=acme`:
  - uses an edge reverse proxy stack to obtain/renew certs.
  - no manual `ssl/tls.crt`/`ssl/tls.key` gate.

Implementation note:
- Keep the current UI nginx routing behavior for same-origin `/api` and host-based routing.
- For ACME, deploy a dedicated edge stack with HTTP-01 challenge handling and cert storage volume.

## Proposed Env Additions

Add to `.env.server.example` and installer prompts:

- `TLS_MODE=manual`
- `ACME_EMAIL=`
- `ACME_STAGING=false`
- `ACME_CA_SERVER=` (optional override; defaults by staging/prod)
- `ACME_STORAGE_PATH=` (default: `.local-state/acme/acme.json`)

Optional knobs:

- `ACME_HTTP_PORT=80`
- `ACME_HTTPS_PORT=443`

Validation rules:

- `TLS_MODE` must be `manual` or `acme`.
- If `TLS_MODE=acme`, `ACME_EMAIL` is required.
- If `TLS_MODE=manual`, `ssl/tls.crt` and `ssl/tls.key` required (existing gate).

## Stage Behavior Changes

### preflight

Add checks:

- `TLS_MODE=acme`:
  - verify host DNS for `UIHostName`, `MiddlewareHostName`, `KeycloakHostName` resolves to server public IP,
  - verify ports `80` and `443` are free or intentionally managed by docker,
  - verify no conflicting reverse proxy is bound to those ports.

- `TLS_MODE=manual`:
  - keep current checks only.

### app-deploy

Current order:

1. `keycloak.sh`
2. `middleware.sh`
3. `deployUI.sh`
4. `provisionSatelliteAdmin.sh`

Proposed:

- `manual`: unchanged.
- `acme`:
  1. `keycloak.sh`
  2. `middleware.sh`
  3. `deployUI.sh` (without hard dependency on local cert files)
  4. `deployEdgeAcme.sh` (new)
  5. `provisionSatelliteAdmin.sh`

## New Script: deployEdgeAcme.sh

Responsibilities:

- Render ACME edge compose template with hostnames and ACME settings.
- Create/secure ACME storage file (`chmod 600`).
- Bring edge stack up.
- Wait for challenge/cert readiness with bounded retries.
- Report success with active cert hostnames.

Expected inputs:

- `UIHostName`
- `MiddlewareHostName`
- `KeycloakHostName`
- `ACME_EMAIL`
- `ACME_STAGING`
- `ACME_CA_SERVER` (optional)

## New Template(s)

Add one template set under `templates/`:

- `docker-compose-edge-acme-template.yaml`

Template should:

- expose `80/443`,
- route by host header to:
  - UI upstream (`localhost:4200` or `ishare_ui:80` depending on network strategy),
  - middleware upstream (`localhost:5001` or `middleware-ishare_mw-1:21001`),
  - keycloak upstream (`localhost:8443`),
- include HTTP->HTTPS redirect except ACME challenge path,
- persist cert state in a volume/file.

## Keep Existing Deployment Stable

- Do not delete current `templates/nginx-template.conf` or `deployUI.sh` behavior.
- ACME mode is additive and selected by env.
- Existing manual cert users should not notice behavioral changes.

## Installer Reporting

Add report lines:

- `TLS mode` (manual/acme)
- ACME preflight pass/fail details:
  - DNS to host IP check per hostname,
  - port 80/443 conflict checks,
  - ACME account email validity,
- post-deploy checks:
  - HTTPS endpoint probe for each hostname,
  - cert subject/SAN probe.

## External Gate Changes

Current gate `EXT_TLS_MATERIAL`:

- `manual`: required and enforced.
- `acme`: replaced by runtime gate `EXT_ACME_READY`:
  - DNS + firewall + ports reachable,
  - ACME issuance successful.

## Migration Plan

1. Introduce env fields and default `TLS_MODE=manual`.
2. Add installer branching/validation.
3. Add edge ACME compose + script.
4. Add report checks + docs update.
5. Test matrix:
   - fresh manual install,
   - fresh acme install,
   - resume behavior for both modes,
   - forced app-deploy rerun idempotency,
   - staging ACME endpoint usage.

## Open Decisions

1. Edge implementation choice:
   - dedicated ACME-capable proxy container stack,
   - or certbot companion pattern with nginx.

2. Routing topology:
   - edge on host network to proxy to existing host ports,
   - or shared docker network with service-name upstreams.

3. Cert issuance policy:
   - strict fail app-deploy if cert not issued,
   - or allow degraded run with explicit warning status.

Recommended defaults:

- Edge on shared docker network with service-name upstreams where possible.
- Strict fail on ACME issuance in `acme` mode.
- Keep `manual` as default to avoid surprise behavior.

## Minimal Initial Scope (Phase 1)

- Add `TLS_MODE` + validation.
- Add ACME edge stack for UI + middleware only.
- Keep Keycloak on `:8443` initially with clear documentation.

Phase 2:

- Add Keycloak host on 443 through edge as well.
- Remove external `:8443` dependency from browser flows where possible.

## User-Facing CLI Prompt Draft

When `TLS_MODE` is prompted:

- `TLS_MODE (manual|acme) [manual]:`
  - `manual`: You provide `ssl/tls.crt` and `ssl/tls.key`.
  - `acme`: Installer obtains and renews certificates automatically using ACME HTTP challenge. Requires DNS + open ports 80/443.

If `acme` selected:

- `ACME_EMAIL (example: ops@example.com):`
- `ACME_STAGING (true|false) [false]:`

## Why This Solves Your Current Pain

- Eliminates manual cert copy/renew cycles when desired.
- Makes TLS behavior explicit and stage-validated.
- Keeps today’s manual deployment path available and stable.
