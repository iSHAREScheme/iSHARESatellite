# Server CLI Installer Guide

This guide explains how to run the server installer workflow through `scripts/install-server.sh`.

## Mode Summary

- Interactive mode (`bash scripts/install-server.sh`):
  - prompts for required values,
  - pre-fills recommended defaults for common participant-registry values,
  - creates/updates `.env.server` (or the `--env-file` target),
  - shows a short explanation for each requested value.

- Non-interactive mode (`--non-interactive`):
  - does not prompt,
  - requires a pre-existing complete env file,
  - fails fast if required values are missing.

## What It Does

The installer orchestrates the existing server deployment scripts in stages:

1. `preflight`
2. `env`
3. `fabric-base`
4. `org-artifact`
5. `join-network`
6. `app-deploy`

It also writes a stage-by-stage validation report under:

- `.local-state/server-install/reports/report-<timestamp>.txt`

And persists installer run state under:

- `.local-state/server-install/state.env`
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

## Validation Report Contents

Each report includes:

- stage headers,
- PASS/WARN/FAIL checks,
- file and compose/runtime validations,
- final success/failure status.

Typical checks include:

- command availability and Docker access,
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
