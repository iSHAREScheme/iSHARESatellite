# iShare Satellite Backup and Restore
1. Login to respective Satellite VM and check the status of running container
```shell
  docker ps
```
2. Stop Docker Containers:
   It's generally a good idea to stop your Docker containers before backing up to ensure data consistency.

3. Stop all running Docker containers on your system
```sh
  docker stop $(docker ps -aq)
```
4. Compress the Project running directory to save space and make it easier to transfer.
### Note:
**Backup Naming:** When creating your tarball, ensure that **<SATELLITENAME-BACKUP>** is replaced with a meaningful name, such as the date or version of the backup, so you can easily identify it later.

```sh
   sudo tar -czvf <SATELLITENAME-BACKUP>.tar.gz iSHARESatellite/
```
5. Transfer Backup (*Optional*):
   If you want to move the backup to a different location or server, you can transfer the compressed backup file using the below command.

```shell
  sudo scp <SATELLITENAME-BACKUP>.tar.gz user@remote_server:/path/to/remote/directory
```
### Restoring the Backup ###

1. Login into the new server.
2. Install the prerequisites as per the installation document.
3. Extract the downloaded backup file to the desired directory/mount point.
```shell
  tar -xzvf <SATELLITENAME-BACKUP>.tar.gz 
```
4. Map the DNS to the new IP Address of server as mentioned in section 6 in INSTALL.md file. (**DNS record configuration**)
5. Copy the below script content and save to a file in the iSHARESatellite folder with **upsat.sh name**
```shell
#for bring up services:
#!/bin/bash
echo “Starting all docker containers... please wait...”
echo “Starting up Fabric ca”
docker-compose -f hlf/${RUNNER_MODE}/${orgName}/fabric-ca/docker-compose-fabric-ca.yaml up -d
sleep 15
echo “Starting up peers”
docker-compose -f hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml up -d
sleep 15
echo “Starting up chaincode”
docker-compose -f chaincode/cc-docker-compose-template.yaml up -d
sleep 15
echo “Starting up explorer”
docker-compose -f explorer/explorer-docker-compose.yaml up -d
sleep 20
echo “Starting up keycloak”
docker-compose -f keycloak/keycloak-docker-compose.yaml up -d
sleep 15
echo “Starting up middleware”
docker-compose -f middleware/docker-compose-mw.yaml up -d
sleep 30
echo “Starting up UI”
docker-compose -f ui/docker-compose-ui.yaml up -d
sleep 10
echo “Your satellite is up”
```
Update the given Variable with the Desired value as per the Satellite in the given script.
```text
${RUNNER_MODE}
${orgName}
```
6. Run the script to start the microservices.
```shell
 bash upsat.sh
```
*The above script will start the services one by one.*
