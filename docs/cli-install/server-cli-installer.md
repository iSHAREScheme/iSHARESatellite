# Server CLI Installer Guide

This guide explains how to run the server installer workflow through `scripts/install-server.sh`.

## Mode Summary

- Interactive mode (`bash scripts/install-server.sh`):
  - prompts for required values,
  - pre-fills recommended defaults for common participant-registry values,
  - lets you accept defaults by pressing Enter,
  - creates/updates `.env.server` (or the `--env-file` target),
  - shows a short explanation for each requested value.

- Non-interactive mode (`--non-interactive`):
  - does not prompt,
  - requires a pre-existing complete env file,
  - fails fast if required values are missing,
  - fails with explicit external-requirement messages when manual onboarding steps are pending.

## What It Does

The installer orchestrates the existing server deployment scripts in stages:

1. `preflight`
2. `env`
3. `fabric-base`
4. `org-artifact`
5. `join-network`
6. `app-deploy`

## External Requirements By Stage

Some steps depend on actions outside the VM. This is the expected order:

### Before `org-artifact`

- Ensure peer DNS records and firewall/NAT exposure are ready for `peer0.<ORG_NAME>.<SUB_DOMAIN>` and `peer1.<ORG_NAME>.<SUB_DOMAIN>`.
- Ensure peer ports `7051` and `8051` are reachable.

### After `org-artifact`

- Send `hlf/<ENVIRONMENT>/<ORG_NAME>/<ORG_NAME>.json` securely to iSHARE Foundation.
- This organization definition is used to admit your org to the shared channel.
- If admission is not completed yet, join operations can fail with `FORBIDDEN`.

### Before `join-network`

- Receive and place required onboarding artifacts: `<repo>/ca-ishareord.pem`, `<repo>/middleware/genesis.block`, `<repo>/middleware/isharechannel.tx`.
- Confirm onboarding values from Foundation are set correctly in `.env.server`: `ORDERER_ADDRESS`, `CHANNEL_NAME`, `CHAINCODE_*`, `PARTY_ID`, `PARTY_NAME`.

### Before `app-deploy`

- Provide `ssl/tls.crt` and `ssl/tls.key`.
- The certificate must cover all configured public hostnames: `UIHostName`, `MiddlewareHostName`, and `KeycloakHostName`.
- Valid options are one SAN certificate listing all required hostnames, or one wildcard certificate for the shared zone (for example `*.example.com`).
- Provide `jwt-rsa/jwtRSA256-public.pem` and `jwt-rsa/jwtRSA256-private.pem`.
- In production, this should come from your qualified eIDAS seal signing material.
- App DNS records should resolve for `UIHostName`, `MiddlewareHostName`, and `KeycloakHostName`.
- SMTP values should be valid: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`.
- The installer will also create/update one initial Keycloak portal user and assign the `SatelliteAdmin` role in your org realm.
- Configure this via `.env.server`:
  - `SATELLITE_ADMIN_USERNAME`
  - `SATELLITE_ADMIN_EMAIL`
  - `SATELLITE_ADMIN_PASSWORD`
- If `SATELLITE_ADMIN_PASSWORD` is left empty, the installer generates a temporary password and writes it to `.env.server`.

It also writes a stage-by-stage validation report under:

- `.local-state/server-install/reports/report-<timestamp>.txt`

And persists installer run state under:

- `.local-state/server-install/state.env`
- `.local-state/server-install/external-gates.env`
- `.local-state/server-install/last-error.log` (only when a run fails)

## Before You Start

1. Use a Debian/Ubuntu VM.
2. Make sure this repository is present on the VM.
3. Optional for interactive mode, required for non-interactive mode: prepare a server env file:

```bash
cp .env.server.example .env.server
```

4. Edit `.env.server` with your real values.

The installer prompts include:

- a short explanation for each value (what it is and why it is needed),
- example values,
- recommended defaults for common network values you can accept with Enter.

## Interactive Run

Interactive mode prompts for values and writes/updates your env file:

```bash
bash scripts/install-server.sh
```

## Non-Interactive Run

Use this when your env file is already complete:

```bash
bash scripts/install-server.sh --env-file .env.server --non-interactive
```

## Resume After Interruption

If a stage already completed and checkpointed:

```bash
bash scripts/install-server.sh --resume
```

If the installer pauses in `WAITING_EXTERNAL` state, resolve the external requirement and rerun the same resume command.

## Run One Stage

Useful for targeted retries:

```bash
bash scripts/install-server.sh --stage join-network
```

## Force Re-run a Stage

Even if a checkpoint exists:

```bash
bash scripts/install-server.sh --resume --force-stage app-deploy
```

## Reset Checkpoints

Start checkpointing fresh:

```bash
bash scripts/install-server.sh --reset-state --resume
```

## List Available Stages

```bash
bash scripts/install-server.sh --list-stages
```

## Show External Gate Status

Print persisted external gate statuses without running installer stages:

```bash
bash scripts/install-server.sh --show-external-gates
```

## Validation Report Contents

Each report includes:

- stage headers,
- PASS/WARN/FAIL checks,
- file and compose/runtime validations,
- final success/failure status.

Typical checks include:

- command availability and Docker access,
- `docker-compose` is Compose v2 (v1 is rejected),
- required env variables,
- stricter format checks for hostnames, host:port values, integer ports/sequences, and path syntax,
- required files (TLS/JWT/network artifacts),
- warning checks for private key file permissions (`tls.key`, `jwtRSA256-private.pem`),
- generated compose/artifact files,
- running service checks after deployment stages.

## Chaincode Package ID

`scripts/approveChaincode.sh` resolves the package ID dynamically from:

- `peer lifecycle chaincode queryinstalled` using `CHAINCODE_LABEL`, or
- explicit `CC_PACKAGE_ID` when provided.

If auto-detection does not find your label, set `CC_PACKAGE_ID` in `.env.server`.
