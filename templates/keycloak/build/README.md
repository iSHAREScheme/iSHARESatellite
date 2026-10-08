# Registry Keycloak image (Keycloak 26.6.2)

Build context for the participant-registry Keycloak, used by `scripts/keycloak.sh`
(rendered to `../keycloak/build/` at deploy time and built via the `build:` section of
`keycloak-docker-compose.yaml`).

## Why
The registry previously ran the Foundation prebuilt `isharefoundation/ishare-satellite-keycloak:v22.0.1`.
Inspecting it showed it is **vanilla Keycloak 22 + one custom theme (`myTheme`) + the realm import**,
with **no custom Java**. Moving to **26.6.2** aligns it with the onboarding portal's Keycloak so a
single shared instance becomes possible. See `docs/onboarding-portal-optional-deploy.md` §11 & §12.

## What this image contains
- Keycloak **26.6.2** (`quay.io/keycloak/keycloak:26.6.2`).
- `myTheme` — copied verbatim from the 22.0.1 image (multi-stage `COPY --from=legacy`), so no
  theme source is required. **Re-test on 26** (login theme templates changed since 22).

That is all: this is the registry's **own** Keycloak. It carries no custom provider JARs.

## Shared single-Keycloak topology
This image is **not** extended for the optional shared instance. In shared mode the registry's
own Keycloak is not deployed at all; instead a single Keycloak is built **`FROM` the onboarding
portal's Keycloak image** (which already carries the portal's provider + theme + entrypoint), with
the registry realm + `myTheme` grafted on. See `docs/onboarding-portal-optional-deploy.md` §11.3
and `scripts/deployOnboardingPortalKeycloak.sh`.

## ⚠️ Upgrade notes (22 → 26)
- **Back up the `keycloakpostgres` volume first** — first 26 start runs a one-way DB migration.
- KC-26 flags differ: `--proxy=edge` → `--proxy-headers=xforwarded`; hostname "v2" uses a full
  `KC_HOSTNAME=https://host[:port]` URL (no `KC_HOSTNAME_ADMIN_URL`); these are applied by
  `scripts/keycloak.sh`.
- Health/metrics moved to management port 9000 (only relevant if something probes KC health).

## Build args
- `KC_LEGACY_IMAGE` (default `isharefoundation/ishare-satellite-keycloak:v22.0.1`) — the image
  `myTheme` is copied from.
