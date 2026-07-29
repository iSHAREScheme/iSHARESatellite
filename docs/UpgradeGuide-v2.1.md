**iSHARE Satellite Upgrade v2.1 manual**


# Table of Contents

[Introduction](#introduction)

[List of Components](#list-of-components)

[Pre-requisites](#pre-requisites)

[Part 1: Upgrade the Containers](#part-1-upgrade-the-containers)

- [Component #1: UI](#component-1-ui)
- [Component #2: Middleware](#component-2-middleware)
- [Component #3: Chaincode](#component-3-chaincode)

[Part 2: Migrate Records from v2 to v2.1](#part-2-migrate-records-from-v2-to-v21)


# Introduction

This document explains the steps for upgrading an existing iSHARE Satellite to **v2.1**.

Release v2.1 ships updated versions of the middleware, UI, and chaincode that work with the new `add_id_also_known_as` migration. The upgrade has two parts:

1. **Part 1 — Upgrade the containers:** pull and run the new v2.1 container images.
2. **Part 2 — Migrate your data:** move your existing v2 records into the new v2.1 format.

Please complete Part 1 before starting Part 2.


# List of Components

The following components are updated in this release:

| # | Component  | New image                                          |
|---|------------|----------------------------------------------------|
| 1 | UI         | `isharefoundation/ishare-satellite-ui:v3.2-rc`     |
| 2 | Middleware | `isharefoundation/ishare-satellite-app-mw:v4.20-rc`|
| 3 | Chaincode  | `isharefoundation/ishare-satellite-cc:v2.1-rc`     |


# Pre-requisites

If you are installing a **fresh** instance of the Satellite, you do not need this guide — the installation configuration already refers to the v2.1 versions.

If you are **upgrading an existing installation**, complete the checklist below before you begin.

> [!note]
> Please make sure to perform a backup of your iSHARE Satellite before proceeding. Refer to the [backup](backup.md) guide for instructions.

> [!note]
> Additionally, please take a backup/snapshot of the VM (including the disks) before proceeding. Refer to your cloud provider for instructions.

**Checklist before you start:**

1. Log in to the shell command prompt of your VM.
2. Make sure you know the location of your `iSHARESatellite` repository (the "satellite install path").
3. Confirm the Satellite is currently running:

   ```shell
   docker ps
   ```


# Part 1: Upgrade the Containers

In this part you first update all three compose files to point at the new v2.1 images, and then restart the whole Satellite once using the provided scripts.

> [!note]
> Do **not** restart containers individually after each edit. Make all three edits first, then restart everything together in the [Restart the Satellite](#restart-the-satellite) step.


## Step 1: Update the UI compose file

1. Open the file for editing:

   ```shell
   nano <satellite install path>/iSHARESatellite/ui/docker-compose-ui.yaml
   ```

2. Under the `ishare_ui` service, update the image to:

   ```yaml
   image: isharefoundation/ishare-satellite-ui:v3.2-rc
   ```

3. Save and exit (press `Ctrl+X`, then `Y`, then `Enter`).


## Step 2: Update the Middleware compose file

1. Open the file for editing:

   ```shell
   nano <satellite install path>/iSHARESatellite/middleware/docker-compose-mw.yaml
   ```

2. Under the `ishare_mw` service, update the image to:

   ```yaml
   image: isharefoundation/ishare-satellite-app-mw:v4.20-rc
   ```

3. Save and exit (press `Ctrl+X`, then `Y`, then `Enter`).


## Step 3: Update the Chaincode compose file

1. Open the file for editing:

   ```shell
   nano <satellite install path>/iSHARESatellite/chaincode/cc-docker-compose-template.yaml
   ```

2. Under the `ishare-cc.hlf` service, update the image to:

   ```yaml
   image: isharefoundation/ishare-satellite-cc:v2.1-rc
   ```

3. Save and exit (press `Ctrl+X`, then `Y`, then `Enter`).


## Restart the Satellite

Once **all three** compose files have been updated, restart the entire Satellite using the scripts in the `scripts` folder.

> [!important]
> Before running the start script, open `satellite_start.sh` and make sure all the compose-file paths are correct for your installation. In particular, replace the `<env>` and `<orgname>` placeholders in the Fabric CA and peers paths with your actual values, for example:
>
> ```shell
> docker compose -f $SAT_HOME/hlf/<env>/<orgname>/fabric-ca/docker-compose-fabric-ca.yaml up -d
> docker compose -f $SAT_HOME/hlf/<env>/<orgname>/peers/docker-compose-hlf.yaml up -d
> ```
>
> The script will not start the Satellite correctly until these paths point to the right files.

1. Navigate to the `scripts` folder:

   ```shell
   cd <satellite install path>/iSHARESatellite/scripts
   ```

2. Stop all running containers:

   ```shell
   ./satellite_stop.sh
   ```

3. Start all containers back up with the new images:

   ```shell
   ./satellite_start.sh
   ```

   The start script brings the components up in order and may take a couple of minutes. Wait until you see the `Your satellite is up` message.


## Confirm the upgrade

List the containers and confirm they are healthy and running:

```shell
docker ps -a
```

If all containers show as healthy and running, the container upgrade is complete. Continue to Part 2 to migrate your records.


# Part 2: Migrate Records from v2 to v2.1

Once the containers are upgraded, migrate your existing records into the v2.1 format. This uses the `pr-migrate-v2.2` helper container.

> [!note]
> Throughout this section, replace `<folder-to-store-migration-files>` with the folder you create in Step 2, and use the same folder in every command.


## Step 1: Pull the migration image

```shell
docker pull isharefoundation/pr-migrate-v2.2:latest
```


## Step 2: Create a folder for the migration files

```shell
mkdir <folder-to-store-migration-files>
```


## Step 3: Query the existing records

This reads your current records from the middleware and writes them into your migration folder.

```shell
docker run --rm --network=host \
  -v "<folder-to-store-migration-files>":/migration_files \
  isharefoundation/pr-migrate-v2.2:latest \
  query --middleware-url "http://localhost:4001"
```


## Step 4: Transform the records

Choose **one** of the two options below.

**Option A — Use the KVK API** (recommended for production). Replace `<KvK-api-key>` and `<kvk-api-url>` with your values:

```shell
docker run --rm --network=host \
  -v "<folder-to-store-migration-files>":/migration_files \
  isharefoundation/pr-migrate-v2.2:latest \
  transform --kvk-api-key <KvK-api-key> --kvk-api-url <kvk-api-url>
```

**Option B — Skip the KVK API** (development/testing). The script derives dummy iSHARE DIDs:

```shell
docker run --rm --network=host \
  -v "<folder-to-store-migration-files>":/migration_files \
  isharefoundation/pr-migrate-v2.2:latest \
  transform --dev
```


## Step 5: Fill in any missing values

Open the file below and manually complete any values the transform step could not determine:

```
<folder-to-store-migration-files>/to_migrate/add_id_also_known_as.csv
```


## Step 6: Run the migration

```shell
docker run --rm --network=host \
  -v "<folder-to-store-migration-files>":/migration_files \
  isharefoundation/pr-migrate-v2.2:latest \
  migrate --middleware-url "http://localhost:4001"
```

Once this completes, your records are migrated and the upgrade to v2.1 is finished. Open the Satellite UI to confirm everything is working as expected.

> [!note]
> Since this release includes UI changes, please clear your browser cache and re-open your browser before accessing the Satellite UI post-upgrade.
