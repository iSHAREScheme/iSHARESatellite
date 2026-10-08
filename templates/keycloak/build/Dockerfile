# Participant-registry Keycloak — built on Keycloak 26.6.2.
#
# Replaces the Foundation prebuilt image (isharefoundation/ishare-satellite-keycloak:v22.0.1)
# so the registry's Keycloak runs the same major version (26.6.2) as the onboarding portal's
# Keycloak. That version alignment is what makes the OPTIONAL shared single-Keycloak topology
# possible (see docs/onboarding-portal-optional-deploy.md §11/§12).
#
# Inspection of the 22.0.1 image showed it is *vanilla Keycloak 22 + one custom theme*
# (`myTheme`, used as both loginTheme and emailTheme) + the realm import — NO custom Java.
# So this image simply carries `myTheme` over verbatim from the 22.0.1 image (no theme source
# needed) and adds nothing else.
#
# This builds the registry's OWN Keycloak (own / registry-only deploys). The optional shared
# single-Keycloak topology does NOT extend this image — it builds FROM the onboarding-portal
# Keycloak image instead, so there are no custom provider JARs to stage here. See §11.3.
#
# Realms are imported at runtime from the mounted /opt/keycloak/data/import directory via the
# compose `start --import-realm` command.
#
# ⚠️  IMPORTANT: 22 -> 26 runs a one-way Keycloak DB migration on first start. Back up the
#     keycloakpostgres volume first. And re-test `myTheme` on 26 (login theme templates changed
#     since 22) — see §12.2 #4.

ARG KC_LEGACY_IMAGE=isharefoundation/ishare-satellite-keycloak:v22.0.1

# Source only the custom theme from the legacy image.
FROM ${KC_LEGACY_IMAGE} AS legacy

FROM quay.io/keycloak/keycloak:26.6.2

# Registry's custom login/email theme, carried over from 22.0.1 (re-test on 26).
COPY --from=legacy /opt/keycloak/themes/myTheme /opt/keycloak/themes/myTheme

# Local compatibility overrides for Keycloak 26 rendering.
COPY myTheme /opt/keycloak/themes/myTheme
COPY myTheme /opt/keycloak/themes/myThemeV2
COPY myTheme /opt/keycloak/themes/myThemeV3

# The base image's entrypoint is /opt/keycloak/bin/kc.sh; the compose `command` supplies
# `start ... --import-realm`. Keycloak augments (build) on first start.
