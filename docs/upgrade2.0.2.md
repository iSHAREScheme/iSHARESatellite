**iSHARE Satellite Patch v2.0.2 manual**


# Table of Contents


[Introduction ](#introduction)


[List of Components ](#list-of-components)


[Pre-requisites ](#pre-requisites)


[Component #1: UI & Nginx](#component-1-ui--nginx)


# Introduction


This document explains the steps for upgrading iSHARE Satellite v2.0.1 to v2.0.2


Release 2.0.2 fixes the bug where an Authorisation Registry could not be added to a participant who registered via the Identity Provider (via api). After the upgrade, the functionality should be fixed.


> [!note]
> Since this is a UI related patch, please make sure to clear cache of your browser and re-open your browser before again accessing the UI of the Satellite post upgrade.






# List of Components


1. 
   a.  UI & Nginx




# Pre-requisites


If you are installing a fresh instance of Satellite, then you do not need to do anything, the installation configuration is already referring to the patched version.


If you are upgrading an existing installation then follow the steps given below.


First, Make sure that you are on release v2.0.1


You can do that by matching the tags of the docker components as shown below:




```                          
isharefoundation/ishare-satellite-ui:v3.0                   ishare_ui
nginx:1.25.1-alpine                                         ui_nginx-proxy_1
isharefoundation/ishare-satellite-keycloak:v22.0.1          keycloak
isharefoundation/postgressql:v14-alpine                     keycloakpostgres
ghcr.io/hyperledger-labs/explorer:2.0.0                     explorer
ghcr.io/hyperledger-labs/explorer-db:2.0.0                  explorerdb
isharefoundation/ishare-satellite-hlf-mw:v1.9               middleware_ishare_hlf_1
isharefoundation/ishare-satellite-app-mw:v4.18              middleware_ishare_mw_1
isharefoundation/postgressql:v15.0-alpine                   offchain_sat
isharefoundation/ishare-satellite-cc:v2.0                   chaincode_ishare-cc.hlf_1
isharefoundation/fabric-peer:v2.5.4                         peers_peer1.example.com_1
isharefoundation/couchdb:v3.3.2                             peers_couchdb.peer1.example.com_1
isharefoundation/couchdb:v3.3.2                             peers_couchdb.peer0.example.com_1
isharefoundation/fabric-peer:v2.5.4                         peers_peer0.iexample.com_1
isharefoundation/fabric-ca:v1.5.7                           ca.example.com
```


To list the currently running docker containers you can execute following command


```shell
docker ps
```
> [!note]
> Please make sure to perform a backup of your iSHARE Satellite before proceeding with the upgrade. Please refer to [backup](backup.md) guide for instructions.


> [!note]
> Additionally, please make sure to perform a backup/snapshot of the VM before proceeding with the upgrade. Please refer to your provider for instructions on how to take VM backup/snapshot including the disks.


# Component #1: UI & Nginx


1.  Login to the shell command prompt of your VM.


2. Navigate to
```shell
<satellite install path>/iSHARESatellite/ui
```


3. Edit docker-compose-ui.yaml file
```shell
nano docker-compose-ui.yaml
```
4. Update the image version under ishare_ui services from 3.0 to 3.0.2 as shown below


```shell
   image: isharefoundation/ishare-satellite-ui:v3.0.2
```


5. Save and exit, press ctrl+x and select yes (or input y) to save and exit


6. Stop the currently running docker container of iSHARE UI


```shell
docker-compose -f docker-compose-ui.yaml down
```


7. Start the   docker container of iSHARE UI to latest version


```shell
docker-compose -f docker-compose-ui.yaml up -d
```


8. Wait for 20-30 seconds and then check if the container is correctly running. To list the currently running docker containers you can execute following command


```shell
docker ps -a
```


If all containers show as healthy and running, then your iSHARE satellite is upgraded. You may proceed to your application UI to check if everything is working fine.


