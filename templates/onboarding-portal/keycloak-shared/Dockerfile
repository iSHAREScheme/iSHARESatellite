# SHARED Keycloak = the onboarding-portal Keycloak image, extended to also serve the
# participant registry. Built FROM the portal KC image so ALL its custom wiring stays
# intact (provider JAR, eherkenning-claim-sync listener, broker flow, themes, entrypoint).
# We only graft on the registry's realm + login/email theme, and re-bake at /auth so the
# satellite's existing keyCloakConfig.domain (https://<kc-host>/auth) keeps working.
#
# See the onboarding portal section in docs/cli-install/server-cli-installer.md.

ARG PORTAL_KC_IMAGE
ARG KC_LEGACY_IMAGE=isharefoundation/ishare-satellite-keycloak:v22.0.1
ARG KEYCLOAK_SMTP_FROM=noreply@example.com

# Source the registry's custom theme from the legacy image (no theme source needed).
FROM ${KC_LEGACY_IMAGE} AS legacy

FROM ${PORTAL_KC_IMAGE}

# Some portal Keycloak images already contain a rendered onboarding realm import.
# Ensure the baked SMTP sender is a valid email address before Keycloak imports it.
USER root
RUN if [ -f /opt/keycloak/data/import/realm-export.json ]; then \
      sed -i -E "s/\"from\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"from\": \"${KEYCLOAK_SMTP_FROM}\"/" /opt/keycloak/data/import/realm-export.json; \
    fi
USER 1000

# Registry login/email theme (re-test on 26 - templates changed since 22).
COPY --from=legacy /opt/keycloak/themes/myTheme /opt/keycloak/themes/myTheme

# Local compatibility overrides for Keycloak 26 rendering.
COPY myTheme /opt/keycloak/themes/myTheme
COPY myTheme /opt/keycloak/themes/myThemeV2
COPY myTheme /opt/keycloak/themes/myThemeV3

# Registry realm export (rendered before build); imported alongside the portal realm by
# the portal entrypoint's `start --import-realm`. The entrypoint only post-wires the
# portal realm, so this realm is imported and left untouched.
COPY realm-test.json /opt/keycloak/data/import/realm-test.json

# Re-augment so the shared instance serves at /auth (keeping the portal's features/providers).
ENV KC_FEATURES=scripts,preview
RUN /opt/keycloak/bin/kc.sh build --http-relative-path=/auth
