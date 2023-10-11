
# Introduction

This document explains the backup activity of the existing
components.

# List of Components

**1.**  HLF Components

    a.  Fabric CA

    b.  CouchDB

    c.  Fabric Peer


**2.**  Application Components-UI

    a.  UI

    b.  MW

    c.  HLF middleware

    d.  Chaincode

**3.** Keycloak

**4.** Explorer

# Component #1:HLF Components

**1.**  Redirect to below directory. Change the environment and orgname
    appropriately in the below command.

```shell
cd iSHARESatellite/hlf/<Environment>/<orgName>/fabric-ca
```

**2.**  Using the below command, stop the docker container.

```shell
docker-compose -f docker-compose-fabric-ca.yaml down
```

**3.** Redirect to below directory. Change the environment and orgname
appropriately in the below command.

```shell
cd iSHARESatellite/hlf/<Environment>/<orgName>/peers
```

**4.** Using the below command, stop the docker container.

```shell
docker-compose -f docker-compose-hlf.yaml down
```

**5.** Redirect to below directory. Change the environment and orgname
appropriately in the below command.

```shell
cd iSHARESatellite/
```

**6.** Take the particular hlf setup backup and Execute the below two
commands for the backup activity.

```shell
sudo zip -r hlf-setup-bkup-<date>.zip hlf/
```



# Component #2: Application Components-UI

**1.**  Redirect to below directory.

```shell
cd iSHARESatellite/
```

**2.** Take the ui folder setup using the below command.

```shell
sudo zip -r ui_setup-bkup-<date>.zip ui/
```

**Note:** This data backup will include below given services.

- UI

- Nginx

# Component #3: Application Components- (Offchain DB,HLF-MW,MW) 

**1.**  .Redirect to below directory.

```shell
cd iSHARESatellite/middleware
```

**2.** Using the below command, stop the docker container.

```shell
docker-compose -f docker-compose-mw.yaml down
```

**3.** Once the services is down, redirect to given directory

```shell
cd iSHARESatellite/
```

**4.** Take backup of entire middleware folder using given command.

```shell
sudo zip -r middleware_setup-bkup-<date>.zip middleware/
```

**Note:** This data backup will include below given services.

-   Middleware

-   HLF Middleware

-   App Postgres DB

# Component #4: Chaincode

**1.** Redirect to below directory.

```shell
cd iSHARESatellite/chaincode
```

**2.** Using the below command, stop the docker container.

```shell
docker-compose -f cc-docker-compose-template.yaml down
```

**3**. Redirect to below directory.

```shell
cd iSHARESatellite/
```

**4.** Take backup of entire chaincode folder using given command.

```shell
sudo zip -r chaincode_setup-bkup-<date>.zip chaincode/
```

# Component #5: Keycloak and PostgresDB

**1.**  Redirect to below directory.

```shell
cd iSHARESatellite/keycloak
```
**2.**  Using the below command, stop the docker container.

```shell
docker-compose -f keycloak-docker-compose.yaml down
```

**3.**  Take a backup of keycloak-docker-compose.yaml file. Execute the
    below command for the backup activity.

```shell
cp keycloak-docker-compose.yaml keycloak-docker-compose.yaml-bkup
```

**4.**  Redirect to iSHARESatellite folder and take a backup of the entire
    keycloak setup. Execute the below commands.

```shell
cd iSHARESatellite
```

```shell
sudo zip -r keycloak-bkup-<date>.zip keycloak/
```

**Note:** This data backup will include below given services.

-   Keycloak

-   PostgresDB

# Component #6: Explorer

**1.**  Redirect to below directory.

```shell
cd iSHARESatellite/explorer
```
**2.**  Using the below command, stop the docker container.

```shell
docker-compose -f explorer-docker-compose.yaml down
```

**3.**  Redirect to below directory.

```shell
cd iSHARESatellite/
```

**4.**  Take the explorer setup backup. Execute the below command for the
    backup activity.

```shell
sudo zip -r explorer-bkup-<date>.zip explorer/
```
