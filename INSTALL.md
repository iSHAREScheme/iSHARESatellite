<img align="right" src="docs/assets/isharelogo-small.png">

iSHARE FOUNDATION

iSHARE SATELLITE DEPLOYMENT GUIDE

VM-Docker based model running on Debian-based GNU/Linux distribution.

# Table of Content

[**1. Pre-requisites**](#pre-req)

[**2. Hardware Requirements**](#hardware-req)

[**2.1. Minimum**](#minimum)

[**2.2. Recommendation**](#recommendation)

[**3 Network Requirements**](#network-req)

[**4. Getting Started**](#get_start)

[**5. Configure Passwords for the services**](#configure)

[**6. Installing Hyperledger Fabric Node**](#install_hyp)

[**7. Register your node**](#reg_node)

[**8. Join the network**](#join_net)

[**9. Deploy the UI and middleware applications**](#deploy)

[**10. Initial user setup**](#U_setup)

[**11. Configure keycloak**](#configure_keycloak)

[**12. Set up email notifications**](#email)

[**13. Enable 2FA for users**](#2FA)

[**14. Commands for managing Docker services**](#docker_service)

[**15. Reference updates deployment procedure**](#ref_update)

# <a id="pre-requisites">  1. Pre-requisites </a>

The proposed model requires virtual machines provisioned on cloud providers and/or on-prem with prescribed operating systems and following software's installed in them. Make sure that you have them before beginning. 

*Note: the scripts and components are tested in versions mentioned in the brackets, usually it should work well in higher version as well.*

1. A recent Debian-based GNU/Linux distribution (tested on Debian 11 / Bullseye and Ubuntu Linux 20.04.4 LTS / Focal Fossa).
1. Create/Update rights to your DNS service to manage satellite URLs in DNS record. 
1. SSL certificates of your domain for applications (applications by default use HTTPS so having certificates on hand is required. You may also use free Letsencrypt certificates, please refer to its website to acquire them. 
1. JWT signing certificate:  
   - For production environments – Qualified Seals as defined in iSHARE specifications, 
   - For test environments – test certificates obtained from <https://ca7.isharetest.net:8442/ejbca/ra/>. Use "postpone" option when you request a test certificate. You will get email with link to download the certificate file, once your request is approved.

# <a id="hardware-req"> 2. Hardware Requirements </a>

## <a id="minimum"> 2.1. Minimum </a>

Virtual Machine with 2 CPU’s and 8 GB Memory.

## <a id="recommendation"> 2.2. Recommendation </a>

Virtual Machine with 4 CPU’s and 16 GB Memory.

# <a id="network-req"> 3. Network Requirements </a>
Following ports are used by following applications, so make sure that you configure your firewall and network settings to allow access via these ports

- 443/TCP,80/TCP for Application middleware and UI
- 7051/TCP and 8051/TCP for HLF Peers
- 8443/TCP for keyCloak instance (user management backend)
- Optionally, 8081/TCP for explorer instance (hyperledger explorer) – open to outside only if require access from outside your own network, maybe necessary when hosted on cloud.

# <a id="get_start"> 4. Getting Started </a>

The iSHARE satellite is based on Hyperledger fabric. When participants are registered via a satellite, the participants is directly registered on the shared ledger, meaning the participant is trusted across the iSHARE network. The iSHARE satellite is composed of following sub-components:

- Hyperledger fabric node,
- Application UI,
- Keycloak (user managment backend),
- Satellite Middleware (APIs and other relevant functions).

This guide will take your through the following steps (sections), in order to install and configure the iSHARE satellite:

5. Download the script files, and configure your passwords,
1. Install Hyperledger fabric node.
1. Register your node.
1. Join the iSHARE network. 
1. Deploy the UI and middleware applications. 
   1. Deploy keycloak.
   1. Deploy middleware.
   1. Deploy UI.
1. Set up and configure satellite access control. Configure satellite admin user and log in the the satellite user interface. 

## <a id="configure"> 5. Configure Passwords for the Services </a>
If you want to change the default passwords (recommended and mandatory for production environments) please follow the steps below. You are not obliged to configure passwords if you are setting up the satellite for a test environment.

The following services use username and password as credentials for authentication:

- Postgres DB for Application
- Explorer DB for Explorer
- Postgres DB for Keycloak

Download the scripts from GitHub:

```sh
git clone https://github.com/iSHAREScheme/iSHARESatellite.git
cd iSHARESatellite
```




### Steps to configure password for changing HLF Explorer’s DB

```sh
cd iSHARESatellite/templates
```

Open explorer-docker-compose-template.yaml in the text editor.

Under *services* section, change the password for explorerdb by referring below snippet under environment:

```yaml
explorerdb:
    image: hyperledger/explorer-db:latest
    container_name: explorerdb
    hostname: explorerdb
    environment:
      - DATABASE_DATABASE=fabricexplorer
      - DATABASE_USERNAME=hppoc
      - DATABASE_PASSWORD=password
```

Same Password has be configured for explorer service under environment, refer below snippet:

```yaml
explorer:
    image: hyperledger/explorer:latest
    container_name: explorer
    hostname: explorer
    environment:
      - DATABASE_HOST=explorerdb
      - DATABASE_DATABASE=fabricexplorer
      - DATABASE_USERNAME=hppoc
      - DATABASE_PASSWD=password
```

Open app-mw-config-template.yaml in the text editor, configure password in explorer db connection string. Check below:

```yaml
explorerDb:
  postgresql://hppoc:password@explorerdb:5432/fabricexplorer?sslmode=disable
```

### Steps to configure password for Application middleware postgres DB

```sh
cd iSHARESatellite/templates
```

Open docker-compose-mw-template.yaml in a text editor and look for below snippet:

```yaml
app-postgres:
  image: postgres:9
  restart: always
  environment:
    POSTGRES_USER: admin
    POSTGRES_PASSWORD: adminpw
```

Change password for admin user under environment section and save.

Open hlf-mw-config-template.yaml file in a text editor and look for the below snippet and lower end of the file:

```yaml
ishareConfig:
  middlewareConfig:
    type: satellite
    postgres_connection_url: postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
```

Change the password adminpw in connection string with password configured in docker-compose-mw.yaml.

Open app-mw-config-template.yaml file in a text editor and look for the below snippet:

```yaml
ishareConfig:
  middlewareConfig:
    postgres_connection_url:
      postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
```

Change the password `adminpw` in connection string with password configured in `docker-compose-mw.yaml`.

### Steps to configure password for Application Keycloak service

```sh
cd iSHARESatellite/keycloak/postgres
```

Open `init-db.sql` in a text editor:

```sql
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloak';
```

Change password from `keycloak` to desired password. Password should be between single quotes.

```sh
cd iSHARESatellite/keycloak
```

Open `keycloak-docker-compose.yaml` in a text editor, look for below snippet

```yaml
keycloak:
    image: jboss/keycloak:11.0.2
    container_name: keycloak
    ports:
      - 8443:8443
environment:
      - KEYCLOAK_USER=admin
      - KEYCLOAK_PASSWORD=admin
      - DB_VENDOR=postgres
      - DB_ADDR=keycloakpostgres
      - DB_DATABASE=keycloak
      - DB_USER=keycloak
      - DB_PASSWORD=keycloak
```

Change `DB_PASSWORD` value keycloak with desired password value.

## <a id="install_hyp"> 4.2. Installing Hyperledger Fabric node </a>

Hyperledger Fabric

The fabric component for each satellite will contain:

1. 2 Peers
1. Shared Orderer
1. 2 CouchDB
1. 1 Fabric CA

These components have to be pulled as images, installed and initialized as per the directions mentioned here.

### Steps and sequence for creating HLF components

Download the scripts from GitHub (if not done so already)

```sh
git clone https://github.com/iSHAREScheme/iSHARESatellite.git
cd iSHARESatellite
```

To install and ensure all the necessary packages are available in the system, use the below script to install the missing packages.

```sh
bash prerequisites.sh
```

If docker was not already setup and configured for the current user, logout and login before continuing.

Configure environment variables to initialize scripts. See environment variables with example below. 

| **Environment** | **Description**                                                                                                                                                     |
|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ORG_NAME`      | Satellite which is going to be a part of HLF network. It should be a word  without special characters (only alphanumeric) and max 17 characters. ex: `mysatellite`. |
| `SUB_DOMAIN`    | Sub-domain reserved in DNS service for this satellite. No special characters. ex: `uat.mydomain.com`                                                                |
| `ENVIRONMENT`   | Name of the infra environment like `uat`, `test`, `prod`. No special characters.                                                                                    |

**Note: the ORG_NAME variable is exclusive. If you earlier tried to deploy a satellite, and this satellite was removed, you can not re-use the same ORG_NAME**. 
```sh
export ORG_NAME=newsatellite
export SUB_DOMAIN=test.example.com
export ENVIRONMENT=test
cd scripts
```

To generate HLF fabric ca certs, use the below command :

```sh
bash fabric-ca-cert.sh
```

Creating HLF Fabric CA instance:

```sh
bash fabric-ca.sh
```

Wait more than a minute after running the above command. Certificates are being generated. Running the next "bash" command too early will cause an error. 

#### Validation

Navigate to `iSHARESatellite/hlf/<Environment>/<orgName>/fabric-ca` directory.

Check the presence of the `docker_data` folder.

To ensure all the HLF Fabric is running, use below commands and check the status.

```sh
docker-compose -f docker-compose-fabric-ca.yaml ps
```

Register and Enroll users and peers

```sh
bash registerAndEnroll.sh
```

Create HLF Peer instances, it will spun up instances of HLF Peers and CouchDB:

```sh
bash peer.sh
```

#### Validation

Navigate to `iSHARESatellite/hlf/<Environment>/<orgName>/peers` directory.

Check the presence of the `docker_data` folder.

To ensure all the HLF Peer is running, use below commands to check the status.

```sh
docker-compose -f docker-compose-hlf.yaml ps
```

HLF Peer instances needs to be a part of  iSHARE Foundation HLF network, for that HLF peers needs to reachable over the internet. Previous script peer.sh creates two HLF peer instance with hostname `peer<num>.<ORG_NAME>.<SUB_DOMAIN>` and they listen at port 7051 and 8051 TCP. Make sure that necessary firewall settings are updated to allow access to these peers over internet. Map DNS entries for Peers hostname with server IP address example for `ORG_NAME=newsatellite` and `SUB_DOMAIN=test.example.com`:

`peer0.<orgname>.<subdomain>` -> `peer0.newsatellite.test.example.com`  
`peer1.<orgname>.<subdomain>` -> `peer1.newsatellite.test.example.com`

| **Full Record Name**          | **Record Type** | **Value**  | **TTL** |
|-------------------------------|-----------------|------------|---------|
| `peer0.<orgname>.<subdomain>` | A               | 12.9.7.6.5 | 1 min   |
| `peer1.<orgname>.<subdomain>` | A               | 12.9.7.6.5 | 1 min   |

The Hyperledger fabric node is deployed. Now follow the next chapter to register your node in the network.

## 4.3. <a id="reg_node"> Register your node </a>

Share details with iSHARE foundation to register your node on iSHARE network.

Now generate the organization definition file which iSHARE Foundation (HLF Channel Admin) would require inorder to onboard your new satellite. Use the below command to create an org definition.

```sh
bash orgDefinition.sh
```

Find the `<orgName>.json` file in the `hlf/<ENVIRONMENT>/<ORG_NAME>` folder.

Note: `<orgName>.json` file has to be shared securely, as it contains x509 certificates of the new satellite.

Send this file as well as following details to iSHARE foundation.

## 4.4. <a id="join_net"> Join the network </a>

Join the network with information received from iSHARE Foundation. You should receive following information and files from iSHARE Foundation:

**Files to be copied into your VM**

- Certificate authority file of HLF ordering service. Called `ca-ishareord.pem`
- `genesis.block` 
- `isharechannel.tx`

Note: the `genesis.block` 
 and `isharechannel.tx` will be used at a later stage (section 4.5). 
 


**Values for following variables**

- `ORDERER_ADDRESS` - one of the ordering services hostname and port
- `CHANNEL_NAME` - channel name in which a particular satellite is on boarded
- `CHAINCODE_NAME` - chaincode (smart contract) which is defined in chaincode definition committed
- `CHAINCODE_VERSION` -  chaincode version defined in chaincode definition committed
- `CHAINCODE_SEQUENCE` - sequence number associated with chaincode
- `CHAINCODE_POLICY` - chaincode policy string used while commiting chaincode definition in the HLF network
- `PARTY_ID` - EORI identifier that iSHARE has used to register you in the network.
- `PARTY_NAME` - Name used by iSHARE to register you in the network.

Once the above details is known, move the copy of the `ca-ishareord.pem` file in the VM and follow below steps.

Export these environment variables:

| **Environment Variables** | **Description**                                                                                                                                                 |
|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `PEER_COUNT`              | Number of HLF Peer nodes in a satellite. The default number of peers is 2.|
| `ORDERER_TLS_CA_CERT`     | Path to CA cert file (`ca-ishareord.pem`) of ordering service which you received from iSHARE Foundation and copied to your VM |
| `ORDERER_ADDRESS`         | Ordering service hostname with port ex: `orderer1.example.aks.io:443`                                                                                           |
| `CHANNEL_NAME`            | Name of the channel in which new satellite is onboarded.                                                                                                        |
| `ANCHOR_PEER_HOSTNAME`    | HLF peer node hostname of a new satellite. ex: `peer0.example.com`. The peer name from chapter 4.2                                                              |
| `ANCHOR_PEER_PORT_NUMBER` | HLF peer node listening port ex: `7051`, corresponding port of the peer set in `ANCHOR_PEER_HOSTNAME`                                                           |
| `CHAINCODE_NAME`          | Chaincode (smart contract) name defined in chaincode definition comitted                                                                                        |
| `CHAINCODE_VERSION`       | Chaincode version defined in chaincode definition committed.                                                                                                    |
| `CHAINCODE_POLICY`        | Chaincode policy defined in chaincode definition committed.                                                                                                     |
| `PEER_ADMIN_MSP_DIR`      | Admin user msp directory of satellite ex: `app/<ENVIRONMENT>/crypto/peerOrganization/<subdomain>/users/Admin@subdomain/msp`                                     |

```sh
export ORG_NAME=<orgname>
export SUB_DOMAIN=<sub-domain>
export PEER_COUNT=2
export ORDERER_COUNT=0
export ENVIRONMENT=test
export ORDERER_TLS_CA_CERT=<path-to-orderer-ca-cert>
export ORDERER_ADDRESS=<orderer-hostname-with-port>
export CHANNEL_NAME=<channelname>
export ANCHOR_PEER_HOSTNAME=<hostname-of-one-the-hlf-peer>
export ANCHOR_PEER_PORT_NUMBER=<port-number-of-one-the-hlf-peer>
export CHAINCODE_NAME=<chaincode-name>
export CHAINCODE_SEQUENCE=<chaincode-version>
export CHAINCODE_VERSION=<chaincode-version>
export CHAINCODE_POLICY=<chaincode-policy>
export PEER_ADMIN_MSP_DIR=/<path>/app/<orgname>/users/Admin/msp
```

Join the HLF channel using below script:
```sh
cd iSHARESatellite/scripts
bash joinchannel.sh
```

Anchor peer for new satellite:

```sh
bash anchorPeer.sh
```

Install chaincode in new satellite peer:

```sh
bash installChaincode.sh
```

Approve the chaincode for new satellite peer:

```sh
bash approveChaincode.sh
```

Create chaincode instance:

```sh
bash chaincode.sh
```

Create HLF explorer instance:

```sh
bash explorer.sh
```

Your node is now on network!

## 4.5. <a id="deploy"> Deploy the UI and middleware applications </a>

**Note: Steps to configure Private key (of the eIDAS) certificate in production environment could differ to accommodate your organizations policies. <br> For test environments currently we configure the private keys in VM itself which is not very secure. But since we issue you test eIDAS certificates it is usually no issue. Please contact us if you wish to configure private keys differently.**

Export these environment variables to initialize scripts:

| **Environment Variables** | **Description**                                                                                                                                                                    |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ORG_NAME`                | Satellite which is going to be a part of HLF network. Ex: `mysatellite`. You already set this value in chapter 4.2, make sure to use the same value here.                             |
| `SUB_DOMAIN`              | Sub-domain reserved in DNS service for this satellite. Ex: `uat.mydomain.com`. You already set this value in chapter 4.2, make sure to use the same value here.                       |
| `CHANNEL_NAME`            | Name of the channel in which new satellite is onboarded. Same value as used in previous chapter.                                                                                   |
| `CHAINCODE_NAME`          | Chaincode (smart contract) name defined in chaincode definition comitted. Same value as used in previous chapter.                                                                  |
| `PARTY_ID`                | EORI identifier that iSHARE has used to register you in the network.                                                                                                               |
| `PARTY_NAME`              | Name used by iSHARE to register you in the network.                                                                                                                                |
| `UIHostName`              | DNS name of Application UI. Ex: `mysatellite.example.com`. Base URL of your satellite application. This name should be unique.                                                       |
| `MiddlewareHostName`      | DNS name for application middleware. Ex: `mysatellite-mw.example.com`. Base URL of your satellite APIs. This name should be unique.                                                  |
| `KeycloakHostName`        | DNS name for application keycloak service. Ex: `mysatellite-keycloak.example.com`. Base URL of your keycloak for user administration. Internal use only. This name should be unique. |

```sh
export ORG_NAME=<myorg>
export SUB_DOMAIN=<test.example.com>
export ENVIRONMENT=<test>
export CHANNEL_NAME=<mychannel>
export CHAINCODE_NAME=<ccname>
export PARTY_ID=<party_id>
export PARTY_NAME=<party_name>
export UIHostName=<myorg-test.example.com>
export MiddlewareHostName=<myorg-mw-test.example.com>
export KeycloakHostName=<myorg-keycloak-test.example.com>
```

#### Configure HTTPS (SSL/TLS)

To configure SSL (HTTPS) you need the certificate chain file and private key file from your CA. 

Copy/move the full certificate full chain file and private key file into the "ssl" directory. The files should have the given names and format shown below: 

- The full chain certificate file should be named "tls.crt".
  - The certificate file should only contain the three keys, and begin with `---BEGIN CERTIFICATE---` and end with `---END CERTIFICATE----`.
- The private key file should be named "tls.key".
  - The file should only contain the private key, and begin with `---BEGIN PRIVATE KEY---` and end with `---END PRIVATE KEY---`, or begin with `---BEGIN RSA PRIVATE KEY---` and end with `---END RSA PRIVATE KEY---`.

Note: SSL certs should be a wild card certificate of your domain name like `*.example.com`.

#### Configure Signing Certificate (e.g. your eIDAS certificate)

**Note: For production environments you should have received your Qualified Seal digital certificate as specified in iSHARE, from your chosen Certificate Authority. When requesting you can request the certificate in p12 file format. For test environments you can request your certificates using following link:<a> https://ca7.isharetest.net:8442/ejbca/ra </a>. Use "postpone" option during request. Once your request is approved you will get a link via email to download the certificate.**

To extract the public certificate from p12 compatible with required format:

```sh
openssl pkcs12 -in <p12 file> -nokeys -passin <p12 password> \
| sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > jwtRSA256-public.pem
```

To extract the unencrypted private key from p12 compatible with required format:

```sh
openssl pkcs12 -in <p12 file> -nocerts -nodes -passin <p12 password> \
| openssl rsa > jwtRSA256-private.pem
```

You can also use following script to automate above and extract certificate in various formats:

<https://github.com/iSHAREScheme/code-snippets/tree/master/Cert_Key_Extractor>

Copy/move RSA public cert and private key (e.g. your eIDAS certificate) in `jwt-rsa` folder.  The folder should contain following files with given names below:

- `jwtRSA256-public.pem` - public full chain certificate for jwt signing.
  - The certificate file should contain three files, and begin with `-----BEGIN CERTIFICATE-----` and end with `-----END CERTIFICATE-----`.
- `jwtRSA256-private.pem` – RSA private key (unecrypted) file for jwt signing.
  - The certificate file should begin with
   `-----BEGIN RSA PRIVATE KEY-----`  and end with `-----END RSA PRIVATE KEY-----`. 

#### Configure environment and deploy applications

Copy `genesis.block` and `isharechannel.tx` files into the `middleware` folder. These files were shared by iSHARE Foundation to you earlier.

Create Keycloak Instance using below command, It listens at port 8443.

```sh
cd iSHARESatellite/scripts
bash keycloak.sh
```

Create middleware instances using below command.

```sh
bash middleware.sh
```

Create UI and Nginx instances:

```sh
bash deployUI.sh
```

#### Configure DNS for your applications

Map DNS entries for application services with server IP address for these environment variables:

- `UIHostName` (ex: `myorg-test.example.com`)

- `MiddlewareHostName` (ex: `myorg-mw-test.example.com`)

- `KeycloakHostName` (ex: `myorg-keycloak-test.example.com`)


| **Full Record Name**   | **Record Type** | **Value**  | **TTL** |
|------------------------|-----------------|------------|---------|
| `<UIHostName>`         | A               | 123.0.0.23 | 1min    |
| `<MiddlewareHostName>` | A               | 123.0.0.23 | 1min    |
| `<KeycloakHostName>`   | A               | 123.0.0.23 | 1min    |

Now your satellite is deployed! Finish the next chapter to use the application.

# 5. <a id="U_setup"> Initial user setup </a>

The satellite is now installed. To access the satellite, first set up a satellite admin user for the keycloak identity provider with the procedure below.  Keycloak URL is accessible over the browser. Example: <https://satellite.example.com:8443/auth>.

NOTE: Once you have set up an initial user, you can add your colleagues via satellite UI in a straightforward manner. Therefore, you do not need repeat the keycloak user setup for other users. Also, make sure to secure keycloak environment based on your organization policy to limit users that can log into the keycloak admin console. You can set stricter password and user policies via keycloak admin console. 

1. Click on administrator console and login with seeded admin user refer to below screenshots.

   ![](docs/assets/keycloakuser1.png)

   ![](docs/assets/keycloakuser2.png)

   Note: username and password for admin can be found in keycloak-docker-compose.yaml inside "keycloak" directory of the project folder.

   **IMPORTANT NOTE: if you change the admin username and password in the keycloak ui, you also need to change these inside the `keycloak-docker-compose.yaml` file.**

2. Once logged in successfully, click on users in left menu

   ![](docs/assets/keycloakuser3.png)

3. Click on Add User button on right side of it

   ![](docs/assets/keycloakuser4.png)

4. Fill all the details in "Add user" form. Refer to the below image and click save.

   Note : username and email should be email id.

   ![](docs/assets/keycloakuser5.png)

5. Click on the "Attribute" tab and add the attributes shown in the table below. Then click save. 

   Note: Attributes are mandatory.

   | **Attribute Name** | **Attribute Value**                                                     |
   |:-------------------|:------------------------------------------------------------------------|
   | `partyId`          | ID of the participant that this user belongs. Usually, the satellite ID |
   | `partyName`        | Name of the participant corresponding to the partyId                    |

   ![](docs/assets/keycloakuser6.png)

6. Click on the "Credentials tab and set the password for the user that is being created. 

   ![](docs/assets/keycloakuser7.png)

7. Click on "Role Mappings" tab and find "Client Roles "dropdown. Select "frontend". 

   ![](docs/assets/keycloakuser8.png)

8. Under "Available Roles", select "satelliteAdmin" and click on the "Add Selected" button.

   ![](docs/assets/keycloakuser9.png)

Your user is now created, and you can proceed to use the satellite the UI with newly created user. In the UI you can start registering satellite participants.

# 6. <a id="email"> Set up email notifications </a>

You need an email account so that notifications can be sent to users. The steps below explain how to set up notifications with google email. Make to create an app password in the google account, as this is needed for the notification configuration. 

If you wish to use other email providers, please refer specifically to their values and settings for setup.

Steps for Email Notification under keycloak administrator login:

1. Login as administrator user

2. Click on "Realm Settings" under the left menu bar.

   ![](docs/assets/keycloakemail1.png)

3. Click on the "Email" tab and fill out the necessary details shown below. Remember to click save. Email notification will be enabled.

   ![](docs/assets/keycloakemail2.png)

Note: Form inputs for *From* and *username* should be valid email id's. Password should be the app password configured in the mail account.

# 7. <a id="configure_keycloak"> Configure Keycloak </a>

Steps for RedirectURL configuration in keycloak

1. Login as administrator user

2. Click on "Clients" under left menu bar and select "frontend" from the "ClientID" options.

   ![](docs/assets/keycloakurl1.png)

3. In the "frontend" settings form, find `RootURL`, `valid RedirectURLs, Web Origins` and add the entries as follows:

   - `RootURL` – the values to this input should be UI application URL. Example: <https://satelliteone-demo.example.com>

   - `Valid Redirect URLs` – it includes multiple values as URLs.

     - UI application URL with `*` as route. Example: <https://satelliteone-demo.krypc.com/>\*
     - Keycloak URL with `*` as route. Example: <https://satelliteone-demo.exapmle.com:8443/>\*

   - `Web Origins` - the values to this input should be keycloak URL with `*` as route. Example: `https://satelliteone-demo.krypc.com:8443/*`

   Find below image as reference:

   ![](docs/assets/keycloakurl2.png)

4. Match all the settings as below image and save it. Redirection settings has been changed successfully.

   ![](docs/assets/keycloakurl3.png)

   ![](docs/assets/keycloakurl4.png)

# 8. <a id="2FA"> Enable 2FA for users </a>

The steps below explain how to set up the 2FA for new devices (configured device lost/new device to configure with existing users). The keycloak administrator has the provision to enable this feature. 

1. Log in with the Keycloak admin credentials, and goto "Manage" in the left option bar, then click "Users". Select the user to reset 2FA.

2. Go to the "Credentials" tab and delete the "otp” type. Then click "confirm". 

   ![](docs/assets/keycloak2fa1.png)

3. Go to the "Details" tab. Click on the "Required user action" dropdown bar, and select "Configure OTP". Click on save.

   ![](docs/assets/keycloak2fa2.png)

   ![](docs/assets/keycloak2fa3.png)

4. Inform the user to login with existing credentials and configure the 2FA on the new device.

The application will allow to use the existing credentials with new 2FA.

You are now ready with your Satellite. Login with the user you created in step 5.2 using the application link `<UIHostName>` setup in previous chapter.

# 9. <a id="docker_service"> Commands for managing Docker services </a>

To check the status of docker containers:

```sh
docker-compose -f <docker-compose-file> ps
```

To stop the container:

```sh
docker-compose -f <docker-compose-file> down
```

To restart containers:

```sh
docker-compose -f <docker-compose-file> restart
```

To bring containers up and running:

```sh
docker-compose -f <docker-compose-file> up -d
```

To get the logs of containers:

```sh
docker-compose -f <docker-compose-file> logs <service-name-in-compose-file>
```

# 10. <a id="ref_update"> Reference updates deployment procedure </a>

Following is general procedure for updates deployment. When new updates are available to be deployed, iSHARE Foundation will inform you with additional details about the deployment.

You will find docker-compose files in following path in project directory. All the docker services will be managed using these docker-compose files. 

- `iSHARESatellite/hlf/<Environment>/<orgName>/peers/docker-compose-hlf.yaml`
- `iSHARESatellite/hlf/<Environment>/<orgName>/fabric-ca/docker-compose-fabric-ca.yaml`
- `iSHARESatellite/middleware/docker-compose-mw.yaml`
- `iSHARESatellite/keycloak/keycloak-docker-compose.yaml`
- `iSHARESatellite/explorer/explorer-docker-compose.yaml`
- `iSHARESatellite/chaincode/cc-docker-compose-template.yaml`
- `iSHARESatellite/ui/docker-compose-ui.yaml`

Find the services which are going to be updated below: 

| # | Services                                                                          | Path                                                        |
|---|-----------------------------------------------------------------------------------|-------------------------------------------------------------|
| 1 | <p>`ishare_mw` (ishare middleware)</p><p>`ishare_hlf` (ishare hlf middleware)</p> | `iSHARESatellite/middleware/docker-compose-mw.yaml`         |
| 2 | <p>`ishare_ui` (ishare UI)</p><p>`nginx-proxy` (Nginx reverse proxy)</p>          | `iSHARESatellite/ui/docker-compose-ui.yaml`                 |
| 3 | `ishare-cc.hlf` (ishare chaincode)                                                | `iSHARESatellite/chaincode/cc-docker-compose-template.yaml` |


Steps to deploy update/releases:

- Open the docker-compose file in a text editor eg: docker-compose-mw.yaml file to manage ishare middleware and ishare hlf middleware.
- Select one of the service eg: `ishare_mw` (ishare middleware).
- Under service name (`ishare_mw`), look for image key eg:
  `ishare_mw`:

image: isharefoundation/ishare-satellite-app-mw:<tag>

- Change the tag of the image with new tag provided as an update/release eg: v1.50 and save it.
  Eg:
  `ishare_mw`:

`            `image: isharefoundation/ishare-satellite-app-mw: v1.50

- Stop the container with below command
  docker-compose –f <docker-compose-file> down
  eg: docker-compose –f docker-compose-mw.yaml down
- Start the docker services again with below
  docker-compose –f <docker-compose-file> up -d
  eg: docker-compose –f docker-compose-mw.yaml up –d
- Check the state of the services
  docker-compose –f <docker-compose-file> ps
  eg: docker-compose –f docker-compose-mw.yaml ps
  It should show table containing state as column with Up as a state.
- Deployment is done.

Similarly, updates can be done for all the services.

