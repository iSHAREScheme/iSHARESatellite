**iSHARE Satellite Patch v2.0.2 manual**


# Table of Contents


[Introduction ](#introduction)


[List of Components ](#list-of-components)


[Pre-requisites ](#pre-requisites)


[Component #1: UI & Nginx](#component-1-ui--nginx)


# Introduction


This document explains the steps for deploying iSHARE Satellite on version v2.2-rc

# Component #1: UI & Middleware

UI:

1.  Login to the shell command prompt of your VM.


2. Navigate to
```shell
<satellite install path>/iSHARESatellite/ui
```


3. Edit docker-compose-ui.yaml file
```shell
nano docker-compose-ui.yaml
```
4. Update the image version under ishare_ui services from 3.0 to v2.2-rc as shown below


```shell
   image: isharefoundation/ishare-satellite-ui:v2.2-rc
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

MW:


1. Navigate to
```shell
<satellite install path>/iSHARESatellite/ui
```


2. Edit docker-compose-ui.yaml file
```shell
nano docker-compose-mw.yaml
```
3. Update the image version under middleware services from 4.18 to v2.2-rc as shown below


```shell
   image: isharefoundation/ishare-satellite-app-mw:v2.2-rc-20260327151020
```


4. Save and exit, press ctrl+x and select yes (or input y) to save and exit


5. Stop the currently running docker container of iSHARE MW


```shell
docker-compose -f docker-compose-mw.yaml down
```


6. Start the   docker container of iSHARE MW to latest version


```shell
docker-compose -f docker-compose-mw.yaml up -d
```


7. Wait for 20-30 seconds and then check if the container is correctly running. To list the currently running docker containers you can execute following command


```shell
docker ps -a
```


If all containers show as healthy and running, then your iSHARE satellite is upgraded. You may proceed to your application UI to check if everything is working fine.
