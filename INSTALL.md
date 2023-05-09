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

There are various ways to deploy satellite. However this guide is only for standalone deployment of satellite in a VM using docker containers. The proposed model requires virtual machines provisioned on cloud providers and/or on-prem with prescribed operating systems and following software's installed in them. Make sure that you have them before beginning. 

*Note: the scripts and components are tested in versions mentioned in the brackets, usually it should work well in higher version as well.*

1. A recent Debian-based GNU/Linux distribution (tested on Debian 11 / Bullseye and Ubuntu Linux 20.04.4 LTS / Focal Fossa).
1. Create/Update rights to your DNS service to manage satellite URLs in DNS record. 
1. SSL certificates of your domain for applications (applications by default use HTTPS so having certificates on hand is required. You may also use free Letsencrypt certificates, please refer to its website to acquire them. 
1. JWT signing certificate:  
   - For production environments – Qualified Seals as defined in iSHARE specifications, 
   - For test environments – test certificates maybe obtained from <https://ca7.isharetest.net:8442/ejbca/ra/>. (Use "postpone" option when you request a test certificate. You will get email with link to download the certificate file, once your request is approved.)

# <a id="hardware-req"> 2. Hardware Requirements </a>

## <a id="minimum"> 2.1. Minimum </a>

Virtual Machine with 2 CPU’s and 8 GB Memory. 20GB Disk Space

## <a id="recommendation"> 2.2. Recommendation </a>

Virtual Machine with 4 CPU’s and 16 GB Memory. 40GB Disk Space

# <a id="network-req"> 3. Network Requirements </a>
Following ports are used by following applications, so make sure that you configure your firewall and network settings to allow access via these ports

- 443/TCP,80/TCP for Application middleware and UI
- 7051/TCP and 8051/TCP for HLF Peers
- 8443/TCP for Keycloak instance (user management backend)


# <a id="get_start"> 4. Getting Started </a>

The iSHARE satellite is based on Hyperledger fabric. When participants are registered via a satellite, they are directly registered on the shared ledger. This means that participants are trusted across the iSHARE network. The iSHARE satellite is composed of following sub-components:

- Hyperledger fabric node,
- Application UI,
- Keycloak (user managment backend),
- Satellite Middleware (APIs and other relevant functions).

The following diagram shows the overall satellite architecture and its components as it is deployed using this guide. Note alternatives are possible and will be updated into this guide at a later stage. If you wish to customise your satellite deployment, please get in touch with iSHARE support team.


![iSHARE satellite general architecture overview](docs/assets/iSHARE-satellite-architecturev1.0.drawio.png)

This guide will take your through the steps below (given by their chapter number), in order to install and configure the iSHARE satellite.

1. Download the script files, and configure your passwords,
1. Install Hyperledger fabric node.
1. Register your node.
1. Join the iSHARE network. 
1. Deploy the UI, middleware and keycloak applications.
1. Set up and configure satellite access control. Configure satellite admin user and log in the the satellite user interface. 

# <a id="configure"> 5. Configure Passwords for the Services </a>
If you want to change the default passwords (recommended and mandatory for production environments) please follow the steps below. You are not obliged to configure passwords if you are setting up the satellite for a test environment. Skip this chapter if you want to deploy satellite with default passwords.

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

Under the *services* section, change the password for *explorerdb*. The password variable is called *DATABASE_PASSWORD*, and is located in the *environment* subsection. See below snipppet:

```yaml

services:

explorerdb:
    image: hyperledger/explorer-db:latest
    container_name: explorerdb
    hostname: explorerdb
    environment:
      - DATABASE_DATABASE=fabricexplorer
      - DATABASE_USERNAME=hppoc
      - DATABASE_PASSWORD=password
```

The same password has to be configured for *explorer* service under the *environment* subsection. The password variable is called *DATABASE_PASSWD*. See the below snippet:

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

Open app-mw-config-template.yaml in the text editor and change the *password* part of the explorer db connection string to your new password. See the string below for reference:

```yaml
explorerDb:
  postgresql://hppoc:password@explorerdb:5432/fabricexplorer?sslmode=disable
```

### Steps to configure password for Application middleware postgres DB

```sh
cd iSHARESatellite/templates
```

Open docker-compose-mw-template.yaml in a text editor. Under the *environment* section, change the password given by *POSTGRES_PASSWORD* and *DATABASE_PASSWORD*. These two passwords should be identical. See the below snippet for reference:

```yaml
environment:
      - DATABASE_DATABASE=offchaindata
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=postgres 
```
Open *hlf-mw-config-template.yaml* file in a text editor. Locate the `postgres_connection_url` subsection. Change the `adminpw` part of the string with the same passwords configured in the snippet above; the docker-compose-mw-template.yaml file. See the below snippet for reference: 

```yaml
ishareConfig:
  middlewareConfig:
    type: satellite
    postgres_connection_url: postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
```

Open *app-mw-config-template.yaml* file in a text editor. Locate the `postgres_connection_url` subsection. Change the `adminpw` part of the string to the passwords you configured two snippets above; in the `docker-compose-mw-template.yaml` file. Look at the below snippet for reference: 

```yaml
ishareConfig:
  middlewareConfig:
    postgres_connection_url:
      postgresql://admin:adminpw@app-postgres:5432/ishare?sslmode=disable
```

### Steps to configure password for Application Keycloak service

Move to the following directory: 
```sh
cd iSHARESatellite/keycloak/postgres
```

Open `init-db.sql` in a text editor, and look for the below snippet. Replace the `keycloak` string with your desired password. The password should be placed between single quotes.

```sql
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloak';
```

Move to the following directory: 
```sh
cd iSHARESatellite/keycloak
```

Open *keycloak-docker-compose.yaml* in a text editor. Locate the `environment` section. Change the value of the `DB_PASSWORD` variable to your desired password. Look at the below snippet for reference: 

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

# <a id="install_hyp"> 6. Installing Hyperledger Fabric node </a>

Each satellite will contain the following hyperledger fabric components:

1. 2 Peers
1. Shared Orderer
1. 2 CouchDB
1. 1 Fabric Certification Authority

These components have to be pulled as docker images, and installed and initialized as directions mentioned here.

### Steps and sequence for creating HLF components

Download the scripts from GitHub (if not done so already).

```sh
git clone https://github.com/iSHAREScheme/iSHARESatellite.git
```
Move into the correct directory.
```sh
cd iSHARESatellite
```

To install and ensure all the necessary packages are available in the system, use the below script to install the missing packages.

```sh
bash prerequisites.sh
```

If docker was not already setup and configured for the current user, logout and login before continuing.

Configure environment variables to initialize scripts. The environment variables below will be needed for in this chapter. 

| **Environment** | **Description**                                                                                                                                                     |
|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ORG_NAME`      | Satellite which is going to be a part of HLF network. It should be a word  without special characters (only alphanumeric) and max 17 characters. ex: `mysatellite`. |
| `SUB_DOMAIN`    | Sub-domain reserved in DNS service for this satellite. No special characters. ex: `uat.mydomain.com`                                                                |
| `ENVIRONMENT`   | Name of the infra environment like `uat`, `test`, `prod`. No special characters.                                                                                    |

**Note: the ORG_NAME variable is exclusive. If you earlier tried to deploy a satellite, and this satellite was removed, you can not re-use the same ORG_NAME**. 

State your environment variables, and move into the correct directory.

```sh
export ORG_NAME=newsatellite
export SUB_DOMAIN=test.example.com
export ENVIRONMENT=test
cd scripts
```

To generate HLF fabric CA certificates, use the below command.

```sh
bash fabric-ca-cert.sh
```

Create the HLF Fabric CA instance. 

```sh
bash fabric-ca.sh
```

Wait more than a minute after running the above command. Certificates are being generated. Running the next "bash" command too early will cause an error. 

Register and Enroll users and peers

```sh
bash registerAndEnroll.sh
```

Create HLF Peer instances, it will spin up instances of HLF Peers and CouchDB.

```sh
bash peer.sh
```

### Validation

Navigate to `iSHARESatellite/hlf/<Environment>/<orgName>/peers` directory.

Check the presence of the `docker_data` folder.

To ensure all the HLF Peer is running, use below commands to check the status.

```sh
docker-compose -f docker-compose-hlf.yaml ps
```

### DNS record configuration
HLF Peer instances needs to be a part of the iSHARE Foundation HLF network. Therefore, HLF peers need to be reachable over the internet. The previous script `peer.sh` creates two HLF peer instances with hostnames `peer<num>.<ORG_NAME>.<SUB_DOMAIN>`, which listen at port 7051 and 8051 TCP. Make sure that necessary firewall settings are updated to allow access to these peers over internet. Log into your DNS record, and create two DNS entries that correspond to the peer addresses shown below. Assign both peer addresses with you server IP address. The example below shows the format of the peer addresses when `ORG_NAME=newsatellite` and `SUB_DOMAIN=test.example.com`. The table below shows the registration format of the peer addresses in the DNS record. 

`peer0.<orgname>.<subdomain>` -> `peer0.newsatellite.test.example.com`  
`peer1.<orgname>.<subdomain>` -> `peer1.newsatellite.test.example.com`

| **Full Record Name**          | **Record Type** | **Value**  | **TTL** |
|-------------------------------|-----------------|------------|---------|
| `peer0.<orgname>.<subdomain>` | A               | `server IP address`| 1 min   |
| `peer1.<orgname>.<subdomain>` | A               | `server IP address` | 1 min   |

The Hyperledger fabric node is deployed on your server. Now follow the next chapter to register your node in the ISHARE HLF network.

# <a id="reg_node"> 7. Register your node </a>

Move into the correct directory. 
```sh
cd scripts
```
Run the command below. The command will create an organization definition file. 
```sh
bash orgDefinition.sh
```
Find the generated organization definition file in the following directory: 
```sh
cd hlf/<ENVIRONMENT>/<ORG_NAME>
```
The organization definition file has the name format: `<orgName>.json`. The file has to be shared with iSHARE Foundation to register your satellite on the iSHARE HLF network. The satellite has to be shared securely, as it contains x509 certificates of the new satellite. After you have provided iSHARE Foundation with the organization definition file, you will receive files and information that is needed to proceed with the satellite deployment. 

Note: when setting up a satellite test environment, the organization definition file can be send via email. 

# <a id="join_net"> 8. Join the network </a>

iSHARE will provide you with the files and variable values below, in order for you to join the iSHARE HLF network.  

**Files to be copied into your VM**

- Certificate authority file of HLF ordering service. Called `ca-ishareord.pem`
- `genesis.block` 
- `isharechannel.tx`

The `ca-ishareord.pem` should be moved into the `iSHARESatellite` folder. The `genesis.block` and `isharechannel.tx` will be used at a later stage (chapter 9). 
 


**Values for following variables**

- `ORDERER_ADDRESS` - one of the ordering services hostname and port
- `CHANNEL_NAME` - channel name in which a particular satellite is on boarded
- `CHAINCODE_NAME` - chaincode (smart contract) which is defined in chaincode definition committed
- `CHAINCODE_VERSION` -  chaincode version defined in chaincode definition committed
- `CHAINCODE_SEQUENCE` - sequence number associated with chaincode
- `CHAINCODE_POLICY` - chaincode policy string used while commiting chaincode definition in the HLF network
- `PARTY_ID` - EORI identifier that iSHARE has used to register you in the network.
- `PARTY_NAME` - Name used by iSHARE to register you in the network.


The table below describes the variables that are new, and will be defined in this chapter. 
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

Export the new variables. 
```sh
export ORG_NAME=newsatellite
export SUB_DOMAIN=test.example.com
export ENVIRONMENT=test
export PEER_COUNT=2
export ORDERER_COUNT=0
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
Move into the correct directory.
```sh
cd iSHARESatellite/scripts
```

Join the HLF channel by using the script below. 
```sh
bash joinchannel.sh
```
Anchor the peer for your satellite.
```sh
bash anchorPeer.sh
```
Install the chaincode in your satellite peer.

```sh
bash installChaincode.sh
```
Approve the chaincode for your satellite peer. 
```sh
bash approveChaincode.sh
```
Create chaincode instance. 
```sh
bash chaincode.sh
```
Create HLF explorer instance.
```sh
bash explorer.sh
```
Your node is now on the iSHARE HLF network!

# <a id="deploy">9. Deploy the UI, middleware and keycloak applications </a>

**Note: Steps to configure Private key (of the eIDAS) certificate in production environment could differ to accommodate your organizations policies. <br> For test environments currently we configure the private keys in VM itself which is not very secure. But since we issue you test eIDAS certificates it is usually no issue. Please contact us if you wish to configure private keys differently.**

The table below describes the variables that are new, and you will define in this chapter. 
| **Environment Variables** | **Description**                                                                                                                                                                    |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `UIHostName`              | DNS name of Application UI. Ex: `mysatellite.example.com`. Base URL of your satellite application. This name should be unique.                                                       |
| `MiddlewareHostName`      | DNS name for application middleware. Ex: `mysatellite-mw.example.com`. Base URL of your satellite APIs. This name should be unique.                                                  |
| `KeycloakHostName`        | DNS name for application keycloak service. Ex: `mysatellite-keycloak.example.com`. Base URL of your keycloak for user administration. Internal use only. This name should be unique. |

Export the variables. 
```sh
export ORG_NAME=newsatellite
export SUB_DOMAIN=test.example.com
export ENVIRONMENT=test
export CHANNEL_NAME=<mychannel>
export CHAINCODE_NAME=<ccname>
export PARTY_ID=<party_id>
export PARTY_NAME=<party_name>
export UIHostName=<myorg-test.example.com>
export MiddlewareHostName=<myorg-mw-test.example.com>
export KeycloakHostName=<myorg-keycloak-test.example.com>
```

### Configure HTTPS (SSL/TLS)

To enable HTTPS protocol for your satellite, you will need SSL/TLS certificates from your certification authority (CA). You will need the full chain certificate file, and the private key file for the deployment. The encryption of the SSL/TLS certificates with RSA is widely accepted whereas with ECDSA may face compatibility issues, so avoid using ECDSA. Your certificate may be a wild card certificate of your domain, like `*.example.com`.

Move into the correct directory. 
```sh
cd iSHARESatellite/ssl
```
Copy/move the full chain certificate file and the private key file into the `ssl` directory. 

Rename the full chain certificate file to `tls.crt`. The file should only contain three keys, and no other text. See the snippet below for reference. 
```text
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
```

The private key file should be named `tls.key`. The file should only contain the private key, and no other text. See the below snippet for reference. 
```text
-----BEGIN PRIVATE KEY-----
XXXXX
-----END PRIVATE KEY-----
```


### Configure Your Signing Certificate (e.g. your eIDAS certificate)

**Note: For the satellite production environment, you should receive your qualified eseal digital certificate from your chosen certificate authority. The list of trusted Certificate authorities is as specified by iSHARE. You can request your certificate in the p12 format. <br>For test environments, you can request your test certificates by using the following link:<a> https://ca7.isharetest.net:8442/ejbca/ra </a>.  Use the "postpone" option during your request. Once your request is approved, you will get a link via email to download the certificate.**

Your satellite needs signing certificates to sign JWTs. You will need the fullchain certificate file, and private key file. The certificates should be RSA encrypted. 

You can use the command below to extract the public certificate, with the correct format and file name, from the p12 certificate file. 
```sh
openssl pkcs12 -in <p12 file> -nokeys -passin <p12 password> \
| sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > jwtRSA256-public.pem
```
The command below extracts the unencrypted private key, with the correct format and file name, from p12 certificate file.
```sh
openssl pkcs12 -in <p12 file> -nocerts -nodes -passin <p12 password> \
| openssl rsa > jwtRSA256-private.pem
```
Alternatively, you can also use the script in the following link to extract the certificate public keys and private key in various formats: <https://github.com/iSHAREScheme/code-snippets/tree/master/Cert_Key_Extractor>

Move to the correct directory. 
```sh
cd iSHARESatellite/jwt-rsa
```
Copy/move the full chain certificate file and the private key file into the `jwtRSA256` directory. 

Rename the full chain certificate file to `jwtRSA256-public.pem`. The file should only contain three keys, and no other text. See the snippet below for reference.
```text
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
XXXXX
-----END CERTIFICATE-----
```
The private key file should be named `jwtRSA256-private.pem`. The file should only contain the private key, and no other text. See the below snippet for reference. 
```text
-----BEGIN PRIVATE KEY-----
XXXXX
-----END PRIVATE KEY-----
```


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
### DNS record configuration

Log into your DNS record, and create three DNS entries that correspond to the UI, middleware and keycloak addresses that you specified as export variables in the beginning of this chapter. Assign the ui, middleware and keycloak addresses with your server IP address. 


| **Full Record Name**   | **Record Type** | **Value**  | **TTL** |
|------------------------|-----------------|------------|---------|
| `<UIHostName>`         | A               | `server IP address` | 1min    |
| `<MiddlewareHostName>` | A               | `server IP address` | 1min    |
| `<KeycloakHostName>`   | A               | `server IP address` | 1min    |

Now your satellite is deployed! Finish the next chapter to use the application.

# <a id="configure_keycloak"> 10. Configure Keycloak </a>

The satellite is now installed, however it must be configured for use. To access the Keycloak admin portal, use the url address that you defined in the `<KeycloakHostName>` variable in chapter 9. Specify the port 8443, and the path `/auth` in your url. A reference example is: <https://myorg-keycloak-test.example.com:8443/auth>

Steps for RedirectURL configuration in keycloak

1. Click on administrator console and login with default admin user refer to below screenshots.

   ![](docs/assets/keycloakuser1.png)

   ![](docs/assets/keycloakuser2.png)

   Note: username and password for admin can be found in keycloak-docker-compose.yaml inside "keycloak" directory of the project folder.

   **IMPORTANT NOTE: if you change the admin username and password in the keycloak ui, you also need to change these inside the `keycloak-docker-compose.yaml` file.**

2. Click on "Clients" under left menu bar and select "frontend" from the "ClientID" options.

   ![](docs/assets/keycloakurl1.png)

3. In the "frontend" settings form, find `RootURL`, `Valid Redirect URIs` and `Web Origins`. The entries in these text boxes should be the `UIHostName`, `MiddlewareHostName` and `KeycloakHostName` addresses that you defined in chapter 9. 

   The `RootURL` textbox should contain the `UIHostName` url. An example of this url (based on the example from chapter 9.) is: <https://myorg-test.example.com>. 

   The `Valid Redirect URLs` textbox should have two entries. The first entry is the `UIHostName` url with `*` as route. Example: <https://myorg-test.example.com/*>. The second entry is the `KeycloakHostName` url with the port 8443 specied. An example of the format is: <https://myorg-keycloak-test.example.com:8443/>. 

   The `Web Origins` MUST be set to '+'.

   Use the image below as reference.

   ![](docs/assets/keycloakurl2.png)

4. Match all the settings as below image and save it. Redirect settings have been changed successfully.

   ![](docs/assets/keycloakurl3.png)

   ![](docs/assets/keycloakurl4.png)

# <a id="U_setup"> 11. Initial user setup </a>

To access the satellite, first set up a satellite admin user from within the keycloak identity provider with the procedure below. To access the Keycloak admin portal follow the steps as explained in previous step

**NOTE: Once you have set up an initial satellite user, you can add your colleagues via satellite UI in a straightforward manner. Therefore, you do not need repeat these steps for other users. Also, make sure to secure keycloak environment based on your organization policy to limit users that can log into the keycloak admin console. You can set stricter password and user policies via keycloak admin console.** 

1. Login as administrator user

2. Once logged in successfully, click on the "Users" button located in the left menu. Then, click on the "Add User" button on the right side of the screen. Fill in all details in the "Add user form". Refer to the below image and click save. 

   **Note : username and email should be email id. First name must be set to partyId value and Last Name must be set to partyName value**

   ![](docs/assets/keycloakuser3.png)

5. Click on the "Attribute" tab and add the attributes shown in the table below. Then click save. 

   **Note: Attributes are mandatory.**

   | **Attribute Name** | **Attribute Value**                                                     |
   |:-------------------|:------------------------------------------------------------------------|
   | `partyId`          | ID of the participant that this user belongs. Usually, the satellite ID |
   | `partyName`        | Name of the participant corresponding to the partyId                    |

   ![](docs/assets/keycloakuser6.png)

6. Click on the "Credentials tab and make a password for the user that is being created. 

   ![](docs/assets/keycloakuser7.png)

7. Click on "Role Mappings" tab and find "Client Roles "dropdown. Select "frontend". Then, under "Available Roles", select "satelliteAdmin" and click on the "Add Selected" button. Refer to the below image and click save. 

   ![](docs/assets/keycloakuser8.png)

Your user is now created, and you can proceed to use the satellite the UI with newly created user. In the UI you can start registering satellite participants.

# <a id="email"> 12. Set up email notifications </a>

You need an email account so that notifications can be sent to users. The steps below explain how to set up notifications with google email. Make to create an app password in the google account, as this is needed for the notification configuration. 

**Note: If you wish to use other email providers, please refer specifically to their values and settings for setup.**

Steps for Email Notification under keycloak administrator login:

1. Login as administrator user

2. Click on "Realm Settings" under the left menu bar. Then, click on the "Email" tab and fill out the necessary details shown below. Remember to click save. Email notification will be enabled.

   ![](docs/assets/keycloakemail1.png)

Note: Form inputs for *From* and *username* should be valid email id's. Password should be the app password configured in the mail account.

# <a id="2FA"> 13. Enable 2FA for users </a>

The steps below explain how to set up the 2FA for new devices (configured device lost/new device to configure with existing users). The keycloak administrator has the provision to enable this feature. 

1. Log in with the Keycloak admin credentials, and goto "Manage" in the left option bar, then click "Users". Select the user to reset 2FA.

2. Go to the "Credentials" tab and delete the "otp” type. Then click "confirm". 

   ![](docs/assets/keycloak2fa1.png)

3. Go to the "Details" tab. Click on the "Required user action" dropdown bar, and select "Configure OTP". Click on save.

   ![](docs/assets/keycloak2fa2.png)

4. Inform the user to login with existing credentials and configure the 2FA on the new device.

The application will allow to use the existing credentials with new 2FA.

You are now ready with your Satellite. Login with the user you created earlier using the application link `<UIHostName>` setup in previous chapter.

# <a id="docker_service"> 14. Commands for managing Docker services </a>

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

# <a id="ref_update"> 15. Reference updates deployment procedure </a>

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

